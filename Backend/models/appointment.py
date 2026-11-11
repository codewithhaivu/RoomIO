from datetime import datetime

from db.base import Base
import uuid
from sqlalchemy import ForeignKey, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column


class Appointment(Base) :
    __tablename__ = "appointments"
    id :Mapped[uuid.UUID] = mapped_column(
        primary_key=True ,
        default=uuid.uuid4,
    )
    id_room:Mapped[uuid.UUID] = mapped_column(
        ForeignKey("rooms.id"),
        nullable=False ,
        index=True ,
    )
    id_tenant:Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id"),
        nullable=False ,
        index=True ,
    )
    meet_at : Mapped[datetime] = mapped_column(
        DateTime ,
        nullable=False ,
    )
    status : Mapped[str] = mapped_column(
        String(255) ,
        default='PENDING' #CONFIRMED, REJECTED, CANCELLED, COMPLETED.
    )

