from uuid import UUID

from schemas.base import BaseSchema


class User(BaseSchema) :
    id_account : UUID
    phone_number : str
    password : str
    full_name : str
    role : str
    state: str
    is_verify :str | None = None

class ListUser(BaseSchema) :
    data : list[User]


class LandlordVerifyRequest(BaseSchema) :
    id_account : UUID

class LandlordVerifyResponse(BaseSchema) :
    id_account : UUID
    state : str


class UserRequest(BaseSchema) :
    id_user :UUID

class ListRoomRequest(BaseSchema) :
    data : list[UUID]

