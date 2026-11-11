from uuid import UUID

from schemas.base import BaseSchema

class RoomResponse(BaseSchema) :
    id :UUID
    name:str
    area : float
    rental_price : float
    status :str
    room_type :str
    location_name : str
    image_url : str

class ListSavedRoomResponse(BaseSchema) :
    rooms : list[RoomResponse] | None
