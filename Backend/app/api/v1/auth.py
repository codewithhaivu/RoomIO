from fastapi import APIRouter, Depends

from app.api.deps import get_account_service
from schemas.account import (
    CheckPhoneResponse, CheckPhoneRequest
, LoginResponse, LoginRequest, SendOTPResponse, SendOTPRequest, VerifyOTPResponse, VerifyOTPRequest, MessageResponse,
    RegisterRequest, ResetPasswordRequest, RefreshResponse, RefreshRequest
)

router = APIRouter(
    prefix="/auth",
    tags=["Auth"]
)

@router.post('/check-phone',response_model=CheckPhoneResponse)
async def check_phone(request :CheckPhoneRequest ,service =Depends(get_account_service)):
    return await service.check_phone(request)

@router.post('/login',response_model=LoginResponse)
async def login(request:LoginRequest, service =Depends(get_account_service)):
    return await service.login(request)

@router.post('/register/send-otp',response_model=SendOTPResponse)
async def send_otp(request: SendOTPRequest,service =Depends(get_account_service)):
    return await service.send_otp(request)

@router.post('/register/verify-otp',response_model=VerifyOTPResponse)
async def verify_otp(request: VerifyOTPRequest,service =Depends(get_account_service)):
    return await service.verify_otp(request)

@router.post('/register',response_model=MessageResponse)
async def register(request : RegisterRequest ,service = Depends(get_account_service)) :
    return await service.register(request)

@router.post('/forgot-password/send-otp',response_model=SendOTPResponse)
async def send_otp(request: SendOTPRequest,service =Depends(get_account_service)):
    return await service.send_otp(request)

@router.post('/forgot-password/verify-otp',response_model=VerifyOTPResponse)
async def verify_otp(request: VerifyOTPRequest,service =Depends(get_account_service)):
    return await service.verify_otp(request)
@router.patch('/forgot-password/reset',response_model=MessageResponse)
async def reset_password(request : ResetPasswordRequest,service =Depends(get_account_service)):
    return await service.reset_password(request)

@router.post('/refresh-token',response_model = RefreshResponse)
async def refresh_token(request : RefreshRequest,service = Depends(get_account_service)) :
    return await service.refresh_token(request)

@router.post('/logout',response_model=MessageResponse)
async def logout(request:RefreshRequest , service =Depends(get_account_service)):
    return await service.logout(request)
