from schemas.base import BaseSchema


class RegisterDeviceRequest(BaseSchema) :
    fcm_token : str
    platform :str

class RegisterDeviceResponse(BaseSchema) :
    id_device : str

class UpdateDeviceRequest(BaseSchema) :
    fcm_token : str
