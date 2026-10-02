import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import (
    CurrentUser,
    DbSession,
    PasswordHasherDep,
    SettingsDep,
    UserAgent,
    limit_login,
    limit_register,
)
from app.modules.accounts.models import User
from app.modules.accounts.schemas import (
    AuthResponse,
    ChangePasswordRequest,
    DeleteAccountRequest,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    SessionResponse,
    TokenPair,
    UpdateProfileRequest,
    UserResponse,
)
from app.modules.accounts.service import AccountService, IssuedTokens

auth_router = APIRouter(prefix="/auth", tags=["Autenticação"])
users_router = APIRouter(prefix="/users", tags=["Usuários"])


def get_account_service(
    db: DbSession,
    settings: SettingsDep,
    hasher: PasswordHasherDep,
) -> AccountService:
    return AccountService(db, settings, hasher)


AccountServiceDep = Annotated[AccountService, Depends(get_account_service)]


def _token_pair(tokens: IssuedTokens) -> TokenPair:
    return TokenPair(
        access_token=tokens.access_token,
        refresh_token=tokens.refresh_token,
        expires_in=tokens.expires_in,
    )


def _auth_response(user: User, tokens: IssuedTokens) -> AuthResponse:
    return AuthResponse(user=UserResponse.model_validate(user), tokens=_token_pair(tokens))


@auth_router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(limit_register)],
    summary="Cria uma conta e já devolve a sessão",
)
def register(
    data: RegisterRequest,
    service: AccountServiceDep,
    user_agent: UserAgent = None,
) -> AuthResponse:
    user, tokens = service.register(data, user_agent=user_agent)
    return _auth_response(user, tokens)


@auth_router.post(
    "/login",
    dependencies=[Depends(limit_login)],
    summary="Autentica com e-mail e senha",
)
def login(
    data: LoginRequest,
    service: AccountServiceDep,
    user_agent: UserAgent = None,
) -> AuthResponse:
    user, tokens = service.login(data.email, data.password, user_agent=user_agent)
    return _auth_response(user, tokens)


@auth_router.post(
    "/refresh",
    dependencies=[Depends(limit_login)],
    summary="Troca o token de renovação por um novo par de tokens",
)
def refresh(
    data: RefreshRequest,
    service: AccountServiceDep,
    user_agent: UserAgent = None,
) -> AuthResponse:
    user, tokens = service.refresh(data.refresh_token, user_agent=user_agent)
    return _auth_response(user, tokens)


@auth_router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Encerra a sessão do token de renovação informado",
)
def logout(data: LogoutRequest, service: AccountServiceDep) -> Response:
    service.logout(data.refresh_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@users_router.get("/me", summary="Dados da conta autenticada")
def get_me(user: CurrentUser) -> UserResponse:
    return UserResponse.model_validate(user)


@users_router.patch("/me", summary="Atualiza os dados pessoais")
def update_me(
    data: UpdateProfileRequest,
    user: CurrentUser,
    service: AccountServiceDep,
) -> UserResponse:
    return UserResponse.model_validate(service.update_profile(user, data))


@users_router.post(
    "/me/password",
    dependencies=[Depends(limit_login)],
    summary="Troca a senha e encerra as outras sessões",
)
def change_password(
    data: ChangePasswordRequest,
    user: CurrentUser,
    service: AccountServiceDep,
    user_agent: UserAgent = None,
) -> TokenPair:
    tokens = service.change_password(
        user,
        current_password=data.current_password,
        new_password=data.new_password,
        user_agent=user_agent,
    )
    return _token_pair(tokens)


@users_router.post(
    "/me/delete",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(limit_login)],
    summary="Apaga a conta e os dados associados (LGPD)",
)
def delete_me(
    data: DeleteAccountRequest,
    user: CurrentUser,
    service: AccountServiceDep,
) -> Response:
    # POST em vez de DELETE porque a confirmação por senha vai no corpo, e corpo
    # em DELETE não é garantido por proxies e clientes HTTP.
    service.delete_account(user, password=data.password)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@users_router.get("/me/sessions", summary="Dispositivos conectados")
def list_sessions(user: CurrentUser, service: AccountServiceDep) -> list[SessionResponse]:
    return [SessionResponse.model_validate(s) for s in service.list_sessions(user)]


@users_router.delete(
    "/me/sessions/{session_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Encerra a sessão de um dispositivo",
)
def revoke_session(
    session_id: uuid.UUID,
    user: CurrentUser,
    service: AccountServiceDep,
) -> Response:
    service.revoke_session(user, session_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
