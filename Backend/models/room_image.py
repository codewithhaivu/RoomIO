import uuid

from sqlalchemy import String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from db.base import Base


class RoomImage(Base):
    __tablename__ = "room_images"

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True,
        default=uuid.uuid4
    )

    image_url: Mapped[str] = mapped_column(
        String(500),
        nullable=False
    )
    public_id : Mapped[str] = mapped_column(
        String(50) ,
        nullable=False,
        index=True
    )

    room_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("rooms.id"),
        nullable=False,
        index=True
    )
    is_thumbnail : Mapped[bool] =mapped_column(
        default= False
    )
