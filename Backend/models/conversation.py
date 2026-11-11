import uuid
from datetime import datetime, timezone

from sqlalchemy import String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from db.base import Base

class Conversation( Base) :
    __tablename__ = "conversations"
    id : Mapped[uuid.UUID] = mapped_column(
        primary_key=True ,
        default=uuid.uuid4 ,
        index =True
    )
    user1_id :Mapped[uuid.UUID] = mapped_column(
        default=uuid.uuid4 ,
        index =True
    )
    user2_id :Mapped[uuid.UUID] = mapped_column(
        default=uuid.uuid4 ,
        index =True
    )
    last_message :Mapped[str] = mapped_column(
        String(500)
    )
    updated_at : Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )