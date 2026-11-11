from uuid import UUID

from schemas.base import BaseSchema


class InteriorResponse(BaseSchema):
    id:UUID
    name:str

class ListInteriorResponse(BaseSchema) :
    data :list[InteriorResponse]