"""Pedidos de orçamento, do lado de quem os recebe: o fornecedor.

Um pedido é um item de uma festa cujo orçamento foi solicitado. O fornecedor vê
só os itens dos próprios anúncios, com o que precisa para dar o preço (tipo de
evento, data, convidados e a configuração do item), e nada sobre quem pediu. As
regras da resposta ficam em ``parties.domain.apply_vendor_response``.
"""

import uuid
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session, aliased

from app.core.database import utcnow
from app.core.errors import NotFoundError
from app.modules.accounts.models import User
from app.modules.parties.domain import (
    ANSWERABLE,
    SUBMITTED,
    PartyStatus,
    QuoteStatus,
    VendorResponse,
    apply_vendor_response,
)
from app.modules.parties.mapping import record, to_state, write_quote
from app.modules.parties.models import Party, PartyItem
from app.modules.parties.service import WITH_CHILDREN
from app.modules.vendors.models import VendorProfile
from app.modules.vendors.service import VendorProfileNotFoundError

MAX_REQUESTS_PER_PAGE = 100

# O que o fornecedor enxerga: festas com o orçamento solicitado e as que foram
# canceladas depois disso. Uma festa que voltou para a edição some daqui: o
# fornecedor não acompanha o que o cliente ainda está mudando.
_VISIBLE_TO_VENDOR = (*SUBMITTED, PartyStatus.CANCELLED)


class QuoteRequestNotFoundError(NotFoundError):
    code = "quote_request_not_found"
    message = "Pedido de orçamento não encontrado."


@dataclass(frozen=True)
class QuoteRequest:
    item: PartyItem
    party: Party
    # O item a que este está ligado, quando é um serviço do próprio anúncio.
    parent_name: str | None

    @property
    def can_respond(self) -> bool:
        return self.party.status in ANSWERABLE


class QuoteInboxService:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_requests(self, user: User) -> list[QuoteRequest]:
        vendor = self._vendor_of(user)
        parent = aliased(PartyItem)
        rows = self._db.execute(
            select(PartyItem, Party, parent.name)
            .join(Party, Party.id == PartyItem.party_id)
            .outerjoin(parent, parent.id == PartyItem.parent_item_id)
            .where(
                PartyItem.vendor_id == vendor.id,
                PartyItem.quote_status != QuoteStatus.NONE,
                Party.status.in_(_VISIBLE_TO_VENDOR),
            )
            # O que mudou por último primeiro; dentro de uma festa, na ordem dela.
            .order_by(Party.updated_at.desc(), Party.id, PartyItem.position)
            .limit(MAX_REQUESTS_PER_PAGE)
        )
        return [QuoteRequest(item, party, parent_name) for item, party, parent_name in rows]

    def respond(self, user: User, item_id: uuid.UUID, response: VendorResponse) -> QuoteRequest:
        vendor = self._vendor_of(user)
        # O fornecedor faz parte do filtro: o item de outro anunciante
        # simplesmente "não existe" para quem pergunta.
        party_id = self._db.scalar(
            select(PartyItem.party_id).where(
                PartyItem.id == item_id, PartyItem.vendor_id == vendor.id
            )
        )
        if party_id is None:
            raise QuoteRequestNotFoundError

        # A festa é travada: a resposta e uma gravação do cliente (voltar a
        # editar, cancelar) acontecem uma depois da outra, nunca juntas.
        party = self._db.scalar(
            select(Party).where(Party.id == party_id).options(*WITH_CHILDREN).with_for_update()
        )
        if party is None:
            raise QuoteRequestNotFoundError

        new_state, entry = apply_vendor_response(to_state(party), item_id, response, now=utcnow())
        answered = next(item for item in new_state.items if item.id == item_id)
        item = next(item for item in party.items if item.id == item_id)
        write_quote(item, answered.quote)
        party.status = new_state.status
        # Avança a versão da festa: o app do cliente descobre, na próxima
        # gravação, que a cópia dele ficou para trás.
        party.updated_at = utcnow()
        record(party, entry)
        self._db.commit()

        parent_name = next(
            (other.name for other in party.items if other.id == item.parent_item_id), None
        )
        return QuoteRequest(item, party, parent_name)

    def _vendor_of(self, user: User) -> VendorProfile:
        vendor = self._db.scalar(select(VendorProfile).where(VendorProfile.user_id == user.id))
        if vendor is None:
            raise VendorProfileNotFoundError
        return vendor
