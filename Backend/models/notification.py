from datetime import datetime, timezone

from db.base import Base
import uuid
from sqlalchemy import ForeignKey, String, Boolean, DateTime
from sqlalchemy.orm import Mapped, mapped_column


class Notification(Base) :
    __tablename__ = "notifications"
    id :Mapped[uuid.UUID] = mapped_column(
        primary_key=True ,
        default=uuid.uuid4,
    )
    id_account: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("accounts.id"),
        nullable=False,
        index=True,
    )

    content: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
    )

    is_read: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )
    created_at : Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )