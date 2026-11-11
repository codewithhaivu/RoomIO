from datetime import datetime
from uuid import UUID

from schemas.base import BaseSchema


class RentalResponse(BaseSchema):
    qr_token : str
    expires_in_second : int

class RentalVerifyResponse(BaseSchema) :
    message : str
    id_valid : bool

class RentalVerifyRequest(BaseSchema) :
    token :str


class TenantRentalResponse(BaseSchema) :
    rental_id : UUID
    tenant_id: UUID
    full_name: str
    avatar_url: str
    phone_number:str
    room_id: UUID
    room_name: str
    start_date: datetime
    status: str

class CurrentTenantsResponse(BaseSchema) :
    data : list[TenantRentalResponse]

class RentalRoomResponse(BaseSchema):
    # 1. Thông tin về phiên thuê (Rental Info)
    rental_id: UUID
    start_date: datetime
    status: str

    # 2. Thông tin cơ bản của phòng trọ (Room Info)
    room_id: UUID
    room_name: str
    room_thumbnail: str
    address: str
    price: float
class MyRentedRoomsResponse(BaseSchema) :
    data : list[RentalRoomResponse]