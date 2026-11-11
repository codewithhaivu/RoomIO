import uuid
from datetime import datetime, timezone

from sqlalchemy import String, ForeignKey, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from db.base import Base
class UserDevice(Base) :
    __tablename__ = "user_devices"
    id : Mapped[uuid.UUID] = mapped_column(
        primary_key=True ,
        default=uuid.uuid4
    )
    fcm_token :Mapped[str] = mapped_column(
        String(512) ,
        nullable=False
    )
    platform :Mapped[str] = mapped_column(
        String(20) ,
        nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    account_id :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("accounts.id"),
        nullable=False ,
        index=True
    )
