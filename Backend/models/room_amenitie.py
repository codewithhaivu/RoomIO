import uuid

from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from db.base import Base


class RoomAmenity(Base) :
    __tablename__ = "room_amenities"
    id_room :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("rooms.id"),
        nullable=False,
        primary_key=True
    )
    id_amenity :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("amenities.id") ,
        nullable=False ,
        primary_key=True
    )