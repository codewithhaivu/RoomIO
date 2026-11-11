import uuid

from sqlalchemy import String, Float, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from db.base import Base


class Room(Base):
    __tablename__ = "rooms"

    id : Mapped[uuid.UUID] = mapped_column(
        primary_key=True ,
        default=uuid.uuid4
    )
    name : Mapped[str] =mapped_column(
        String(255) ,
        nullable=False
    )
    area : Mapped[float] = mapped_column(
        Float ,
        nullable=False
    )
    water_fee : Mapped[float] = mapped_column(
        Float ,
        nullable= False
    )
    service_fee : Mapped[float] = mapped_column(
        Float ,
        nullable= False
    )
    parking_fee : Mapped[float] = mapped_column(
        Float ,
        nullable= False
    )
    rental_price : Mapped[float] = mapped_column(
        Float ,
        nullable= False
    )
    electricity_fee:Mapped[float] = mapped_column(
        Float ,
        nullable=False
    )
    status :Mapped[str] = mapped_column(
        String(255) ,
        nullable=False
    )
    room_type :Mapped[str] = mapped_column(
        String(255) ,
        nullable=False
    )
    location_id :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("locations.id"),
        nullable=False ,
        index=True
    )
    landlord_id :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("landlords.id"),
        nullable=False ,
        index=True
    )