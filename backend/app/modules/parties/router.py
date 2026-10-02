import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import CurrentUser, DbSession
from app.modules.parties.schemas import PartyInput, PartyListResponse, PartyResponse
from app.modules.parties.service import PartyService

router = APIRouter(prefix="/parties", tags=["Festas"])


def get_party_service(db: DbSession) -> PartyService:
    return PartyService(db)


PartyServiceDep = Annotated[PartyService, Depends(get_party_service)]


@router.get("", summary="Festas do usuário")
def list_parties(user: CurrentUser, service: PartyServiceDep) -> PartyListResponse:
    return PartyListResponse(
        items=[PartyResponse.from_party(party) for party in service.list_parties(user)]
    )


@router.get("/{party_id}", summary="Uma festa do usuário")
def get_party(party_id: uuid.UUID, user: CurrentUser, service: PartyServiceDep) -> PartyResponse:
    return PartyResponse.from_party(service.get_party(user, party_id))


@router.put(
    "/{party_id}",
    summary="Cria ou atualiza a festa com o estado enviado",
    responses={status.HTTP_201_CREATED: {"model": PartyResponse}},
)
def save_party(
    party_id: uuid.UUID,
    data: PartyInput,
    user: CurrentUser,
    service: PartyServiceDep,
    response: Response,
) -> PartyResponse:
    party, created = service.save_party(user, party_id, data)
    if created:
        response.status_code = status.HTTP_201_CREATED
    return PartyResponse.from_party(party)


@router.delete(
    "/{party_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Apaga a festa",
)
def delete_party(party_id: uuid.UUID, user: CurrentUser, service: PartyServiceDep) -> Response:
    service.delete_party(user, party_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
