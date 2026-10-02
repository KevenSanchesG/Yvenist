"""Casos de uso de contas: cadastro, login, sessões e dados pessoais."""

import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.database import utcnow
from app.core.errors import ConflictError, NotFoundError, UnauthorizedError, UnprocessableError
from app.core.security import (
    PasswordHasher,
    create_access_token,
    generate_refresh_token,
    hash_refresh_token,
)
from app.modules.accounts.models import RefreshToken, User
from app.modules.accounts.schemas import RegisterRequest, UpdateProfileRequest

_USER_AGENT_MAX_LENGTH = 255


class EmailAlreadyRegisteredError(ConflictError):
    code = "email_already_registered"
    message = "Já existe uma conta com este e-mail."


class InvalidCredentialsError(UnauthorizedError):
    code = "invalid_credentials"
    message = "E-mail ou senha inválidos."


class InvalidRefreshTokenError(UnauthorizedError):
    code = "invalid_refresh_token"
    message = "Sessão expirada. Entre novamente."


class WrongPasswordError(UnprocessableError):
    code = "wrong_password"
    message = "Senha atual incorreta."


@dataclass(frozen=True)
class IssuedTokens:
    access_token: str
    refresh_token: str
    expires_in: int


def normalize_email(email: str) -> str:
    return email.strip().lower()


class AccountService:
    def __init__(self, db: Session, settings: Settings, hasher: PasswordHasher) -> None:
        self._db = db
        self._settings = settings
        self._hasher = hasher

    # ------------------------------------------------------------------
    # Cadastro e autenticação
    # ------------------------------------------------------------------

    def register(
        self, data: RegisterRequest, *, user_agent: str | None
    ) -> tuple[User, IssuedTokens]:
        email = normalize_email(data.email)
        if self._db.scalar(select(User.id).where(User.email == email)) is not None:
            raise EmailAlreadyRegisteredError

        user = User(
            email=email,
            password_hash=self._hasher.hash(data.password),
            full_name=data.full_name,
            terms_version=self._settings.terms_version,
            terms_accepted_at=utcnow(),
        )
        self._db.add(user)
        try:
            self._db.flush()
        except IntegrityError as exc:
            # Dois cadastros simultâneos com o mesmo e-mail: o índice único decide.
            self._db.rollback()
            raise EmailAlreadyRegisteredError from exc

        tokens = self._issue_tokens(user, family_id=uuid.uuid4(), user_agent=user_agent)
        self._db.commit()
        return user, tokens

    def login(
        self, email: str, password: str, *, user_agent: str | None
    ) -> tuple[User, IssuedTokens]:
        user = self._db.scalar(select(User).where(User.email == normalize_email(email)))
        if user is None:
            # Gasta o mesmo tempo de uma verificação real para não revelar, pela
            # demora, se o e-mail está cadastrado.
            self._hasher.verify_dummy(password)
            raise InvalidCredentialsError

        valid, updated_hash = self._hasher.verify(password, user.password_hash)
        if not valid or not user.is_active:
            raise InvalidCredentialsError
        if updated_hash is not None:
            user.password_hash = updated_hash

        self._purge_expired_tokens(user.id)
        tokens = self._issue_tokens(user, family_id=uuid.uuid4(), user_agent=user_agent)
        self._db.commit()
        return user, tokens

    def refresh(self, refresh_token: str, *, user_agent: str | None) -> tuple[User, IssuedTokens]:
        stored = self._db.scalar(
            select(RefreshToken)
            .where(RefreshToken.token_hash == hash_refresh_token(refresh_token))
            .with_for_update()
        )
        if stored is None:
            raise InvalidRefreshTokenError

        now = utcnow()
        if stored.revoked_at is not None:
            # Um token já trocado voltou a ser usado: alguém tem uma cópia dele.
            # Encerra a família inteira e obriga um novo login.
            self._revoke_family(stored.family_id, now)
            self._db.commit()
            raise InvalidRefreshTokenError
        if stored.expires_at <= now:
            raise InvalidRefreshTokenError

        user = self._db.get(User, stored.user_id)
        if user is None or not user.is_active:
            raise InvalidRefreshTokenError

        stored.revoked_at = now
        tokens = self._issue_tokens(
            user,
            family_id=stored.family_id,
            user_agent=user_agent or stored.user_agent,
        )
        self._db.commit()
        return user, tokens

    def logout(self, refresh_token: str) -> None:
        """Encerra a sessão do token informado. Não falha se o token não existir."""
        stored = self._db.scalar(
            select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(refresh_token))
        )
        if stored is not None:
            self._revoke_family(stored.family_id, utcnow())
            self._db.commit()

    # ------------------------------------------------------------------
    # Dados pessoais
    # ------------------------------------------------------------------

    def update_profile(self, user: User, data: UpdateProfileRequest) -> User:
        changes = data.model_dump(exclude_unset=True)
        if "full_name" in changes and changes["full_name"] is None:
            raise UnprocessableError("O nome não pode ficar vazio.", code="validation_error")
        for field, value in changes.items():
            setattr(user, field, value)
        self._db.commit()
        return user

    def change_password(
        self,
        user: User,
        *,
        current_password: str,
        new_password: str,
        user_agent: str | None,
    ) -> IssuedTokens:
        valid, _ = self._hasher.verify(current_password, user.password_hash)
        if not valid:
            raise WrongPasswordError

        user.password_hash = self._hasher.hash(new_password)
        # Derruba todas as sessões: quem tinha a senha antiga perde o acesso.
        user.token_version += 1
        self._revoke_all_tokens(user.id, utcnow())
        tokens = self._issue_tokens(user, family_id=uuid.uuid4(), user_agent=user_agent)
        self._db.commit()
        return tokens

    def delete_account(self, user: User, *, password: str) -> None:
        """Apaga a conta e tudo que pertence a ela (direito de eliminação, LGPD)."""
        valid, _ = self._hasher.verify(password, user.password_hash)
        if not valid:
            raise WrongPasswordError("Senha incorreta.")
        self._db.delete(user)
        self._db.commit()

    # ------------------------------------------------------------------
    # Sessões (dispositivos conectados)
    # ------------------------------------------------------------------

    def list_sessions(self, user: User) -> list[RefreshToken]:
        return list(
            self._db.scalars(
                select(RefreshToken)
                .where(
                    RefreshToken.user_id == user.id,
                    RefreshToken.revoked_at.is_(None),
                    RefreshToken.expires_at > utcnow(),
                )
                .order_by(RefreshToken.created_at.desc())
            )
        )

    def revoke_session(self, user: User, session_id: uuid.UUID) -> None:
        stored = self._db.scalar(
            select(RefreshToken).where(
                RefreshToken.id == session_id,
                # Filtrar pelo dono impede encerrar a sessão de outra pessoa.
                RefreshToken.user_id == user.id,
            )
        )
        if stored is None:
            raise NotFoundError("Sessão não encontrada.", code="session_not_found")
        self._revoke_family(stored.family_id, utcnow())
        self._db.commit()

    # ------------------------------------------------------------------
    # Internos
    # ------------------------------------------------------------------

    def _issue_tokens(
        self,
        user: User,
        *,
        family_id: uuid.UUID,
        user_agent: str | None,
    ) -> IssuedTokens:
        now = utcnow()
        access_ttl = timedelta(minutes=self._settings.access_token_ttl_minutes)
        access_token, _ = create_access_token(
            user_id=user.id,
            token_version=user.token_version,
            secret=self._settings.jwt_secret.get_secret_value(),
            ttl=access_ttl,
            now=now,
        )
        refresh_token = generate_refresh_token()
        self._db.add(
            RefreshToken(
                user_id=user.id,
                family_id=family_id,
                token_hash=hash_refresh_token(refresh_token),
                user_agent=user_agent[:_USER_AGENT_MAX_LENGTH] if user_agent else None,
                created_at=now,
                expires_at=now + timedelta(days=self._settings.refresh_token_ttl_days),
            )
        )
        return IssuedTokens(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=int(access_ttl.total_seconds()),
        )

    def _revoke_family(self, family_id: uuid.UUID, now: datetime) -> None:
        self._db.execute(
            update(RefreshToken)
            .where(RefreshToken.family_id == family_id, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=now)
        )

    def _revoke_all_tokens(self, user_id: uuid.UUID, now: datetime) -> None:
        self._db.execute(
            update(RefreshToken)
            .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=now)
        )

    def _purge_expired_tokens(self, user_id: uuid.UUID) -> None:
        self._db.execute(
            delete(RefreshToken).where(
                RefreshToken.user_id == user_id,
                RefreshToken.expires_at <= utcnow(),
            )
        )
