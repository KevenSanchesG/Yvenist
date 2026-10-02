"""Persistência das festas. As regras ficam em ``domain.reconcile``."""

import uuid
from collections.abc import Iterator
from contextlib import contextmanager

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload
from sqlalchemy.orm.exc import StaleDataError

from app.core.database import utcnow
from app.core.errors import ConflictError, NotFoundError
from app.modules.accounts.models import User
from app.modules.catalog.models import Listing, ListingStatus
from app.modules.parties.domain import (
    CatalogItem,
    ItemState,
    PartyState,
    PartyStatus,
    reconcile,
)
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


_WITH_CHILDREN = (selectinload(Party.items), selectinload(Party.snapshot))


def _to_state(party: Party) -> PartyState:
    return PartyState(
        title=party.title,
        event_at=party.event_at,
        guest_count=party.guest_count,
        status=party.status,
        items=tuple(
            ItemState(
                id=item.id,
                listing_id=item.listing_id,
                category=item.category,
                name=item.name,
                unit_price_cents=item.unit_price_cents,
                currency=item.currency,
                quantity=item.quantity,
                image_url=item.image_url,
            )
            for item in party.items
        ),
    )


class PartyService:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_parties(self, owner: User) -> list[Party]:
        # selectinload traz itens e snapshots em duas consultas extras no total,
        # e não uma por festa.
        return list(
            self._db.scalars(
                select(Party)
                .where(Party.owner_id == owner.id)
                .options(*_WITH_CHILDREN)
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
        current = _to_state(party) if party is not None else None
        new_state = reconcile(current, data.to_desired(), lookup=self._lookup_listing)

        if party is None:
            # O cliente acha que a festa existe, mas ela foi apagada.
            if data.version:
                raise PartyNotFoundError
            return self._create(owner, party_id, new_state), True

        if new_state == current:
            # Nada a fazer. Também torna seguro repetir uma requisição cuja
            # resposta se perdeu no caminho.
            return party, False
        if data.version is not None and data.version != party.version:
            raise PartyVersionConflictError

        with self._translating_errors():
            self._apply(party, new_state)
            self._db.commit()
        return party, False

    def delete_party(self, owner: User, party_id: uuid.UUID) -> None:
        party = self._find(owner, party_id)
        if party is None:
            raise PartyNotFoundError
        if party.status is PartyStatus.PAID:
            raise PaidPartyCannotBeDeletedError
        self._db.delete(party)
        self._db.commit()

    # ------------------------------------------------------------------

    def _find(self, owner: User, party_id: uuid.UUID, *, for_update: bool = False) -> Party | None:
        # O dono faz parte do filtro: a festa de outra pessoa simplesmente "não
        # existe" para quem pergunta, sem revelar que o id é válido.
        statement = (
            select(Party)
            .where(Party.id == party_id, Party.owner_id == owner.id)
            .options(*_WITH_CHILDREN)
        )
        if for_update:
            statement = statement.with_for_update(of=Party)
        return self._db.scalar(statement)

    def _lookup_listing(self, listing_id: uuid.UUID) -> CatalogItem | None:
        listing = self._db.scalar(
            select(Listing).where(
                Listing.id == listing_id, Listing.status == ListingStatus.PUBLISHED
            )
        )
        if listing is None:
            return None
        return CatalogItem(
            listing_id=listing.id,
            category=listing.category_slug,
            name=listing.title,
            unit_price_cents=listing.price_from_cents,
            currency=listing.currency,
            image_url=listing.cover_image_url,
        )

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
            event_at=state.event_at,
            guest_count=state.guest_count,
            status=state.status,
            created_at=now,
            updated_at=now,
            items=[],
            snapshot=None,
        )
        self._upsert_items(party, state)
        with self._translating_errors():
            self._db.add(party)
            self._db.commit()
        return party

    def _apply(self, party: Party, new_state: PartyState) -> None:
        was_locked = party.status is PartyStatus.LOCKED
        is_locked = new_state.status is PartyStatus.LOCKED

        party.title = new_state.title
        party.event_at = new_state.event_at
        party.guest_count = new_state.guest_count
        party.status = new_state.status
        # Sempre toca a linha da festa: é isso que faz a versão avançar mesmo
        # quando só os itens mudaram.
        party.updated_at = utcnow()

        wanted_ids = {item.id for item in new_state.items}
        party.items = [item for item in party.items if item.id in wanted_ids]
        if was_locked and not is_locked:
            party.snapshot = None
        # Apaga o que saiu antes de inserir o que entrou: trocar um salão por
        # outro na mesma gravação não pode esbarrar no índice de salão único.
        self._db.flush()

        self._upsert_items(party, new_state)
        if is_locked and not was_locked:
            party.snapshot = self._build_snapshot(party, new_state)

    @staticmethod
    def _upsert_items(party: Party, state: PartyState) -> None:
        existing = {item.id: item for item in party.items}
        synced: list[PartyItem] = []
        for position, wanted in enumerate(state.items):
            item = existing.get(wanted.id)
            if item is None:
                item = PartyItem(
                    id=wanted.id,
                    listing_id=wanted.listing_id,
                    category=wanted.category,
                    name=wanted.name,
                    unit_price_cents=wanted.unit_price_cents,
                    currency=wanted.currency,
                    image_url=wanted.image_url,
                )
            item.quantity = wanted.quantity
            item.position = position
            synced.append(item)
        party.items = synced

    @staticmethod
    def _build_snapshot(party: Party, state: PartyState) -> PartySnapshot:
        return PartySnapshot(
            party_id=party.id,
            generated_at=utcnow(),
            total_cents=state.total_cents,
            currency=state.items[0].currency,
            breakdown=[
                {
                    "listing_id": str(item.listing_id) if item.listing_id else None,
                    "category": item.category,
                    "name": item.name,
                    "unit_price_cents": item.unit_price_cents,
                    "quantity": item.quantity,
                    "subtotal_cents": item.subtotal_cents,
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
