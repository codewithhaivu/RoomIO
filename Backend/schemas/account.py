from schemas.base import BaseSchema


class CheckPhoneResponse(BaseSchema):
    exist :bool

class  CheckPhoneRequest(BaseSchema):
    phone_number :str

class LoginResponse(BaseSchema) :
    access_token :str
    refresh_token :str
    role : str

class LoginRequest(BaseSchema) :
    phone_number :str
    password :str

class SendOTPRequest(BaseSchema) :
    phone_number :str

class SendOTPResponse(BaseSchema) :
    message :str

class VerifyOTPResponse(BaseSchema) :
    is_verified :bool
class VerifyOTPRequest(BaseSchema) :
    phone_number :str
    OTP :str
class MessageResponse(BaseSchema) :
    message :str

class RegisterRequest(BaseSchema) :
    phone_number :str
    password :str
    role :str

class ResetPasswordRequest(BaseSchema) :
    phone_number :str
    password :str

class RefreshResponse(BaseSchema) :
    access_token :str

class RefreshRequest(BaseSchema) :
    refresh_token :str

