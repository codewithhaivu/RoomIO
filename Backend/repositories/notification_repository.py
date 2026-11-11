from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.notification import Notification


class NotificationRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_notifications(self, id_account, offset, limit):
        result = await self.db.execute(
            select(Notification)
            .where(Notification.id_account == id_account)
            .order_by(Notification.created_at.desc(), Notification.id.desc())
            .offset(offset)
            .limit(limit)
        )

        return result.scalars().all()

    async def get_notification_by_id(self, notification_id, id_account):
        result = await self.db.execute(
            select(Notification)
            .where(
                Notification.id == notification_id,
                Notification.id_account == id_account
            )
            .with_for_update()
        )

        return result.scalar_one_or_none()

    async def mark_as_read(self, notification):
        notification.is_read = True
        await self.db.flush()
        return notification
