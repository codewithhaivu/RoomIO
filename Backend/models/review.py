from datetime import datetime, timezone

from db.base import Base
import uuid
from sqlalchemy import ForeignKey, String, Float, DateTime
from sqlalchemy.orm import Mapped, mapped_column


class Review(Base) :
    __tablename__ = "reviews"
    id :Mapped[uuid.UUID] = mapped_column(
        primary_key=True ,
        default=uuid.uuid4,
        index = True
    )
    id_tenant: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id"),
        nullable=False,
        index=True,
    )

    id_rooms: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("rooms.id"),
        nullable=False,
        index=True,
    )

    content: Mapped[str] = mapped_column(
        String(255)
    )
    rating :Mapped[float] = mapped_column(
        Float,
        default=1
    )
    created_at : Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    status :Mapped[str] = mapped_column(
        String(50) ,
        default='active' # inactive
    )