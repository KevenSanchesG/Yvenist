"""Cadastro de fornecedores, anúncios próprios e fila de análise."""

import uuid

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.core.database import utcnow
from app.core.errors import ConflictError, NotFoundError, UnprocessableError
from app.modules.accounts.models import User
from app.modules.catalog.models import Category, EventType, Listing, ListingStatus
from app.modules.catalog.text import build_search_text
from app.modules.vendors.models import VendorProfile, VendorStatus
from app.modules.vendors.schemas import ListingInput, OnboardingRequest, VendorData

MAX_LISTINGS_PER_VENDOR = 50
_REVIEW_QUEUE_PAGE_SIZE = 50


class VendorProfileNotFoundError(NotFoundError):
    code = "vendor_profile_not_found"
    message = "Você ainda não tem cadastro de fornecedor."


class VendorDataRequiredError(UnprocessableError):
    code = "vendor_data_required"
    message = "Informe os dados do responsável para enviar o primeiro anúncio."


class DocumentAlreadyRegisteredError(ConflictError):
    code = "document_already_registered"
    message = "Este CPF/CNPJ já está vinculado a outro cadastro."


class OnboardingInProgressError(ConflictError):
    code = "onboarding_in_progress"
    message = "Seu cadastro já foi recebido. Atualize a tela para acompanhar a análise."


class UnknownCategoryError(UnprocessableError):
    code = "unknown_category"
    message = "Categoria inválida."


class UnknownEventTypeError(UnprocessableError):
    code = "unknown_event_type"
    message = "Tipo de evento inválido."


class ListingLimitReachedError(ConflictError):
    code = "listing_limit_reached"
    message = f"Um fornecedor pode ter no máximo {MAX_LISTINGS_PER_VENDOR} anúncios."


class VendorNotApprovedError(ConflictError):
    code = "vendor_not_approved"
    message = "O anúncio só pode ser publicado depois que o fornecedor for aprovado."


class AlreadyReviewedError(ConflictError):
    code = "already_reviewed"
    message = "Este item já foi analisado."


class VendorService:
    def __init__(self, db: Session) -> None:
        self._db = db

    # ------------------------------------------------------------------
    # Fornecedor
    # ------------------------------------------------------------------

    def get_profile(self, user: User) -> VendorProfile:
        profile = self._profile_of(user)
        if profile is None:
            raise VendorProfileNotFoundError
        return profile

    def list_own_listings(self, user: User) -> list[Listing]:
        profile = self.get_profile(user)
        return list(
            self._db.scalars(
                select(Listing)
                .where(Listing.vendor_id == profile.id)
                .options(selectinload(Listing.event_types))
                .order_by(Listing.created_at.desc(), Listing.id)
            )
        )

    def submit_onboarding(
        self, user: User, data: OnboardingRequest
    ) -> tuple[VendorProfile, Listing]:
        """Cria o cadastro (se ainda não existe) e o anúncio, numa só transação."""
        existing = self._profile_of(user)
        try:
            if existing is None:
                if data.vendor is None:
                    raise VendorDataRequiredError
                profile = self._create_profile(user, data.vendor)
            else:
                profile = existing
                if profile.status is VendorStatus.REJECTED and data.vendor is not None:
                    # Cadastro recusado pode ser corrigido e volta para a fila.
                    self._resubmit_profile(profile, data.vendor)

            listing = self._create_listing(profile, data.listing)
            self._db.commit()
        except IntegrityError as exc:
            # As consultas "o documento está livre?" e "a conta já tem cadastro?"
            # não bastam: entre elas e a gravação, outra requisição pode ter
            # passado na frente. Quem decide é o índice único, e a violação pode
            # aparecer em qualquer gravação deste bloco, não só no commit.
            self._db.rollback()
            if existing is None and self._profile_of(user) is not None:
                # A mesma conta enviou duas vezes ao mesmo tempo: a outra venceu.
                raise OnboardingInProgressError from exc
            raise DocumentAlreadyRegisteredError from exc
        return profile, listing

    # ------------------------------------------------------------------
    # Fila de análise
    # ------------------------------------------------------------------

    def list_vendors_by_status(self, status: VendorStatus) -> list[VendorProfile]:
        # Mais antigo primeiro: é uma fila.
        return list(
            self._db.scalars(
                select(VendorProfile)
                .where(VendorProfile.status == status)
                .order_by(VendorProfile.created_at, VendorProfile.id)
                .limit(_REVIEW_QUEUE_PAGE_SIZE)
            )
        )

    def approve_vendor(
        self, admin: User, vendor_id: uuid.UUID, *, publish_pending_listings: bool
    ) -> VendorProfile:
        profile = self._pending_vendor(vendor_id)
        now = utcnow()
        profile.status = VendorStatus.APPROVED
        profile.rejection_reason = None
        profile.reviewed_at = now
        profile.reviewed_by = admin.id

        if publish_pending_listings:
            pending = self._db.scalars(
                select(Listing).where(
                    Listing.vendor_id == profile.id,
                    Listing.status == ListingStatus.PENDING_REVIEW,
                )
            )
            for listing in pending:
                listing.status = ListingStatus.PUBLISHED
                listing.published_at = now
        self._db.commit()
        return profile

    def reject_vendor(self, admin: User, vendor_id: uuid.UUID, *, reason: str) -> VendorProfile:
        profile = self._pending_vendor(vendor_id)
        profile.status = VendorStatus.REJECTED
        profile.rejection_reason = reason
        profile.reviewed_at = utcnow()
        profile.reviewed_by = admin.id
        self._db.commit()
        return profile

    def list_listings_by_status(self, status: ListingStatus) -> list[Listing]:
        return list(
            self._db.scalars(
                select(Listing)
                .where(Listing.status == status)
                .options(selectinload(Listing.event_types))
                .order_by(Listing.created_at, Listing.id)
                .limit(_REVIEW_QUEUE_PAGE_SIZE)
            )
        )

    def approve_listing(self, listing_id: uuid.UUID) -> Listing:
        listing = self._pending_listing(listing_id)
        vendor = self._db.get(VendorProfile, listing.vendor_id)
        if vendor is None or vendor.status is not VendorStatus.APPROVED:
            raise VendorNotApprovedError
        listing.status = ListingStatus.PUBLISHED
        listing.rejection_reason = None
        listing.published_at = utcnow()
        self._db.commit()
        return listing

    def reject_listing(self, listing_id: uuid.UUID, *, reason: str) -> Listing:
        listing = self._pending_listing(listing_id)
        listing.status = ListingStatus.REJECTED
        listing.rejection_reason = reason
        self._db.commit()
        return listing

    # ------------------------------------------------------------------
    # Internos
    # ------------------------------------------------------------------

    def _profile_of(self, user: User) -> VendorProfile | None:
        return self._db.scalar(select(VendorProfile).where(VendorProfile.user_id == user.id))

    def _ensure_document_is_free(self, document: str, *, owner_id: uuid.UUID) -> None:
        taken_by = self._db.scalar(
            select(VendorProfile.user_id).where(VendorProfile.document == document)
        )
        if taken_by is not None and taken_by != owner_id:
            raise DocumentAlreadyRegisteredError

    def _resubmit_profile(self, profile: VendorProfile, data: VendorData) -> None:
        self._ensure_document_is_free(data.document, owner_id=profile.user_id)
        profile.person_type = data.person_type
        profile.document = data.document
        profile.legal_name = data.legal_name
        profile.status = VendorStatus.PENDING_REVIEW
        profile.rejection_reason = None
        profile.reviewed_at = None
        profile.reviewed_by = None

    def _create_profile(self, user: User, data: VendorData) -> VendorProfile:
        self._ensure_document_is_free(data.document, owner_id=user.id)

        profile = VendorProfile(
            user_id=user.id,
            person_type=data.person_type,
            document=data.document,
            legal_name=data.legal_name,
            status=VendorStatus.PENDING_REVIEW,
        )
        self._db.add(profile)
        self._db.flush()
        return profile

    def _create_listing(self, profile: VendorProfile, data: ListingInput) -> Listing:
        category = self._db.get(Category, data.category)
        if category is None or not category.is_active:
            raise UnknownCategoryError

        event_types = list(
            self._db.scalars(
                select(EventType)
                .where(EventType.slug.in_(data.event_types), EventType.is_active)
                .order_by(EventType.sort_order)
            )
        )
        if len(event_types) != len(data.event_types):
            raise UnknownEventTypeError

        total = self._db.scalar(
            select(func.count()).select_from(Listing).where(Listing.vendor_id == profile.id)
        )
        if total is not None and total >= MAX_LISTINGS_PER_VENDOR:
            raise ListingLimitReachedError

        listing = Listing(
            vendor_id=profile.id,
            category_slug=category.slug,
            title=data.title,
            description=data.description,
            neighborhood=data.neighborhood,
            city=data.city,
            state=data.state,
            price_from_cents=data.price_from_cents,
            capacity=data.capacity,
            area_m2=data.area_m2,
            amenities=data.amenities,
            cancellation_policy=data.cancellation_policy,
            cover_image_url=str(data.cover_image_url) if data.cover_image_url else None,
            # Todo anúncio novo passa por análise, mesmo de fornecedor aprovado.
            status=ListingStatus.PENDING_REVIEW,
            search_text=build_search_text(
                data.title, data.neighborhood, data.city, data.state, category.name
            ),
            event_types=event_types,
        )
        self._db.add(listing)
        self._db.flush()
        return listing

    def _pending_vendor(self, vendor_id: uuid.UUID) -> VendorProfile:
        profile = self._db.scalar(
            select(VendorProfile).where(VendorProfile.id == vendor_id).with_for_update()
        )
        if profile is None:
            raise NotFoundError("Cadastro de fornecedor não encontrado.", code="vendor_not_found")
        if profile.status is not VendorStatus.PENDING_REVIEW:
            raise AlreadyReviewedError
        return profile

    def _pending_listing(self, listing_id: uuid.UUID) -> Listing:
        listing = self._db.scalar(
            select(Listing)
            .where(Listing.id == listing_id)
            .options(selectinload(Listing.event_types))
            .with_for_update(of=Listing)
        )
        if listing is None:
            raise NotFoundError("Anúncio não encontrado.", code="listing_not_found")
        if listing.status is not ListingStatus.PENDING_REVIEW:
            raise AlreadyReviewedError
        return listing
