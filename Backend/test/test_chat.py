import unittest
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, create_autospec
from uuid import UUID, uuid4

from fastapi import HTTPException
from sqlalchemy import create_engine, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.websocket.user import websocket_user
from db.base import Base
from models.account import Account
from models.conversation import Conversation
from models.landlord import LandLord
from models.message import Message
from models.tenant import Tenant
from repositories.chat_repository import ChatRepository
from schemas.chat import ChatMessageRequest
from services.chat_service import ChatService
from services.push_notification_service import PushNotificationService


class ChatServiceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repository = create_autospec(ChatRepository, instance=True)
        self.repository.db = AsyncMock(spec=AsyncSession)
        self.push_service = create_autospec(PushNotificationService, instance=True)
        self.service = ChatService(self.repository, self.push_service)
        self.sender_id = UUID(int=2)
        self.receiver_id = UUID(int=1)
        self.conversation = Conversation(
            id=uuid4(), user1_id=self.receiver_id, user2_id=self.sender_id,
            last_message="Previous", updated_at=datetime.now(timezone.utc)
        )
        self.message = Message(
            id=uuid4(), conversation_id=self.conversation.id, sender_id=self.sender_id,
            content="Hello", status="active", created_at=datetime(2030, 1, 1, tzinfo=timezone.utc)
        )
        self.request = ChatMessageRequest(
            receiver_id=self.receiver_id, content="Hello", status="active",
            created_at="2030-01-01T07:00:00+07:00", type="chat_message"
        )
        self.repository.get_account_by_id.side_effect = lambda account_id, **kwargs: Account(id=account_id)
        self.repository.get_conversation.return_value = self.conversation
        self.repository.create_conversation.return_value = self.conversation
        self.repository.create_message.return_value = self.message
        self.saved_connections = dict(websocket_user.connections)
        websocket_user.connections.clear()

    def tearDown(self):
        websocket_user.connections.clear()
        websocket_user.connections.update(self.saved_connections)

    async def assert_http_error(self, status_code, operation):
        with self.assertRaises(HTTPException) as error:
            await operation
        self.assertEqual(error.exception.status_code, status_code)
        self.push_service.send_notification.assert_not_awaited()

    async def send(self):
        return await self.service.send_message(self.sender_id, self.request)

    async def test_conversations_map_existing_schema(self):
        self.repository.get_conversations.return_value = [SimpleNamespace(
            target_user_id=self.receiver_id, target_user_name="Owner", target_avatar_url="avatar.jpg",
            last_message="Hello", updated_at=self.conversation.updated_at
        )]
        response = await self.service.get_conversations(self.sender_id)
        self.assertEqual(response.data[0].target_user_id, self.receiver_id)
        self.assertEqual(response.data[0].target_user_name, "Owner")
        self.repository.get_conversations.return_value = []
        self.assertEqual((await self.service.get_conversations(self.sender_id)).data, [])

    async def test_missing_conversation_returns_empty_history(self):
        self.repository.get_conversation.return_value = None
        result = await self.service.get_message(self.sender_id, self.receiver_id)
        self.assertEqual(result.data, [])
        self.repository.get_messages.assert_not_awaited()

    async def test_history_derives_receiver_for_both_senders(self):
        reply = Message(
            id=uuid4(), sender_id=self.receiver_id, content="Reply", status="active",
            created_at=datetime(2030, 1, 1, 1)
        )
        self.repository.get_messages.return_value = [self.message, reply]
        response = await self.service.get_message(self.sender_id, self.receiver_id)
        self.assertEqual(response.data[0].receiver_id, self.receiver_id)
        self.assertEqual(response.data[1].receiver_id, self.sender_id)
        self.assertEqual(response.data[0].created_at, "2030-01-01T00:00:00+00:00")
        self.assertEqual(response.data[1].created_at, "2030-01-01T01:00:00+00:00")

    async def test_first_message_creates_conversation_and_updates_preview(self):
        self.repository.get_conversation.return_value = None
        result = await self.send()
        self.assertTrue(result.id_valid)
        args = self.repository.create_conversation.await_args.args
        self.assertEqual(args[:3], (self.receiver_id, self.sender_id, "Hello"))
        self.assertEqual(self.repository.update_conversation.await_args.args[:2], (self.conversation, "Hello"))
        self.repository.db.commit.assert_awaited_once()

    async def test_existing_conversation_is_reused_and_accounts_lock_in_order(self):
        await self.send()
        self.repository.create_conversation.assert_not_awaited()
        self.assertEqual([call.args[0] for call in self.repository.get_account_by_id.await_args_list], sorted((self.sender_id, self.receiver_id)))
        self.repository.get_conversation.assert_awaited_once_with(self.sender_id, self.receiver_id, for_update=True)

    async def test_online_delivery_happens_after_commit_and_is_json_serializable(self):
        async def assert_committed(event):
            self.repository.db.commit.assert_awaited_once()
            self.assertEqual(event["type"], self.request.type)
            self.assertEqual(event["data"]["message_id"], str(self.message.id))
            self.assertEqual(event["data"]["sender_id"], str(self.sender_id))
            self.assertEqual(event["data"]["receiver_id"], str(self.receiver_id))
            self.assertIsInstance(event["data"]["created_at"], str)

        socket = SimpleNamespace(send_json=AsyncMock(side_effect=assert_committed))
        websocket_user.connections[self.receiver_id] = socket
        await self.send()
        socket.send_json.assert_awaited_once()

    async def test_offline_receiver_still_gets_persisted_message(self):
        result = await self.send()
        self.assertTrue(result.id_valid)
        self.repository.create_message.assert_awaited_once()
        self.repository.db.commit.assert_awaited_once()

    async def test_push_targets_receiver_after_commit_online_or_offline(self):
        commits_at_push = []

        async def record_commit(**kwargs):
            commits_at_push.append(self.repository.db.commit.await_count)

        self.push_service.send_notification.side_effect = record_commit
        for online in (False, True):
            with self.subTest(online=online):
                self.repository.db.commit.reset_mock()
                self.push_service.send_notification.reset_mock()
                if online:
                    websocket_user.connections[self.receiver_id] = SimpleNamespace(send_json=AsyncMock())
                result = await self.send()
                self.assertTrue(result.id_valid)
                self.push_service.send_notification.assert_awaited_once_with(
                    id_account=str(self.receiver_id),
                    title="Tin nhắn mới",
                    body="Bạn có một tin nhắn mới trên RoomIO",
                    data={"type": "chat", "sender_id": str(self.sender_id)}
                )
        self.assertEqual(commits_at_push, [1, 1])

    async def test_push_failure_does_not_fail_message_or_realtime(self):
        self.push_service.send_notification.side_effect = RuntimeError("Firebase unavailable")
        socket = SimpleNamespace(send_json=AsyncMock())
        websocket_user.connections[self.receiver_id] = socket
        with self.assertLogs("services.chat_service", level="ERROR"):
            result = await self.send()
        self.assertTrue(result.id_valid)
        socket.send_json.assert_awaited_once()
        self.repository.db.commit.assert_awaited_once()
        self.repository.db.rollback.assert_not_awaited()

    async def test_socket_failure_does_not_fail_committed_message(self):
        socket = SimpleNamespace(send_json=AsyncMock(side_effect=RuntimeError("closed")))
        websocket_user.connections[self.receiver_id] = socket
        with self.assertLogs("services.chat_service", level="WARNING"):
            result = await self.send()
        self.assertTrue(result.id_valid)
        self.assertNotIn(self.receiver_id, websocket_user.connections)
        self.repository.db.rollback.assert_not_awaited()
        self.push_service.send_notification.assert_awaited_once()

    async def test_socket_failure_does_not_disconnect_replacement_connection(self):
        replacement = SimpleNamespace(send_json=AsyncMock())

        async def reconnect(event):
            websocket_user.connections[self.receiver_id] = replacement
            raise RuntimeError("old connection closed")

        websocket_user.connections[self.receiver_id] = SimpleNamespace(send_json=AsyncMock(side_effect=reconnect))
        with self.assertLogs("services.chat_service", level="WARNING"):
            await self.send()
        self.assertIs(websocket_user.connections[self.receiver_id], replacement)

    async def test_created_at_converts_offset_and_database_precision_to_utc(self):
        self.request.created_at = "2030-01-01T07:00:00.123456+07:00"
        await self.send()
        self.assertEqual(self.repository.create_message.await_args.args[-1], datetime(2030, 1, 1, tzinfo=timezone.utc))

    async def test_naive_created_at_is_treated_as_utc(self):
        self.request.created_at = "2030-01-01T00:00:00"
        await self.send()
        self.assertEqual(self.repository.create_message.await_args.args[-1].tzinfo, timezone.utc)

    async def test_rejects_self_message(self):
        self.request.receiver_id = self.sender_id
        await self.assert_http_error(400, self.send())
        self.repository.create_message.assert_not_awaited()

    async def test_rejects_empty_or_oversized_content(self):
        for content in ("", " \n\t", "a" * 501):
            with self.subTest(content_length=len(content)):
                self.request.content = content
                await self.assert_http_error(400, self.send())
        self.repository.create_message.assert_not_awaited()

    async def test_accepts_content_at_database_limit(self):
        self.request.content = "a" * 500
        await self.send()
        self.assertEqual(self.repository.create_message.await_args.args[2], self.request.content)

    async def test_rejects_invalid_status_type_and_timestamp(self):
        self.request.status = "unknown"
        await self.assert_http_error(400, self.send())
        self.request.status = "active"
        self.request.type = " "
        await self.assert_http_error(400, self.send())
        self.request.type = "chat_message"
        self.request.created_at = "not-a-date"
        await self.assert_http_error(400, self.send())

    async def test_sender_or_receiver_must_exist(self):
        for missing_id, status_code in ((self.sender_id, 401), (self.receiver_id, 404)):
            with self.subTest(status_code=status_code):
                self.repository.get_account_by_id.side_effect = lambda account_id, **kwargs: None if account_id == missing_id else Account(id=account_id)
                await self.assert_http_error(status_code, self.send())
        self.repository.create_message.assert_not_awaited()

    async def test_database_failures_rollback_and_never_push(self):
        socket = SimpleNamespace(send_json=AsyncMock())
        websocket_user.connections[self.receiver_id] = socket
        for method in (self.repository.create_message, self.repository.update_conversation, self.repository.db.commit):
            with self.subTest(method=method):
                method.side_effect = RuntimeError("database failure")
                await self.assert_http_error(500, self.send())
                method.side_effect = None
        self.assertEqual(self.repository.db.rollback.await_count, 3)
        socket.send_json.assert_not_awaited()


class ChatRepositoryTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        # Adapter async chạy SQL trên SQLite trong bộ nhớ phục vụ test.
        # Không kiểm thử khóa đồng thời hoặc driver asyncmy của MySQL.
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.session = Session(self.engine, expire_on_commit=False)
        self.db = AsyncMock(spec=AsyncSession)
        self.db.execute.side_effect = self.session.execute
        self.db.add.side_effect = self.session.add
        self.db.flush.side_effect = self.session.flush
        self.db.commit.side_effect = self.session.commit
        self.db.rollback.side_effect = self.session.rollback
        self.repository = ChatRepository(self.db)
        self.push_service = create_autospec(PushNotificationService, instance=True)
        self.service = ChatService(self.repository, self.push_service)
        self.owner = Account(id=uuid4(), phone_number="001", password="hash", role="LANDLORD", state="ok")
        self.customer = Account(id=uuid4(), phone_number="002", password="hash", role="CUSTOMER", state="ok")
        self.other = Account(id=uuid4(), phone_number="003", password="hash", role="CUSTOMER", state="ok")
        self.session.add_all([
            self.owner, self.customer, self.other,
            LandLord(account_id=self.owner.id, full_name="Owner", avatar="owner.jpg", gender="OTHER", description=""),
            Tenant(account_id=self.customer.id, full_name="Customer", avatar="customer.jpg", gender="OTHER", description="")
        ])
        self.session.commit()
        self.created_at = datetime(2030, 1, 1, tzinfo=timezone.utc)

    def tearDown(self):
        self.session.close()
        self.engine.dispose()

    async def create_conversation(self, user1=None, user2=None, updated_at=None):
        return await self.repository.create_conversation(
            user1 or self.owner.id, user2 or self.customer.id, "Hello", updated_at or self.created_at
        )

    async def test_conversation_lookup_is_bidirectional_and_scoped(self):
        conversation = await self.create_conversation()
        forward = await self.repository.get_conversation(self.owner.id, self.customer.id)
        reverse = await self.repository.get_conversation(self.customer.id, self.owner.id, for_update=True)
        self.assertEqual(forward.id, conversation.id)
        self.assertEqual(reverse.id, conversation.id)
        self.assertIsNone(await self.repository.get_conversation(self.other.id, self.owner.id))

    async def test_conversations_are_sorted_and_profiles_loaded_in_one_query(self):
        await self.create_conversation()
        await self.create_conversation(user2=self.other.id, updated_at=self.created_at + timedelta(days=1))
        self.db.execute.reset_mock()
        rows = await self.repository.get_conversations(self.owner.id)
        self.db.execute.assert_awaited_once()
        self.assertEqual([row.target_user_id for row in rows], [self.other.id, self.customer.id])
        self.assertEqual(rows[1].target_user_name, "Customer")
        self.assertEqual(rows[1].target_avatar_url, "customer.jpg")
        self.assertEqual(rows[0].target_user_name, self.other.phone_number)
        self.assertEqual(rows[0].target_avatar_url, "")

    async def test_target_profile_works_when_current_user_is_user2(self):
        await self.create_conversation()
        rows = await self.repository.get_conversations(self.customer.id)
        self.assertEqual(rows[0].target_user_id, self.owner.id)
        self.assertEqual(rows[0].target_user_name, "Owner")
        self.assertEqual(rows[0].target_avatar_url, "owner.jpg")

    async def test_history_is_scoped_to_conversation_and_chronological(self):
        conversation = await self.create_conversation()
        another = await self.create_conversation(user2=self.other.id)
        later = await self.repository.create_message(conversation.id, self.owner.id, "Later", "active", self.created_at + timedelta(hours=1))
        earlier = await self.repository.create_message(conversation.id, self.customer.id, "Earlier", "active", self.created_at)
        await self.repository.create_message(another.id, self.other.id, "Private", "active", self.created_at)
        rows = await self.repository.get_messages(conversation.id)
        self.assertEqual([row.id for row in rows], [earlier.id, later.id])
        self.assertEqual((await self.service.get_message(self.customer.id, self.other.id)).data, [])

    async def test_last_message_and_activity_timestamp_are_updated(self):
        conversation = await self.create_conversation()
        updated_at = self.created_at + timedelta(hours=1)
        await self.repository.update_conversation(conversation, "New message", updated_at)
        self.assertEqual(self.session.get(Conversation, conversation.id).last_message, "New message")
        self.assertEqual(conversation.updated_at, updated_at)

    async def test_round_trip_reuses_conversation_for_both_senders(self):
        request = ChatMessageRequest(receiver_id=self.customer.id, content="Hello", created_at=self.created_at.isoformat(), status="active", type="chat_message")
        await self.service.send_message(self.owner.id, request)
        request.receiver_id = self.owner.id
        request.content = "Reply"
        request.created_at = (self.created_at + timedelta(minutes=1)).isoformat()
        await self.service.send_message(self.customer.id, request)
        self.assertEqual(len(self.session.execute(select(Conversation)).scalars().all()), 1)
        history = await self.service.get_message(self.owner.id, self.customer.id)
        self.assertEqual([message.content for message in history.data], ["Hello", "Reply"])
        self.assertEqual(history.data[0].receiver_id, self.customer.id)
        self.assertEqual(history.data[1].receiver_id, self.owner.id)
        self.assertEqual((await self.repository.get_conversations(self.owner.id))[0].last_message, "Reply")

    async def test_commit_failure_rolls_back_new_conversation_and_message(self):
        self.db.commit.side_effect = RuntimeError("commit failed")
        request = ChatMessageRequest(receiver_id=self.customer.id, content="Hello", created_at=self.created_at.isoformat(), status="active", type="chat_message")
        with self.assertRaises(HTTPException) as error:
            await self.service.send_message(self.owner.id, request)
        self.assertEqual(error.exception.status_code, 500)
        self.assertEqual(self.session.execute(select(Conversation)).scalars().all(), [])
        self.assertEqual(self.session.execute(select(Message)).scalars().all(), [])


if __name__ == "__main__":
    unittest.main()
