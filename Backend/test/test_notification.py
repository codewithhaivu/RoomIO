import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, create_autospec
from uuid import UUID, uuid4

from fastapi import FastAPI, HTTPException
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from db.base import Base
from models.account import Account
from models.notification import Notification
from repositories.notification_repository import NotificationRepository
from services.notification_service import NotificationService


class NotificationServiceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repository = create_autospec(NotificationRepository, instance=True)
        self.repository.db = AsyncMock(spec=AsyncSession)
        self.service = NotificationService(self.repository)
        self.account_id = uuid4()
        self.notification = Notification(
            id=uuid4(), id_account=self.account_id, content="Thông báo mới",
            is_read=False, created_at=datetime.now(timezone.utc)
        )
        self.repository.get_notifications.return_value = [self.notification]
        self.repository.get_notification_by_id.return_value = self.notification

    async def assert_http_error(self, status_code, operation):
        with self.assertRaises(HTTPException) as error:
            await operation
        self.assertEqual(error.exception.status_code, status_code)

    async def test_list_maps_schema_and_calculates_page_offset(self):
        result = await self.service.get_notifications(2, self.account_id)
        self.repository.get_notifications.assert_awaited_once_with(self.account_id, 10, 10)
        self.assertEqual(result.data[0].notification_id, self.notification.id)
        self.assertEqual(result.data[0].content, self.notification.content)
        self.assertEqual(result.data[0].created_at, self.notification.created_at)
        self.assertFalse(result.data[0].is_read)
        self.repository.mark_as_read.assert_not_awaited()
        self.repository.db.commit.assert_not_awaited()

    async def test_list_first_page_and_empty_page(self):
        self.repository.get_notifications.return_value = []
        result = await self.service.get_notifications(1, self.account_id)
        self.repository.get_notifications.assert_awaited_once_with(self.account_id, 0, 10)
        self.assertEqual(result.model_dump(), {"data": []})

    async def test_list_rejects_invalid_page_before_querying(self):
        for page in (0, -1):
            with self.subTest(page=page):
                await self.assert_http_error(400, self.service.get_notifications(page, self.account_id))
        self.repository.get_notifications.assert_not_awaited()

    async def test_read_scopes_lookup_to_current_account_and_commits(self):
        response = await self.service.read_notification(self.account_id, str(self.notification.id))
        self.repository.get_notification_by_id.assert_awaited_once_with(self.notification.id, self.account_id)
        self.repository.mark_as_read.assert_awaited_once_with(self.notification)
        self.repository.db.commit.assert_awaited_once()
        self.assertTrue(response.message)

    async def test_read_rejects_invalid_uuid_before_querying(self):
        await self.assert_http_error(400, self.service.read_notification(self.account_id, "invalid-id"))
        self.repository.get_notification_by_id.assert_not_awaited()

    async def test_read_missing_or_foreign_notification_preserves_404(self):
        self.repository.get_notification_by_id.return_value = None
        await self.assert_http_error(404, self.service.read_notification(self.account_id, str(uuid4())))
        self.repository.mark_as_read.assert_not_awaited()
        self.repository.db.commit.assert_not_awaited()
        self.repository.db.rollback.assert_awaited_once()

    async def test_read_flush_failure_rolls_back(self):
        self.repository.mark_as_read.side_effect = RuntimeError("flush failed")
        await self.assert_http_error(500, self.service.read_notification(self.account_id, str(self.notification.id)))
        self.repository.db.rollback.assert_awaited_once()
        self.repository.db.commit.assert_not_awaited()

    async def test_read_commit_failure_rolls_back(self):
        self.repository.db.commit.side_effect = RuntimeError("commit failed")
        await self.assert_http_error(500, self.service.read_notification(self.account_id, str(self.notification.id)))
        self.repository.db.rollback.assert_awaited_once()

    async def test_router_declares_list_and_message_responses(self):
        from app.api.v1.notification import router

        app = FastAPI()
        app.include_router(router)
        paths = app.openapi()["paths"]
        list_schema = paths["/notifications/"]["get"]["responses"]["200"]["content"]["application/json"]["schema"]
        read_schema = paths["/notifications/{notification_id}/read"]["patch"]["responses"]["200"]["content"]["application/json"]["schema"]
        self.assertTrue(list_schema["$ref"].endswith("/ListNotificationResponse"))
        self.assertTrue(read_schema["$ref"].endswith("/MessageResponse"))


class NotificationRepositoryTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        # Adapter async phục vụ test SQL trên SQLite, không dùng database thật.
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.session = Session(self.engine, expire_on_commit=False)
        self.db = AsyncMock(spec=AsyncSession)
        self.db.execute.side_effect = self.session.execute
        self.db.flush.side_effect = self.session.flush
        self.db.commit.side_effect = self.session.commit
        self.db.rollback.side_effect = self.session.rollback
        self.repository = NotificationRepository(self.db)
        self.service = NotificationService(self.repository)
        self.account_id = uuid4()
        self.other_account_id = uuid4()
        self.session.add_all([
            Account(id=self.account_id, phone_number="001", password="hash", role="CUSTOMER", state="ok"),
            Account(id=self.other_account_id, phone_number="002", password="hash", role="LANDLORD", state="ok")
        ])
        created_at = datetime(2030, 1, 1, tzinfo=timezone.utc)
        self.notifications = [
            Notification(
                id=UUID(int=index + 1), id_account=self.account_id, content=f"Notification {index}",
                is_read=False, created_at=created_at + timedelta(minutes=index)
            )
            for index in range(21)
        ]
        self.foreign_notification = Notification(
            id=uuid4(), id_account=self.other_account_id, content="Private notification",
            is_read=False, created_at=created_at + timedelta(days=1)
        )
        self.session.add_all(self.notifications + [self.foreign_notification])
        self.session.commit()

    def tearDown(self):
        self.session.close()
        self.engine.dispose()

    async def test_pagination_returns_only_owned_notifications_in_newest_order(self):
        pages = [await self.repository.get_notifications(self.account_id, offset, 10) for offset in (0, 10, 20, 30)]
        self.assertEqual([len(page) for page in pages], [10, 10, 1, 0])
        all_ids = [notification.id for page in pages for notification in page]
        self.assertEqual(all_ids, [notification.id for notification in reversed(self.notifications)])
        self.assertNotIn(self.foreign_notification.id, all_ids)
        self.assertTrue(all(not notification.is_read for page in pages for notification in page))

    async def test_equal_timestamps_have_stable_order_by_id(self):
        timestamp = datetime(2031, 1, 1, tzinfo=timezone.utc)
        for notification in self.notifications:
            notification.created_at = timestamp
        rows = await self.repository.get_notifications(self.account_id, 0, 30)
        self.assertEqual([row.id for row in rows], sorted([notification.id for notification in self.notifications], reverse=True))

    async def test_lookup_hides_foreign_and_missing_notifications(self):
        self.assertIsNone(await self.repository.get_notification_by_id(self.foreign_notification.id, self.account_id))
        self.assertIsNone(await self.repository.get_notification_by_id(uuid4(), self.account_id))
        result = await self.repository.get_notification_by_id(self.notifications[0].id, self.account_id)
        self.assertEqual(result.id, self.notifications[0].id)

    async def test_read_is_idempotent_and_does_not_change_other_notifications(self):
        notification_id = self.notifications[0].id
        for _ in range(2):
            response = await self.service.read_notification(self.account_id, str(notification_id))
            self.assertTrue(response.message)
        self.assertTrue(self.session.get(Notification, notification_id).is_read)
        self.assertFalse(self.session.get(Notification, self.notifications[1].id).is_read)
        self.assertFalse(self.session.get(Notification, self.foreign_notification.id).is_read)

    async def test_service_denies_reading_another_users_notification(self):
        with self.assertRaises(HTTPException) as error:
            await self.service.read_notification(self.account_id, str(self.foreign_notification.id))
        self.assertEqual(error.exception.status_code, 404)
        self.assertFalse(self.session.get(Notification, self.foreign_notification.id).is_read)

    async def test_failed_commit_rolls_back_read_flag(self):
        notification_id = self.notifications[0].id
        self.db.commit.side_effect = RuntimeError("commit failed")
        with self.assertRaises(HTTPException) as error:
            await self.service.read_notification(self.account_id, str(notification_id))
        self.assertEqual(error.exception.status_code, 500)
        self.assertFalse(self.session.get(Notification, notification_id).is_read)


if __name__ == "__main__":
    unittest.main()
