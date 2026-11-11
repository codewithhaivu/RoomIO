import uuid

from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from db.base import Base


class RoomInterior(Base) :
    __tablename__ = "room_interiors"
    id_room :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("rooms.id"),
        nullable=False,
        primary_key=True
    )
    id_interior :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("interiors.id") ,
        nullable=False ,
        primary_key=True
    )