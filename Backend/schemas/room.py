from uuid import UUID
from schemas.base import BaseSchema


class Location(BaseSchema) :
    name :str
    longitude :float
    latitude :float
class LandlordResponse(BaseSchema):
    id_account : UUID
    full_name :str
    gender :str
    avatar : str | None
    is_verify : bool
class InteriorResponse(BaseSchema) :
    id:UUID
    name :str
class AmenityResponse(BaseSchema) :
    id:UUID
    name :str
class Image(BaseSchema) :
    image_url :str
    public_id :str
    is_thumbnail :bool

class ListImageResponse(BaseSchema) :
    response : list[Image]
class RoomResponse(BaseSchema) :
    id :UUID
    name:str
    area : float
    water_fee : float
    service_fee : float
    parking_fee :float
    rental_price : float
    electricity_fee: float
    status :str
    room_type :str
    location : Location
    interiors : list[InteriorResponse]
    amenities : list[AmenityResponse]
    image : ListImageResponse

class ListRoomResponse(BaseSchema) :
    rooms : list[RoomResponse] | None

class RoomDetailResponse(BaseSchema) :
    room : RoomResponse
    landlord : LandlordResponse
class RoomRequest(BaseSchema) :
    name:str
    area :float
    water_fee : float
    service_fee : float
    parking_fee :float
    rental_price : float
    electricity_fee: float
    status :str
    room_type :str
    location : Location
    interiors : list[UUID]
    amenities : list[UUID]
    images : list[Image]

class RoomByPosition(BaseSchema) :
    id: UUID
    name: str
    area: float
    rental_price: float
    status: str
    distance : float
    room_type: str
    location_name:str
    image_url: str
    is_saved :bool

class ListRoomByPosition(BaseSchema) :
    rooms : list[RoomByPosition]

class ListRoomByDistrict(BaseSchema) :
    rooms : list[RoomByPosition]
    district :str

class RoomRequestUpdate(BaseSchema) :
    name:str | None = None
    area :float | None = None
    water_fee : float | None = None
    service_fee : float | None = None
    parking_fee :float | None = None
    rental_price : float | None = None
    electricity_fee: float | None = None
    status :str | None = None
    room_type :str | None = None
    location : Location | None = None
    interiors : list[UUID] | None = None
    amenities : list[UUID] | None = None
    images : list[Image] | None = None

class LocationResponse(BaseSchema) :
    name_district : str
    location_id : UUID

class ListLocationResponse(BaseSchema) :
    data : list[LocationResponse]
