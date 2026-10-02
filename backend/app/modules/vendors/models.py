import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base, UTCDateTime, str_enum, utcnow


class PersonType(StrEnum):
    INDIVIDUAL = "pf"
    COMPANY = "pj"


class VendorStatus(StrEnum):
    PENDING_REVIEW = "pending_review"
    APPROVED = "approved"
    REJECTED = "rejected"


class VendorProfile(Base):
    """Cadastro de fornecedor de um usuário. Passa por análise antes de valer."""

    __tablename__ = "vendor_profiles"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True
    )
    person_type: Mapped[PersonType] = mapped_column(str_enum(PersonType, name="person_type"))
    # CPF (11) ou CNPJ (14), sem pontuação. Dado pessoal: nunca sai inteiro
    # pela API pública, só mascarado.
    document: Mapped[str] = mapped_column(String(14), unique=True)
    legal_name: Mapped[str] = mapped_column(String(160))
    status: Mapped[VendorStatus] = mapped_column(
        str_enum(VendorStatus, name="vendor_status"), default=VendorStatus.PENDING_REVIEW
    )
    rejection_reason: Mapped[str | None] = mapped_column(String(500))
    reviewed_at: Mapped[datetime | None] = mapped_column(UTCDateTime)
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow, onupdate=utcnow)
