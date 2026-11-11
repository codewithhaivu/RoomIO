import secrets

from fastapi import HTTPException
from jwt import ExpiredSignatureError, InvalidTokenError
from core.redis_custom import redis_client
from core.security import verify_password, create_token, decode_token
from core.sms_custom import sms_service
from schemas.account import (
    CheckPhoneRequest, CheckPhoneResponse, LoginRequest, LoginResponse,
    SendOTPRequest, VerifyOTPRequest, VerifyOTPResponse, RegisterRequest,
    MessageResponse, SendOTPResponse, ResetPasswordRequest, RefreshRequest, RefreshResponse)
from repositories.account_repository import AccountRepository


class AccountService:

    def __init__(self, repository: AccountRepository):
        self.repository = repository

    async def check_phone(
            self,
            request: CheckPhoneRequest
    ) -> CheckPhoneResponse:

        account = await self.repository.get_by_phone(
            request.phone_number
        )
        return CheckPhoneResponse(
            exist=account is not None
        )

    async def login(self, request: LoginRequest) -> LoginResponse:
        account = await self.repository.get_by_phone(
            request.phone_number
        )
        if account is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid phone number or password"
            )
        if account.state =='not ok' :
            raise HTTPException(
                status_code=403,
                detail="Account is locked. Please contact hotline 0988643798 for more details."
            )
        if not verify_password(request.password, account.password):
            raise HTTPException(
                status_code=401,
                detail="Invalid phone number or password"
            )

        access_token = create_token(account.id, "access_token")
        refresh_token = await self.repository.create_refresh_token(account.id)
        return LoginResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            role=account.role
        )

    async def send_otp(self, request: SendOTPRequest) -> SendOTPResponse:
        otp = str(secrets.randbelow(10000)).zfill(4)
        await sms_service.send_otp(request.phone_number,otp)
        print(otp)
        await redis_client.set(request.phone_number, otp, 120)
        return SendOTPResponse(
            message ="send succeess"
        )

    async def verify_otp(self, request: VerifyOTPRequest) -> VerifyOTPResponse:
        otp = await redis_client.get(request.phone_number)
        if request.OTP == otp:
            return VerifyOTPResponse(
                is_verified=True
            )
        return VerifyOTPResponse(
            is_verified=False
        )

    async def register(self, request: RegisterRequest) -> MessageResponse:
        new_account = await self.repository.create_account(request.phone_number, request.password, request.role)
        if new_account is None:
            return MessageResponse(
                message="Register Fail"
            )

        return MessageResponse(
            message="Register Success"
        )

    async def reset_password(self, request: ResetPasswordRequest) -> MessageResponse:
        account = await self.repository.update_account(request.phone_number, request.password)
        if account is None:
            return MessageResponse(
                message="Reset Fail"
            )
        await self.repository.revoke_all_refresh_tokens(account.id)
        return MessageResponse(
            message="Reset Success"
        )

    async def refresh_token(
            self,
            request: RefreshRequest
    ) -> RefreshResponse:

        try:
            # 1. Decode và kiểm tra JWT
            payload = decode_token(request.refresh_token)

            # 2. Đây phải là refresh token
            if payload.get("type") != "refresh_token":
                raise HTTPException(
                    status_code=401,
                    detail="Refresh token required"
                )

            # 3. Lấy account_id
            account_id = payload.get("sub")

            if account_id is None:
                raise HTTPException(
                    status_code=401,
                    detail="Invalid refresh token"
                )
            account = await self.repository.get_account_by_id(account_id)
            if account.state == 'not ok':
                raise HTTPException(
                    status_code=403,
                    detail="Account is locked. Please contact hotline 0988643798 for more details."
                )

            # 4. Kiểm tra refresh token trong DB
            result = await self.repository.get_rf_token_by_token(
                request.refresh_token
            )

            if result is None:
                raise HTTPException(
                    status_code=401,
                    detail="Refresh token not found"
                )

            # 5. Kiểm tra token đã bị revoke chưa
            if result.is_revoked:
                raise HTTPException(
                    status_code=401,
                    detail="Refresh token has been revoked"
                )

            # 6. Tạo access token mới
            new_access_token = create_token(
                account_id,
                "access_token"
            )

            return RefreshResponse(
                access_token=new_access_token
            )

        except ExpiredSignatureError:
            raise HTTPException(
                status_code=401,
                detail="Refresh token expired"
            )

        except InvalidTokenError:
            raise HTTPException(
                status_code=401,
                detail="Invalid refresh token"
            )

    async def logout(self, request: RefreshRequest) -> MessageResponse:
        await self.repository.revoked_refresh_token(request.refresh_token)
        return MessageResponse(
            message="Logout Success"
        )
