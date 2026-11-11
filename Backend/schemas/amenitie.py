from uuid import UUID

from schemas.base import BaseSchema


class AmenityResponse(BaseSchema):
    id:UUID
    name:str

class ListAmenityResponse(BaseSchema) :
    data:list[AmenityResponse]