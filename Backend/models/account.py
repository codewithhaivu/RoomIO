import uuid
from sqlalchemy import  String
from sqlalchemy.orm import Mapped, mapped_column
from db.base import Base

class Account(Base) :
    __tablename__ = "accounts"
    id:Mapped[uuid.UUID]= mapped_column(
        primary_key =True,
        default = uuid.uuid4,
    )
    password: Mapped[str] = mapped_column(
        String(255) ,
        nullable = False
    )
    phone_number :Mapped[str] = mapped_column(
        String(255) ,
        nullable= False ,
        unique= True
    )
    role : Mapped[str] = mapped_column(
        String(20) ,
        nullable =False
    )
    state :Mapped[str] = mapped_column(
        String(20) ,
        default= "ok" ,
    )
