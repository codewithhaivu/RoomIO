import uuid
from datetime import datetime, timezone

from sqlalchemy import String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from db.base import Base

class Message( Base) :
    __tablename__ = "messages"
    id : Mapped[uuid.UUID] = mapped_column(
        primary_key=True ,
        default=uuid.uuid4 ,
        index =True
    )
    conversation_id :Mapped[uuid.UUID] = mapped_column(
        ForeignKey("conversations.id") ,
        nullable=False,
        index =True
    )
    sender_id :Mapped[uuid.UUID] = mapped_column(
        default=uuid.uuid4 ,
        index =True
    )
    content :Mapped[str] = mapped_column(
        String(500)
    )
    status :Mapped[str] = mapped_column(
        String(50),
        default="active" # deactivate
    )
    created_at : Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )