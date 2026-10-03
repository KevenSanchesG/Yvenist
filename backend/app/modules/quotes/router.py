import uuid
from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import CurrentUser, DbSession
from app.modules.parties.domain import QuoteStatus, VendorResponse
from app.modules.quotes.schemas import (
    QuoteAmountInput,
    QuoteExplanationInput,
    QuoteRequestResponse,
    QuoteRequestsResponse,
)
from app.modules.quotes.service import QuoteInboxService

router = APIRouter(prefix="/vendors/me/quote-requests", tags=["Pedidos de orçamento"])


def get_quote_inbox_service(db: DbSession) -> QuoteInboxService:
    return QuoteInboxService(db)


QuoteInboxServiceDep = Annotated[QuoteInboxService, Depends(get_quote_inbox_service)]


@router.get("", summary="Pedidos de orçamento recebidos pelo fornecedor")
def list_quote_requests(user: CurrentUser, service: QuoteInboxServiceDep) -> QuoteRequestsResponse:
    return QuoteRequestsResponse(
        items=[
            QuoteRequestResponse.from_request(request) for request in service.list_requests(user)
        ]
    )


@router.post("/{item_id}/quote", summary="Informa o valor do item")
def quote_item(
    item_id: uuid.UUID,
    data: QuoteAmountInput,
    user: CurrentUser,
    service: QuoteInboxServiceDep,
) -> QuoteRequestResponse:
    response = VendorResponse(
        status=QuoteStatus.QUOTED, amount_cents=data.amount_cents, message=data.message
    )
    return QuoteRequestResponse.from_request(service.respond(user, item_id, response))


@router.post("/{item_id}/request-changes", summary="Pede ao cliente que altere o item")
def request_changes(
    item_id: uuid.UUID,
    data: QuoteExplanationInput,
    user: CurrentUser,
    service: QuoteInboxServiceDep,
) -> QuoteRequestResponse:
    response = VendorResponse(status=QuoteStatus.CHANGES_REQUESTED, message=data.message)
    return QuoteRequestResponse.from_request(service.respond(user, item_id, response))


@router.post("/{item_id}/decline", summary="Avisa que não pode atender o item")
def decline_item(
    item_id: uuid.UUID,
    data: QuoteExplanationInput,
    user: CurrentUser,
    service: QuoteInboxServiceDep,
) -> QuoteRequestResponse:
    response = VendorResponse(status=QuoteStatus.DECLINED, message=data.message)
    return QuoteRequestResponse.from_request(service.respond(user, item_id, response))
