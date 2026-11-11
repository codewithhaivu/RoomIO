from uuid import UUID

from fastapi import HTTPException

from repositories.notification_repository import NotificationRepository
from schemas.account import MessageResponse
from schemas.notification import ListNotificationResponse, NotificationResponse


class NotificationService:

    def __init__(self, repository: NotificationRepository):
        self.repository = repository

    async def get_notifications(self, page: int, id_account: str) -> ListNotificationResponse:
        if page < 1:
            raise HTTPException(status_code=400, detail="Số trang phải lớn hơn hoặc bằng 1")

        page_size = 10
        notifications = await self.repository.get_notifications(
            id_account, (page - 1) * page_size, page_size
        )

        return ListNotificationResponse(
            data=[
                NotificationResponse(
                    notification_id=notification.id,
                    content=notification.content,
                    is_read=notification.is_read,
                    created_at=notification.created_at
                )
                for notification in notifications
            ]
        )

    async def read_notification(self, id_account: str, notification_id: str) -> MessageResponse:
        try:
            notification_id = UUID(str(notification_id))
        except (ValueError, TypeError, AttributeError):
            raise HTTPException(status_code=400, detail="ID thông báo không hợp lệ")

        try:
            notification = await self.repository.get_notification_by_id(notification_id, id_account)
            if notification is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy thông báo")

            await self.repository.mark_as_read(notification)
            await self.repository.db.commit()
            return MessageResponse(message="Đánh dấu thông báo đã đọc thành công")
        except HTTPException:
            await self.repository.db.rollback()
            raise
        except Exception:
            await self.repository.db.rollback()
            raise HTTPException(status_code=500, detail="Failed to read notification")
