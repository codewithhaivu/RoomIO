import asyncio
import logging
from firebase_admin import messaging
from firebase_admin.exceptions import FirebaseError
from repositories.device_repository import DeviceRepository
logger = logging.getLogger(__name__)


class PushNotificationService:
    def __init__(self, repository: DeviceRepository):
        self.repository = repository

    async def send_notification(
        self,
        id_account,
        title: str,
        body: str,
        data: dict[str, str] | None = None
    ) -> int:

        # 1. Lấy danh sách thiết bị của tài khoản
        devices = await self.repository.get_devices_by_account(
            id_account
        )

        success_count = 0

        # 2. Gửi Push đến từng thiết bị
        for device in devices:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body
                ),
                data=data or {},
                token=device.fcm_token
            )

            try:
                # Firebase Admin SDK send() là hàm đồng bộ
                # Chạy trong thread để không chặn event loop
                await asyncio.to_thread(
                    messaging.send,
                    message
                )

                success_count += 1

            except messaging.UnregisteredError:
                # Token đã bị Firebase xác nhận không còn hợp lệ
                logger.info(
                    "Removing invalid FCM token for device %s",
                    device.id
                )

                await self.repository.delete_device(
                    device.id,
                    id_account
                )

            except FirebaseError:
                logger.exception(
                    "Failed to send push to device %s",
                    device.id
                )

        return success_count