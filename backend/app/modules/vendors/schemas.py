import uuid
from datetime import datetime
from typing import Annotated, Self

from pydantic import AfterValidator, BaseModel, Field, HttpUrl, field_validator, model_validator

from app.core.documents import is_valid_cnpj, is_valid_cpf, mask_document, normalize_document
from app.modules.catalog.models import CancellationPolicy, Listing, ListingStatus
from app.modules.catalog.pricing import MAX_PRICE_CENTS, PricingModel
from app.modules.catalog.reference_data import AMENITIES, BRAZILIAN_STATES, VENUE_CATEGORY
from app.modules.catalog.schemas import ListingDetail
from app.modules.vendors.models import PersonType, VendorProfile, VendorStatus

MAX_OFFERS_PER_LISTING = 20
MAX_PARTNERS_PER_LISTING = 20


def _single_spaced(value: str) -> str:
    return " ".join(value.split())


def _required_text(min_length: int, message: str) -> AfterValidator:
    def validate(value: str) -> str:
        cleaned = _single_spaced(value)
        if len(cleaned) < min_length:
            raise ValueError(message)
        return cleaned

    return AfterValidator(validate)


class VendorData(BaseModel):
    person_type: PersonType
    document: Annotated[str, Field(max_length=20)]
    legal_name: Annotated[
        str, Field(max_length=160), _required_text(3, "Informe o nome completo ou a razão social.")
    ]

    @model_validator(mode="after")
    def _document_matches_person_type(self) -> Self:
        document = normalize_document(self.document)
        if self.person_type is PersonType.INDIVIDUAL:
            if not is_valid_cpf(document):
                raise ValueError("CPF inválido.")
        elif not is_valid_cnpj(document):
            raise ValueError("CNPJ inválido.")
        self.document = document
        return self


def _check_pricing(model: PricingModel, price_cents: int, minimum_cents: int | None) -> None:
    """O que vale para o preço de um anúncio e de um serviço dele."""
    if model is PricingModel.ON_REQUEST:
        if price_cents != 0 or minimum_cents is not None:
            raise ValueError("Um preço sob consulta não tem valor nem mínimo.")
    elif price_cents <= 0:
        raise ValueError("Informe um preço maior que zero, ou marque como sob consulta.")


class OfferInput(BaseModel):
    """Um serviço que o próprio anunciante oferece junto com o anúncio."""

    category: Annotated[str, Field(max_length=40)]
    name: Annotated[str, Field(max_length=120), _required_text(3, "Informe o nome do serviço.")]
    description: Annotated[str | None, Field(max_length=300)] = None
    pricing_model: PricingModel = PricingModel.FIXED
    price_cents: int = Field(default=0, ge=0, le=MAX_PRICE_CENTS)
    minimum_price_cents: int | None = Field(default=None, ge=0, le=MAX_PRICE_CENTS)
    # Quem contrata o anúncio contrata este serviço junto.
    required: bool = False

    @field_validator("category")
    @classmethod
    def _not_a_venue(cls, value: str) -> str:
        # Uma festa tem um salão só: o serviço de um anúncio não pode ser outro.
        if value == VENUE_CATEGORY:
            raise ValueError("Um serviço do anúncio não pode ser um salão.")
        return value

    @field_validator("description")
    @classmethod
    def _clean_description(cls, value: str | None) -> str | None:
        return (_single_spaced(value) or None) if value is not None else None

    @model_validator(mode="after")
    def _coherent_pricing(self) -> Self:
        _check_pricing(self.pricing_model, self.price_cents, self.minimum_price_cents)
        return self


class ListingInput(BaseModel):
    category: Annotated[str, Field(max_length=40)]
    title: Annotated[str, Field(max_length=120), _required_text(3, "Informe o nome do anúncio.")]
    description: Annotated[
        str,
        Field(max_length=4000),
        _required_text(20, "Descreva o anúncio com pelo menos 20 caracteres."),
    ]
    neighborhood: Annotated[str | None, Field(max_length=80)] = None
    city: Annotated[str, Field(max_length=80), _required_text(2, "Informe a cidade.")]
    state: Annotated[str, Field(min_length=2, max_length=2)]
    pricing_model: PricingModel = PricingModel.FIXED
    # Zero só quando o anúncio é sob consulta.
    price_from_cents: int = Field(default=0, ge=0, le=MAX_PRICE_CENTS)
    minimum_price_cents: int | None = Field(default=None, ge=0, le=MAX_PRICE_CENTS)
    capacity: int | None = Field(default=None, ge=1, le=100_000)
    area_m2: int | None = Field(default=None, ge=1, le=1_000_000)
    amenities: list[str] = Field(default_factory=list, max_length=len(AMENITIES))
    event_types: list[str] = Field(default_factory=list, max_length=20)
    cancellation_policy: CancellationPolicy = CancellationPolicy.FLEXIBLE
    cover_image_url: HttpUrl | None = None
    offers: list[OfferInput] = Field(default_factory=list, max_length=MAX_OFFERS_PER_LISTING)
    # Outros anúncios publicados que este recomenda.
    partner_listing_ids: list[uuid.UUID] = Field(
        default_factory=list, max_length=MAX_PARTNERS_PER_LISTING
    )

    @model_validator(mode="after")
    def _coherent_pricing(self) -> Self:
        _check_pricing(self.pricing_model, self.price_from_cents, self.minimum_price_cents)
        return self

    @field_validator("partner_listing_ids")
    @classmethod
    def _unique_partners(cls, value: list[uuid.UUID]) -> list[uuid.UUID]:
        # Sem repetição, na ordem em que vieram.
        return list(dict.fromkeys(value))

    @field_validator("state")
    @classmethod
    def _known_state(cls, value: str) -> str:
        state = value.upper()
        if state not in BRAZILIAN_STATES:
            raise ValueError("UF inválida.")
        return state

    @field_validator("neighborhood")
    @classmethod
    def _clean_neighborhood(cls, value: str | None) -> str | None:
        return (_single_spaced(value) or None) if value is not None else None

    @field_validator("amenities")
    @classmethod
    def _known_amenities(cls, value: list[str]) -> list[str]:
        unknown = sorted(set(value) - AMENITIES)
        if unknown:
            raise ValueError(f"Comodidades desconhecidas: {', '.join(unknown)}.")
        # Sem repetição e em ordem estável.
        return sorted(set(value))

    @field_validator("event_types")
    @classmethod
    def _unique_event_types(cls, value: list[str]) -> list[str]:
        return sorted(set(value))

    @field_validator("cover_image_url")
    @classmethod
    def _https_only(cls, value: HttpUrl | None) -> HttpUrl | None:
        if value is not None and value.scheme != "https":
            raise ValueError("A imagem de capa precisa usar https.")
        return value


class OnboardingRequest(BaseModel):
    # Obrigatório no primeiro anúncio; ignorado se o cadastro de fornecedor já existe.
    vendor: VendorData | None = None
    listing: ListingInput


class VendorResponse(BaseModel):
    id: uuid.UUID
    person_type: PersonType
    document_masked: str
    legal_name: str
    status: VendorStatus
    rejection_reason: str | None
    created_at: datetime

    @classmethod
    def from_profile(cls, profile: VendorProfile) -> Self:
        return cls(
            id=profile.id,
            person_type=profile.person_type,
            document_masked=mask_document(profile.document),
            legal_name=profile.legal_name,
            status=profile.status,
            rejection_reason=profile.rejection_reason,
            created_at=profile.created_at,
        )


class VendorListingResponse(ListingDetail):
    status: ListingStatus
    rejection_reason: str | None

    @classmethod
    def from_listing(cls, listing: Listing) -> Self:
        detail = ListingDetail.from_listing(listing)
        return cls(
            **detail.model_dump(),
            status=listing.status,
            rejection_reason=listing.rejection_reason,
        )


class OnboardingResponse(BaseModel):
    vendor: VendorResponse
    listing: VendorListingResponse


class VendorListingsResponse(BaseModel):
    items: list[VendorListingResponse]


# ----------------------------------------------------------------------
# Fila de análise (administração)
# ----------------------------------------------------------------------


class AdminVendorResponse(VendorResponse):
    """Para quem analisa o cadastro: inclui o documento completo."""

    user_id: uuid.UUID
    document: str

    @classmethod
    def from_profile(cls, profile: VendorProfile) -> Self:
        base = VendorResponse.from_profile(profile)
        return cls(**base.model_dump(), user_id=profile.user_id, document=profile.document)


class AdminVendorsResponse(BaseModel):
    items: list[AdminVendorResponse]


class AdminListingResponse(VendorListingResponse):
    """Para quem analisa o anúncio: diz de quem ele é e desde quando espera."""

    created_at: datetime
    vendor_id: uuid.UUID
    vendor_legal_name: str
    # Um anúncio só pode ser publicado se o fornecedor já foi aprovado.
    vendor_status: VendorStatus

    @classmethod
    def from_review(cls, listing: Listing, vendor: VendorProfile) -> Self:
        base = VendorListingResponse.from_listing(listing)
        return cls(
            **base.model_dump(),
            created_at=listing.created_at,
            vendor_id=vendor.id,
            vendor_legal_name=vendor.legal_name,
            vendor_status=vendor.status,
        )


class AdminListingsResponse(BaseModel):
    items: list[AdminListingResponse]


class ApproveVendorRequest(BaseModel):
    # Publica junto os anúncios do fornecedor que aguardam análise.
    publish_pending_listings: bool = True


class RejectRequest(BaseModel):
    reason: Annotated[str, Field(max_length=500), _required_text(5, "Explique o motivo da recusa.")]
