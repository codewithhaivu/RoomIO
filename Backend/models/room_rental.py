import uuid
from datetime import datetime, timezone

from sqlalchemy import String, ForeignKey, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from db.base import Base

class RoomRental(Base) :
    __tablename__ = "room_rentals"
    id:Mapped[uuid.UUID]= mapped_column(
        primary_key =True,
        default = uuid.uuid4,
    )
    id_tenant :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id"),
        nullable=False ,
        index=True
    )
    id_room :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("rooms.id"),
        nullable=False ,
        index=True
    )
    status :Mapped[str] = mapped_column(
        String(255) ,
        default= "active" # inactive
    )
    rent_at :Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )