import uuid
from datetime import datetime, timezone

from sqlalchemy import ForeignKey, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from db.base import Base


class RoomSaved(Base) :
    __tablename__ = "room_saves"
    id_room :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("rooms.id"),
        nullable=False,
        primary_key=True
    )
    id_tenant :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id") ,
        nullable=False ,
        primary_key=True
    )
    saved_at : Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    status : Mapped[str] = mapped_column(
        String(50) ,
        default='active' # inactive
    )