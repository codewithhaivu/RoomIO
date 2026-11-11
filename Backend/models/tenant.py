import uuid
from sqlalchemy import String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from db.base import Base
class Tenant(Base) :
    __tablename__ = "tenants"
    id : Mapped[uuid.UUID] = mapped_column(
        primary_key=True ,
        default=uuid.uuid4
    )
    full_name :Mapped[str] = mapped_column(
        String(255) ,
        nullable=False
    )
    gender :Mapped[str] = mapped_column(
        String(20) ,
        nullable=False
    )
    avatar : Mapped[str] = mapped_column(
        String(500) ,
    )
    description :Mapped[str] =mapped_column(
        String(500) ,
    )
    account_id :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("accounts.id"),
        nullable=False ,
        index=True
    )
