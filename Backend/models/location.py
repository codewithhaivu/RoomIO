import uuid

from sqlalchemy import String, Float
from sqlalchemy.orm import Mapped, mapped_column

from db.base import Base

class Location( Base) :
    __tablename__ = "locations"
    id : Mapped[uuid.UUID] = mapped_column(
        primary_key=True ,
        default=uuid.uuid4
    )
    name : Mapped[str] = mapped_column(
        String(255)
    )
    longitude : Mapped[float] =mapped_column(
        Float
    )
    latitude : Mapped[float] =mapped_column(
        Float
    )
    type : Mapped[str] =mapped_column(
        String(255) ,
        nullable=False
    )