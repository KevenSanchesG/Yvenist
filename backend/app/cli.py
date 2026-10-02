"""Comandos de administração: ``python -m app.cli <comando>``.

- ``create-admin``: cria um usuário administrador (ou promove um existente);
- ``seed-demo``: popula o catálogo com dados de demonstração (nunca em produção);
- ``purge-tokens``: apaga sessões expiradas ou encerradas há muito tempo.
"""

import argparse
import getpass
import os
import secrets
import sys
from collections.abc import Sequence
from datetime import timedelta
from decimal import Decimal

from pydantic import EmailStr, TypeAdapter, ValidationError
from sqlalchemy import delete, func, or_, select
from sqlalchemy.orm import Session

from app import models  # noqa: F401  (registra as tabelas)
from app.core.config import Settings
from app.core.database import create_db_engine, create_session_factory, utcnow
from app.core.security import PasswordHasher
from app.modules.accounts.models import RefreshToken, User
from app.modules.accounts.schemas import PASSWORD_MIN_LENGTH
from app.modules.accounts.service import normalize_email
from app.modules.catalog.models import Category, EventType, Listing, ListingStatus
from app.modules.catalog.text import build_search_text
from app.modules.vendors.models import PersonType, VendorProfile, VendorStatus

_EMAIL = TypeAdapter(EmailStr)

DEMO_VENDOR_EMAIL = "demo.fornecedor@yvenist.example"
# CPF de exemplo com dígitos verificadores válidos, usado só nos dados de demonstração.
DEMO_VENDOR_DOCUMENT = "52998224725"

_VENUE_IMAGE = (
    "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=600&q=80"
)
_ATTRACTION_IMAGE = (
    "https://images.unsplash.com/photo-1523438885200-e635ba2c371e?auto=format&fit=crop&w=600&q=80"
)

_DEMO_GROUPS = (
    # (categoria, título, bairro, preço inicial, incremento, nota, avaliações, imagem, eventos)
    ("venue", "Salão Glamour", "Campo Grande", 100_000, 10_000, "5.00", 120, _VENUE_IMAGE,
     ("wedding", "debutante", "graduation")),
    ("attraction", "Atração Festiva", "Barra da Tijuca", 80_000, 5_000, "4.80", 85,
     _ATTRACTION_IMAGE, ("kids_party", "corporate")),
    ("buffet", "Buffet Sabor & Festa", "Tijuca", 250_000, 15_000, "4.70", 60, _VENUE_IMAGE,
     ("wedding", "corporate", "barbecue")),
    ("decoration", "Decoração Encanto", "Recreio", 60_000, 4_000, "4.90", 40, _ATTRACTION_IMAGE,
     ("wedding", "debutante", "kids_party")),
)  # fmt: skip
_LISTINGS_PER_GROUP = 8


def validated_email(email: str) -> str:
    """Valida o e-mail com a mesma regra do login e devolve a forma gravada no banco.

    Sem isso seria possível criar um administrador com um endereço que a API
    recusa na hora de entrar (um domínio interno como ``admin@empresa.local``,
    por exemplo): a conta existiria, mas ninguém conseguiria usá-la.
    """
    try:
        return normalize_email(_EMAIL.validate_python(email.strip()))
    except ValidationError as error:
        raise ValueError(
            f"E-mail inválido: {email!r}. Use um endereço que possa entrar pelo app."
        ) from error


def create_admin(session: Session, hasher: PasswordHasher, settings: Settings, *,
                 email: str, full_name: str, password: str) -> str:  # fmt: skip
    """Cria o administrador ou promove a conta existente. Devolve o que foi feito."""
    normalized = validated_email(email)
    user = session.scalar(select(User).where(User.email == normalized))
    if user is not None:
        user.is_admin = True
        session.commit()
        return f"Conta existente promovida a administrador: {normalized}"

    if len(password) < PASSWORD_MIN_LENGTH:
        raise ValueError(f"A senha precisa ter pelo menos {PASSWORD_MIN_LENGTH} caracteres.")
    session.add(
        User(
            email=normalized,
            password_hash=hasher.hash(password),
            full_name=full_name,
            is_admin=True,
            terms_version=settings.terms_version,
            terms_accepted_at=utcnow(),
        )
    )
    session.commit()
    return f"Administrador criado: {normalized}"


def seed_demo(session: Session, hasher: PasswordHasher, settings: Settings) -> str:
    """Cria um fornecedor de demonstração com anúncios publicados. Idempotente."""
    if settings.is_production:
        raise RuntimeError("seed-demo não pode ser executado em produção.")
    if session.scalar(select(User.id).where(User.email == DEMO_VENDOR_EMAIL)) is not None:
        return "Dados de demonstração já existem; nada foi alterado."

    now = utcnow()
    owner = User(
        email=DEMO_VENDOR_EMAIL,
        # Senha aleatória que ninguém conhece: a conta existe só para ser dona
        # dos anúncios de demonstração.
        password_hash=hasher.hash(secrets.token_urlsafe(32)),
        full_name="Fornecedor Demonstração",
        terms_version=settings.terms_version,
        terms_accepted_at=now,
    )
    session.add(owner)
    session.flush()
    vendor = VendorProfile(
        user_id=owner.id,
        person_type=PersonType.INDIVIDUAL,
        document=DEMO_VENDOR_DOCUMENT,
        legal_name="Fornecedor Demonstração",
        status=VendorStatus.APPROVED,
        reviewed_at=now,
    )
    session.add(vendor)
    session.flush()

    categories = {category.slug: category for category in session.scalars(select(Category))}
    event_types = {event.slug: event for event in session.scalars(select(EventType))}
    total = 0
    for slug, title, neighborhood, base, step, rating, reviews, image, events in _DEMO_GROUPS:
        for index in range(_LISTINGS_PER_GROUP):
            name = f"{title} {index + 1}"
            session.add(
                Listing(
                    vendor_id=vendor.id,
                    category_slug=slug,
                    title=name,
                    description=f"{name}: anúncio de demonstração do Yvenist em {neighborhood}.",
                    neighborhood=neighborhood,
                    city="Rio de Janeiro",
                    state="RJ",
                    price_from_cents=base + index * step,
                    capacity=100 + index * 20 if slug == "venue" else None,
                    amenities=["kitchen", "parking", "wifi"] if slug == "venue" else [],
                    cover_image_url=image,
                    status=ListingStatus.PUBLISHED,
                    rating_average=Decimal(rating),
                    rating_count=reviews + index,
                    search_text=build_search_text(
                        name, neighborhood, "Rio de Janeiro", "RJ", categories[slug].name
                    ),
                    published_at=now - timedelta(minutes=total),
                    event_types=[event_types[event] for event in events],
                )
            )
            total += 1
    session.commit()
    return f"{total} anúncios de demonstração criados."


def purge_tokens(session: Session, *, older_than_days: int) -> str:
    """Apaga sessões que expiraram ou foram encerradas há mais de ``older_than_days``."""
    cutoff = utcnow() - timedelta(days=older_than_days)
    old = or_(RefreshToken.expires_at < cutoff, RefreshToken.revoked_at < cutoff)
    total = session.scalar(select(func.count()).select_from(RefreshToken).where(old))
    session.execute(delete(RefreshToken).where(old))
    session.commit()
    return f"{total} sessões antigas removidas."


def _read_admin_password() -> str:
    # Variável de ambiente para uso automatizado; senão, pergunta sem ecoar.
    from_env = os.environ.get("YVENIST_ADMIN_PASSWORD")
    if from_env:
        return from_env
    password = getpass.getpass("Senha do administrador: ")
    if password != getpass.getpass("Repita a senha: "):
        raise ValueError("As senhas não conferem.")
    return password


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="python -m app.cli", description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    admin = commands.add_parser("create-admin", help="cria ou promove um administrador")
    admin.add_argument("--email", required=True)
    admin.add_argument("--name", default="Administrador")

    commands.add_parser("seed-demo", help="popula o catálogo com dados de demonstração")

    purge = commands.add_parser("purge-tokens", help="apaga sessões antigas")
    purge.add_argument("--older-than-days", type=int, default=30)
    return parser


def main(argv: Sequence[str] | None = None, settings: Settings | None = None) -> int:
    arguments = _build_parser().parse_args(argv)
    settings = settings or Settings()
    engine = create_db_engine(settings.database_url)
    hasher = PasswordHasher(settings.password_hash_profile)
    try:
        with create_session_factory(engine)() as session:
            if arguments.command == "create-admin":
                # Antes de pedir a senha: um e-mail inválido já encerra aqui.
                email = validated_email(arguments.email)
                existing = session.scalar(select(User.id).where(User.email == email))
                password = "" if existing is not None else _read_admin_password()
                message = create_admin(
                    session,
                    hasher,
                    settings,
                    email=email,
                    full_name=arguments.name,
                    password=password,
                )
            elif arguments.command == "seed-demo":
                message = seed_demo(session, hasher, settings)
            else:
                message = purge_tokens(session, older_than_days=arguments.older_than_days)
    except (ValueError, RuntimeError) as error:
        print(f"Erro: {error}", file=sys.stderr)
        return 1
    finally:
        engine.dispose()

    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
