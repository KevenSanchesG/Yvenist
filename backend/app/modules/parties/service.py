"""Persistência das festas. As regras ficam em ``domain.reconcile``."""

import uuid
from collections.abc import Collection, Iterator
from contextlib import contextmanager

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload
from sqlalchemy.orm.exc import StaleDataError

from app.core.database import utcnow
from app.core.errors import AppError, ConflictError, NotFoundError
from app.modules.accounts.models import User
from app.modules.catalog.models import (
    EventType,
    Listing,
    ListingOffer,
    ListingStatus,
    listing_partners,
)
from app.modules.parties.domain import (
    SUBMITTED,
    Catalog,
    CatalogItem,
    PartyState,
    PartyStatus,
    describe_transition,
    reconcile,
)
from app.modules.parties.mapping import record, to_state, write_quote
from app.modules.parties.models import Party, PartyItem, PartySnapshot
from app.modules.parties.schemas import PartyInput

MAX_PARTIES_PER_USER = 100


class PartyNotFoundError(NotFoundError):
    code = "party_not_found"
    message = "Festa não encontrada."


class PartyVersionConflictError(ConflictError):
    code = "party_version_conflict"
    message = "A festa foi alterada em outro dispositivo. Atualize e tente novamente."


class PartyIdConflictError(ConflictError):
    code = "party_id_conflict"
    message = "Identificador já utilizado."


class PartyLimitReachedError(ConflictError):
    code = "party_limit_reached"
    message = f"Você atingiu o limite de {MAX_PARTIES_PER_USER} festas."


class PaidPartyCannotBeDeletedError(ConflictError):
    code = "paid_party_cannot_be_deleted"
    message = "Uma festa já paga não pode ser apagada."


class PartyHasOpenQuoteError(ConflictError):
    code = "party_has_open_quote"
    message = "Cancele a festa antes de apagar: os fornecedores já receberam o pedido."


WITH_CHILDREN = (
    selectinload(Party.items),
    selectinload(Party.snapshot),
    selectinload(Party.events),
)


class _CatalogReader:
    """O catálogo como as regras o consultam, lendo cada anúncio uma vez só."""

    def __init__(self, db: Session) -> None:
        self._db = db
        self._listings: dict[uuid.UUID, CatalogItem | None] = {}
        self._offers: dict[uuid.UUID, CatalogItem | None] = {}

    def listing(self, listing_id: uuid.UUID) -> CatalogItem | None:
        if listing_id not in self._listings:
            self.preload([listing_id], [])
        return self._listings[listing_id]

    def offer(self, offer_id: uuid.UUID) -> CatalogItem | None:
        if offer_id not in self._offers:
            self.preload([], [offer_id])
        return self._offers[offer_id]

    def preload(self, listing_ids: Collection[uuid.UUID], offer_ids: Collection[uuid.UUID]) -> None:
        """Busca de uma vez o que as regras vão perguntar, em vez de item por item."""
        listing_ids = [i for i in listing_ids if i not in self._listings]
        offer_ids = [i for i in offer_ids if i not in self._offers]
        published = Listing.status == ListingStatus.PUBLISHED

        if listing_ids:
            found = {
                listing.id: listing
                for listing in self._db.scalars(
                    select(Listing).where(Listing.id.in_(listing_ids), published)
                )
            }
            required: dict[uuid.UUID, set[uuid.UUID]] = {}
            partners: dict[uuid.UUID, set[uuid.UUID]] = {}
            if found:
                for listing_id, offer_id in self._db.execute(
                    select(ListingOffer.listing_id, ListingOffer.id).where(
                        ListingOffer.listing_id.in_(found), ListingOffer.is_required
                    )
                ):
                    required.setdefault(listing_id, set()).add(offer_id)
                for listing_id, partner_id in self._db.execute(
                    select(listing_partners.c.listing_id, listing_partners.c.partner_listing_id)
                    .where(listing_partners.c.listing_id.in_(found))
                ):  # fmt: skip
                    partners.setdefault(listing_id, set()).add(partner_id)
            for listing_id in listing_ids:
                listing = found.get(listing_id)
                self._listings[listing_id] = (
                    None
                    if listing is None
                    else CatalogItem(
                        listing_id=listing.id,
                        category=listing.category_slug,
                        name=listing.title,
                        pricing_model=listing.pricing_model,
                        unit_price_cents=listing.price_from_cents,
                        minimum_cents=listing.minimum_price_cents,
                        currency=listing.currency,
                        image_url=listing.cover_image_url,
                        capacity=listing.capacity,
                        vendor_id=listing.vendor_id,
                        required_offer_ids=frozenset(required.get(listing.id, ())),
                        partner_listing_ids=frozenset(partners.get(listing.id, ())),
                    )
                )

        if offer_ids:
            # Um serviço próprio só existe enquanto o anúncio dele está publicado.
            rows = self._db.execute(
                select(ListingOffer, Listing)
                .join(Listing, Listing.id == ListingOffer.listing_id)
                .where(ListingOffer.id.in_(offer_ids), published)
            )
            own_services = {offer.id: (offer, listing) for offer, listing in rows}
            for offer_id in offer_ids:
                pair = own_services.get(offer_id)
                self._offers[offer_id] = (
                    None
                    if pair is None
                    else CatalogItem(
                        listing_id=pair[1].id,
                        offer_id=pair[0].id,
                        category=pair[0].category_slug,
                        name=pair[0].name,
                        pricing_model=pair[0].pricing_model,
                        unit_price_cents=pair[0].price_cents,
                        minimum_cents=pair[0].minimum_price_cents,
                        currency=pair[1].currency,
                        # Um serviço não tem foto: fica a do anúncio a que pertence.
                        image_url=pair[1].cover_image_url,
                        vendor_id=pair[1].vendor_id,
                        required=pair[0].is_required,
                    )
                )


class PartyService:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_parties(self, owner: User) -> list[Party]:
        # selectinload traz itens, snapshots e histórico em três consultas
        # extras no total, e não uma por festa.
        return list(
            self._db.scalars(
                select(Party)
                .where(Party.owner_id == owner.id)
                .options(*WITH_CHILDREN)
                .order_by(Party.updated_at.desc(), Party.id)
                .limit(MAX_PARTIES_PER_USER)
            )
        )

    def get_party(self, owner: User, party_id: uuid.UUID) -> Party:
        party = self._find(owner, party_id)
        if party is None:
            raise PartyNotFoundError
        return party

    def save_party(self, owner: User, party_id: uuid.UUID, data: PartyInput) -> tuple[Party, bool]:
        """Grava o estado desejado. Devolve a festa e se ela foi criada agora."""
        party = self._find(owner, party_id, for_update=True)
        current = to_state(party) if party is not None else None
        desired = data.to_desired()
        is_stale = party is not None and data.version is not None and data.version != party.version

        try:
            new_state = reconcile(
                current,
                desired,
                catalog=self._catalog(current, data),
                now=utcnow(),
            )
        except AppError:
            # O pedido foi montado sobre uma cópia antiga da festa (a resposta
            # de um fornecedor, ou outro aparelho, mudou-a nesse meio tempo). A
            # regra que falhou é consequência disso: o que o app precisa saber
            # é que tem de recarregar.
            if is_stale:
                raise PartyVersionConflictError from None
            raise

        if party is None:
            # O cliente acha que a festa existe, mas ela foi apagada.
            if data.version:
                raise PartyNotFoundError
            return self._create(owner, party_id, new_state), True

        if new_state == current:
            # Nada a fazer. Também torna seguro repetir uma requisição cuja
            # resposta se perdeu no caminho.
            return party, False
        if is_stale:
            raise PartyVersionConflictError

        with self._translating_errors():
            self._apply(party, current, new_state)
            self._db.commit()
        return party, False

    def delete_party(self, owner: User, party_id: uuid.UUID) -> None:
        party = self._find(owner, party_id)
        if party is None:
            raise PartyNotFoundError
        if party.status is PartyStatus.PAID:
            raise PaidPartyCannotBeDeletedError
        if party.status in SUBMITTED:
            # O pedido chegou a fornecedores: some para eles só depois de um
            # cancelamento, que fica registrado.
            raise PartyHasOpenQuoteError
        self._db.delete(party)
        self._db.commit()

    # ------------------------------------------------------------------

    def _find(self, owner: User, party_id: uuid.UUID, *, for_update: bool = False) -> Party | None:
        # O dono faz parte do filtro: a festa de outra pessoa simplesmente "não
        # existe" para quem pergunta, sem revelar que o id é válido.
        statement = (
            select(Party)
            .where(Party.id == party_id, Party.owner_id == owner.id)
            .options(*WITH_CHILDREN)
        )
        if for_update:
            statement = statement.with_for_update(of=Party)
        return self._db.scalar(statement)

    def _catalog(self, current: PartyState | None, data: PartyInput) -> Catalog:
        reader = _CatalogReader(self._db)
        if data.status is PartyStatus.LOCKED:
            # Solicitar o orçamento confere se cada item continua disponível:
            # todos de uma vez.
            items = current.items if current is not None else ()
            reader.preload(
                [*(i.listing_id for i in items if i.listing_id), *data.listing_ids()],
                [*(i.offer_id for i in items if i.offer_id), *data.offer_ids()],
            )

        event_types: frozenset[str] = frozenset()
        previous = current.event_type if current is not None else None
        if data.event_type is not None and data.event_type != previous:
            event_types = frozenset(
                self._db.scalars(select(EventType.slug).where(EventType.is_active))
            )
        return Catalog(listing=reader.listing, offer=reader.offer, event_types=event_types)

    def _create(self, owner: User, party_id: uuid.UUID, state: PartyState) -> Party:
        total = self._db.scalar(
            select(func.count()).select_from(Party).where(Party.owner_id == owner.id)
        )
        if total is not None and total >= MAX_PARTIES_PER_USER:
            raise PartyLimitReachedError

        now = utcnow()
        party = Party(
            id=party_id,
            owner_id=owner.id,
            title=state.title,
            event_type=state.event_type,
            event_at=state.event_at,
            guest_count=state.guest_count,
            status=state.status,
            quote_round=state.quote_round,
            created_at=now,
            updated_at=now,
            items=[],
            snapshot=None,
            events=[],
        )
        with self._translating_errors():
            self._db.add(party)
            self._sync_items(party, state)
            self._db.commit()
        return party

    def _apply(self, party: Party, current: PartyState | None, new_state: PartyState) -> None:
        was_submitted = party.status in SUBMITTED
        is_submitted = new_state.status in SUBMITTED

        party.title = new_state.title
        party.event_type = new_state.event_type
        party.event_at = new_state.event_at
        party.guest_count = new_state.guest_count
        party.status = new_state.status
        party.quote_round = new_state.quote_round
        # Sempre toca a linha da festa: é isso que faz a versão avançar mesmo
        # quando só os itens mudaram.
        party.updated_at = utcnow()

        wanted = {item.id: item for item in new_state.items}
        # Quem fica já passa a apontar para o item certo (ou para nenhum) antes
        # de o que saiu ser apagado: assim a ligação nunca aponta para uma
        # linha que deixou de existir.
        for item in party.items:
            if item.id in wanted:
                item.parent_item_id = wanted[item.id].parent_item_id
        party.items = [item for item in party.items if item.id in wanted]
        if was_submitted and not is_submitted:
            party.snapshot = None
        # Apaga o que saiu antes de inserir o que entrou: trocar um salão por
        # outro na mesma gravação não pode esbarrar no índice de salão único.
        self._db.flush()

        self._sync_items(party, new_state)
        if is_submitted and not was_submitted:
            party.snapshot = self._build_snapshot(party, new_state)
        entry = describe_transition(current, new_state)
        if entry is not None:
            record(party, entry)

    def _sync_items(self, party: Party, state: PartyState) -> None:
        existing = {item.id: item for item in party.items}
        synced: list[PartyItem] = []
        fresh: list[PartyItem] = []
        for position, wanted in enumerate(state.items):
            item = existing.get(wanted.id)
            if item is None:
                item = PartyItem(
                    id=wanted.id,
                    listing_id=wanted.listing_id,
                    offer_id=wanted.offer_id,
                    vendor_id=wanted.vendor_id,
                    category=wanted.category,
                    name=wanted.name,
                    pricing_model=wanted.pricing_model,
                    unit_price_cents=wanted.unit_price_cents,
                    minimum_cents=wanted.minimum_cents,
                    currency=wanted.currency,
                    image_url=wanted.image_url,
                    capacity=wanted.capacity,
                )
                fresh.append(item)
            item.relation = wanted.relation
            item.quantity = wanted.quantity
            item.configuration = dict(wanted.configuration)
            item.position = position
            write_quote(item, wanted.quote)
            synced.append(item)
        party.items = synced

        # Um item novo pode estar ligado a outro que entra na mesma gravação.
        # A linha de que ele depende precisa existir primeiro: a ligação é
        # gravada depois que todos entraram.
        parents = {wanted.id: wanted.parent_item_id for wanted in state.items}
        linked = [item for item in fresh if parents[item.id] is not None]
        if linked:
            self._db.flush()
            for item in linked:
                item.parent_item_id = parents[item.id]

    @staticmethod
    def _build_snapshot(party: Party, state: PartyState) -> PartySnapshot:
        return PartySnapshot(
            party_id=party.id,
            generated_at=utcnow(),
            total_cents=state.estimate_cents,
            currency=state.items[0].currency,
            breakdown=[
                {
                    "listing_id": str(item.listing_id) if item.listing_id else None,
                    "offer_id": str(item.offer_id) if item.offer_id else None,
                    "category": item.category,
                    "name": item.name,
                    "pricing_model": item.pricing_model.value,
                    "unit_price_cents": item.unit_price_cents,
                    "quantity": item.quantity,
                    # Nulo quando o item não tem como ser estimado.
                    "subtotal_cents": item.estimate_cents(state.guest_count),
                }
                for item in state.items
            ],
        )

    @contextmanager
    def _translating_errors(self) -> Iterator[None]:
        try:
            yield
        except StaleDataError as exc:
            # Outra requisição gravou a festa entre a leitura e o UPDATE.
            self._db.rollback()
            raise PartyVersionConflictError from exc
        except IntegrityError as exc:
            # Id de festa ou de item já usado por outro registro.
            self._db.rollback()
            raise PartyIdConflictError from exc
