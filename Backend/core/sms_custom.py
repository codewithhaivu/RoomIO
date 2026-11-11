import httpx
from fastapi import HTTPException

from core.config import settings


class SMSServiceCustom:
    def __init__(self):
        self.access_token = settings.SMS_ACCESS_TOKEN
        self.BASE_URL =  settings.SMS_BASE_URL

    async def send_otp(self, phone: str, otp: str):
        url = f"{self.BASE_URL}/sms/send"

        params = {
            "access-token": self.access_token,
            "to": phone,
            "content": f"Mã OTP là: {otp}, thời gian hiệu lực trong vòng 2 phút",
            "type": 4,
            "sender":""
        }

        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(
                url,
                params=params
            )

            response.raise_for_status()
            result = response.json()
            print(result)
            if result.get("status") != "success":
                raise HTTPException(
                    status_code=502,
                    detail="Lỗi dịch vụ khi gửi tin nhắn qua dịch vụ"
                )

            return result

sms_service = SMSServiceCustom()