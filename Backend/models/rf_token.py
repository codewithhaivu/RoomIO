
from db.base import Base
import uuid
from sqlalchemy import  ForeignKey, Text, Boolean
from sqlalchemy.orm import Mapped, mapped_column


class RefreshToken(Base) :
    __tablename__ = "refresh_tokens"
    id :Mapped[uuid.UUID] = mapped_column(
        primary_key=True ,
        default=uuid.uuid4,
    )
    token:Mapped[str] = mapped_column(
        Text ,
        nullable=False,
    )
    is_revoked :Mapped[bool] = mapped_column(
        Boolean ,
        default=False
    )
    account_id:Mapped[uuid.UUID] = mapped_column(
        ForeignKey("accounts.id"),
        nullable=False ,
        index=True ,
    )
