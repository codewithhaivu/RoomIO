from schemas.base import BaseSchema


class CreateProfileRequest(BaseSchema):
    fullName :str
    gender : str
    avatar : str
    description :str

class ProfileResponse(BaseSchema) :
    fullName :str
    gender : str
    avatar : str
    description :str
    is_verify:bool
    message :str

class UpdateProfileRequest(BaseSchema):
    fullName: str | None = None
    gender: str | None = None
    avatar: str | None = None
    description: str | None = None


class ImageResponse(BaseSchema) :
    image_url :str
    public_id :str