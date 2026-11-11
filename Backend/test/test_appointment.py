import unittest
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, create_autospec
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import create_engine, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.websocket.user import websocket_user
from db.base import Base
from models.account import Account
from models.appointment import Appointment
from models.landlord import LandLord
from models.location import Location
from models.notification import Notification
from models.room import Room
from models.tenant import Tenant
from repositories.appointment_repository import AppointmentRepository
from schemas.appointment import AppointmentRequest
from services.appointment_service import AppointmentService
from services.push_notification_service import PushNotificationService


class AppointmentServiceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repository = create_autospec(AppointmentRepository, instance=True)
        self.repository.db = AsyncMock(spec=AsyncSession)
        self.push_service = create_autospec(PushNotificationService, instance=True)
        self.service = AppointmentService(self.repository, self.push_service)
        self.tenant = Tenant(id=uuid4(), account_id=uuid4(), full_name="Khách thuê")
        self.landlord = LandLord(id=uuid4(), account_id=uuid4())
        self.room = Room(id=uuid4(), landlord_id=self.landlord.id, name="Phòng 101")
        self.meet_at = datetime.now(timezone(timedelta(hours=7))).replace(tzinfo=None, microsecond=0) + timedelta(days=1)
        self.appointment = Appointment(
            id=uuid4(), id_room=self.room.id, id_tenant=self.tenant.id,
            meet_at=self.meet_at, status="PENDING"
        )
        self.request = AppointmentRequest(id_room=self.room.id, meet_at=self.meet_at)
        self.repository.get_tenant_by_id_account.return_value = self.tenant
        self.repository.get_tenant_by_id.return_value = self.tenant
        self.repository.get_landlord_by_id.return_value = self.landlord
        self.repository.get_room_by_id.return_value = self.room
        self.repository.get_conflicting_appointment.return_value = None
        self.repository.create_appointment.return_value = self.appointment
        self.repository.get_appointment_by_id.return_value = self.appointment
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

    async def confirm(self, status="CONFIRMED", account_id=None):
        return await self.service.confirm_appointment(
            account_id or self.landlord.account_id, str(self.appointment.id), status
        )

    async def test_send_offline_saves_notification_for_landlord(self):
        response = await self.service.send_appointment(self.request, self.tenant.account_id)
        self.assertEqual(response.id_appointment, str(self.appointment.id))
        self.assertEqual(response.name_tenant, self.tenant.full_name)
        self.assertEqual(self.repository.create_notification.await_args.args[0], self.landlord.account_id)
        self.repository.db.commit.assert_awaited_once()

    async def test_send_online_pushes_json_only_after_commit(self):
        async def check_committed(message):
            self.repository.db.commit.assert_awaited_once()
            self.assertEqual(message["type"], "appointment_created")
            self.assertEqual(message["data"]["id_room"], str(self.room.id))

        socket = SimpleNamespace(send_json=AsyncMock(side_effect=check_committed))
        websocket_user.connections[self.landlord.account_id] = socket
        await self.service.send_appointment(self.request, self.tenant.account_id)
        socket.send_json.assert_awaited_once()
        self.repository.create_notification.assert_awaited_once()

    async def test_disconnected_socket_keeps_single_notification_and_sends_push(self):
        socket = SimpleNamespace(send_json=AsyncMock(side_effect=RuntimeError("closed")))
        websocket_user.connections[self.landlord.account_id] = socket
        with self.assertLogs("services.appointment_service", level="WARNING"):
            await self.service.send_appointment(self.request, self.tenant.account_id)
        self.assertNotIn(self.landlord.account_id, websocket_user.connections)
        self.repository.create_notification.assert_awaited_once()
        self.repository.db.commit.assert_awaited_once()
        self.push_service.send_notification.assert_awaited_once()

    async def test_disconnection_during_commit_still_attempts_delivery(self):
        socket = SimpleNamespace(send_json=AsyncMock(side_effect=RuntimeError("closed")))
        websocket_user.connections[self.landlord.account_id] = socket
        self.repository.db.commit.side_effect = lambda: websocket_user.connections.clear()
        with self.assertLogs("services.appointment_service", level="WARNING"):
            await self.service.send_appointment(self.request, self.tenant.account_id)
        self.repository.create_notification.assert_awaited_once()

    async def test_online_notification_failure_rolls_back_before_any_delivery(self):
        socket = SimpleNamespace(send_json=AsyncMock())
        websocket_user.connections[self.landlord.account_id] = socket
        self.repository.create_notification.side_effect = RuntimeError("database unavailable")
        await self.assert_http_error(500, self.service.send_appointment(self.request, self.tenant.account_id))
        self.repository.db.rollback.assert_awaited_once()
        self.repository.db.commit.assert_not_awaited()
        socket.send_json.assert_not_awaited()

    async def test_offline_notification_failure_rolls_back_appointment(self):
        self.repository.create_notification.side_effect = RuntimeError("database unavailable")
        await self.assert_http_error(500, self.service.send_appointment(self.request, self.tenant.account_id))
        self.repository.db.rollback.assert_awaited_once()
        self.repository.db.commit.assert_not_awaited()

    async def test_commit_failure_does_not_push_realtime(self):
        socket = SimpleNamespace(send_json=AsyncMock())
        websocket_user.connections[self.landlord.account_id] = socket
        self.repository.db.commit.side_effect = RuntimeError("commit failed")
        await self.assert_http_error(500, self.service.send_appointment(self.request, self.tenant.account_id))
        socket.send_json.assert_not_awaited()
        self.repository.db.rollback.assert_awaited_once()

    async def test_send_past_time_returns_400(self):
        self.request.meet_at = self.meet_at - timedelta(days=2)
        await self.assert_http_error(400, self.service.send_appointment(self.request, self.tenant.account_id))
        self.repository.create_appointment.assert_not_awaited()

    async def test_aware_time_is_normalized_to_vietnam_time(self):
        self.request.meet_at = self.meet_at.replace(tzinfo=timezone(timedelta(hours=7))).astimezone(timezone.utc)
        await self.service.send_appointment(self.request, self.tenant.account_id)
        self.assertEqual(self.repository.create_appointment.await_args.args[2], self.meet_at)

    async def test_subsecond_time_uses_database_precision_for_conflict_check(self):
        self.request.meet_at = self.meet_at.replace(microsecond=123456)
        await self.service.send_appointment(self.request, self.tenant.account_id)
        self.assertEqual(self.repository.get_conflicting_appointment.await_args.args[2], self.meet_at)
        self.assertEqual(self.repository.create_appointment.await_args.args[2], self.meet_at)

    async def test_send_conflict_preserves_409(self):
        self.repository.get_conflicting_appointment.return_value = self.appointment
        await self.assert_http_error(409, self.service.send_appointment(self.request, self.tenant.account_id))
        self.repository.create_appointment.assert_not_awaited()
        self.repository.db.rollback.assert_awaited_once()

    async def test_send_missing_resources_return_404(self):
        for method, value in (
            (self.repository.get_tenant_by_id_account, self.tenant),
            (self.repository.get_room_by_id, self.room),
            (self.repository.get_landlord_by_id, self.landlord)
        ):
            with self.subTest(method=method):
                method.return_value = None
                await self.assert_http_error(404, self.service.send_appointment(self.request, self.tenant.account_id))
                method.return_value = value

    async def test_confirm_offline_notifies_tenant(self):
        response = await self.confirm()
        self.assertEqual(self.appointment.status, "CONFIRMED")
        self.assertTrue(response.message)
        self.assertEqual(self.repository.create_notification.await_args.args[0], self.tenant.account_id)

    async def test_confirm_online_notifies_correct_tenant(self):
        socket = SimpleNamespace(send_json=AsyncMock())
        websocket_user.connections[self.tenant.account_id] = socket
        await self.confirm("confirmed")
        message = socket.send_json.await_args.args[0]
        self.assertEqual(message["status"], "CONFIRMED")
        self.repository.create_notification.assert_awaited_once()

    async def test_creation_push_targets_landlord_after_commit_online_or_offline(self):
        commits_at_push = []

        async def record_commit(**kwargs):
            commits_at_push.append(self.repository.db.commit.await_count)

        self.push_service.send_notification.side_effect = record_commit
        for online in (False, True):
            with self.subTest(online=online):
                self.repository.create_notification.reset_mock()
                self.repository.db.commit.reset_mock()
                self.push_service.send_notification.reset_mock()
                if online:
                    websocket_user.connections[self.landlord.account_id] = SimpleNamespace(send_json=AsyncMock())
                await self.service.send_appointment(self.request, self.tenant.account_id)
                self.push_service.send_notification.assert_awaited_once_with(
                    id_account=str(self.landlord.account_id),
                    title="Yêu cầu xem phòng mới",
                    body="Bạn vừa nhận được một yêu cầu đặt lịch xem phòng.",
                    data={"type": "appointment", "appointment_id": str(self.appointment.id)}
                )
                self.repository.create_notification.assert_awaited_once()
        self.assertEqual(commits_at_push, [1, 1])

    async def test_confirmation_push_targets_tenant_and_repeat_does_not_push(self):
        state_at_push = []

        async def record_commit(**kwargs):
            state_at_push.append((self.repository.db.commit.await_count, self.appointment.status))

        self.push_service.send_notification.side_effect = record_commit
        await self.confirm()
        self.assertEqual(state_at_push, [(1, "CONFIRMED")])
        self.push_service.send_notification.assert_awaited_once_with(
            id_account=str(self.tenant.account_id),
            title="Lịch hẹn đã được xác nhận",
            body="Chủ trọ đã xác nhận lịch hẹn xem phòng của bạn.",
            data={"type": "appointment", "appointment_id": str(self.appointment.id)}
        )
        with self.assertRaises(HTTPException) as error:
            await self.confirm()
        self.assertEqual(error.exception.status_code, 409)
        self.push_service.send_notification.assert_awaited_once()
        self.repository.create_notification.assert_awaited_once()
        self.repository.db.commit.assert_awaited_once()

    async def test_duplicate_creation_does_not_push_again(self):
        await self.service.send_appointment(self.request, self.tenant.account_id)
        self.repository.get_conflicting_appointment.return_value = self.appointment
        with self.assertRaises(HTTPException) as error:
            await self.service.send_appointment(self.request, self.tenant.account_id)
        self.assertEqual(error.exception.status_code, 409)
        self.push_service.send_notification.assert_awaited_once()
        self.repository.create_notification.assert_awaited_once()

    async def test_push_failure_preserves_creation_confirmation_and_realtime(self):
        self.push_service.send_notification.side_effect = RuntimeError("Firebase unavailable")
        for confirm in (False, True):
            with self.subTest(confirm=confirm):
                self.repository.db.commit.reset_mock()
                self.repository.create_notification.reset_mock()
                recipient = self.tenant.account_id if confirm else self.landlord.account_id
                socket = SimpleNamespace(send_json=AsyncMock())
                websocket_user.connections[recipient] = socket
                with self.assertLogs("services.appointment_service", level="ERROR"):
                    if confirm:
                        result = await self.confirm()
                        self.assertTrue(result.message)
                    else:
                        result = await self.service.send_appointment(self.request, self.tenant.account_id)
                        self.assertEqual(result.id_appointment, str(self.appointment.id))
                socket.send_json.assert_awaited_once()
                self.repository.create_notification.assert_awaited_once()
                self.repository.db.commit.assert_awaited_once()
                self.repository.db.rollback.assert_not_awaited()

    async def test_confirm_commit_failure_sends_neither_push_nor_realtime(self):
        socket = SimpleNamespace(send_json=AsyncMock())
        websocket_user.connections[self.tenant.account_id] = socket
        self.repository.db.commit.side_effect = RuntimeError("commit failed")
        await self.assert_http_error(500, self.confirm())
        socket.send_json.assert_not_awaited()
        self.repository.db.rollback.assert_awaited_once()

    async def test_confirm_rejects_another_landlord(self):
        await self.assert_http_error(404, self.confirm(account_id=uuid4()))
        self.repository.db.commit.assert_not_awaited()

    async def test_confirm_validates_id_and_existence(self):
        await self.assert_http_error(400, self.service.confirm_appointment(self.landlord.account_id, "bad-id", "CONFIRMED"))
        self.repository.get_appointment_by_id.return_value = None
        await self.assert_http_error(404, self.confirm())

    async def test_confirm_unknown_status_returns_400(self):
        await self.assert_http_error(400, self.confirm("CANCELLED"))
        self.repository.db.commit.assert_not_awaited()

    async def test_confirm_terminal_status_returns_409(self):
        for status in ("REJECTED", "CANCELLED", "COMPLETED", "CONFIRMED"):
            with self.subTest(status=status):
                self.appointment.status = status
                await self.assert_http_error(409, self.confirm())

    async def test_confirm_past_time_returns_400(self):
        self.appointment.meet_at -= timedelta(days=2)
        await self.assert_http_error(400, self.confirm())

    async def test_confirm_conflict_returns_409(self):
        self.repository.get_conflicting_appointment.return_value = self.appointment
        await self.assert_http_error(409, self.confirm())

    async def test_reject_pending_appointment(self):
        await self.confirm("REJECTED")
        self.assertEqual(self.appointment.status, "REJECTED")
        self.push_service.send_notification.assert_not_awaited()

    async def test_complete_requires_confirmed_past_appointment(self):
        await self.assert_http_error(409, self.confirm("COMPLETED"))
        self.appointment.status = "CONFIRMED"
        await self.assert_http_error(400, self.confirm("COMPLETED"))
        self.appointment.meet_at -= timedelta(days=2)
        await self.confirm("COMPLETED")
        self.assertEqual(self.appointment.status, "COMPLETED")
        self.push_service.send_notification.assert_not_awaited()

    async def test_get_all_uses_existing_response_schema(self):
        self.repository.get_appointments_by_id_account.return_value = [SimpleNamespace(
            id_appointment=self.appointment.id, name_tenant=self.tenant.full_name,
            id_room=self.room.id, name_room=self.room.name, meet_at=self.meet_at,
            status=self.appointment.status
        )]
        result = await self.service.get_all_appointment(self.tenant.account_id)
        self.assertEqual(result.data[0].id_appointment, str(self.appointment.id))
        self.repository.get_appointments_by_id_account.return_value = []
        self.assertEqual((await self.service.get_all_appointment(self.tenant.account_id)).data, [])

    async def test_cancel_marks_status_and_notifies_landlord(self):
        await self.service.destroy_appointment(self.tenant.account_id, str(self.appointment.id))
        self.assertEqual(self.appointment.status, "CANCELLED")
        self.assertEqual(self.repository.create_notification.await_args.args[0], self.landlord.account_id)
        self.push_service.send_notification.assert_not_awaited()

    async def test_cancel_checks_ownership_and_terminal_status(self):
        self.appointment.id_tenant = uuid4()
        await self.assert_http_error(404, self.service.destroy_appointment(self.tenant.account_id, str(self.appointment.id)))
        self.appointment.id_tenant = self.tenant.id
        self.appointment.status = "COMPLETED"
        await self.assert_http_error(409, self.service.destroy_appointment(self.tenant.account_id, str(self.appointment.id)))

    async def test_update_resets_confirmation_and_excludes_itself_from_conflict(self):
        self.appointment.status = "CONFIRMED"
        self.request.meet_at += timedelta(hours=1)
        await self.service.update_appointment(self.tenant.account_id, self.request, str(self.appointment.id))
        self.assertEqual(self.appointment.meet_at, self.request.meet_at)
        self.assertEqual(self.appointment.status, "PENDING")
        self.assertEqual(self.repository.get_conflicting_appointment.await_args.args[-1], self.appointment.id)
        self.push_service.send_notification.assert_not_awaited()

    async def test_update_checks_ownership_room_and_conflict(self):
        self.appointment.id_tenant = uuid4()
        await self.assert_http_error(404, self.service.update_appointment(self.tenant.account_id, self.request, str(self.appointment.id)))
        self.appointment.id_tenant = self.tenant.id
        self.request.id_room = uuid4()
        await self.assert_http_error(400, self.service.update_appointment(self.tenant.account_id, self.request, str(self.appointment.id)))
        self.request.id_room = self.room.id
        self.repository.get_conflicting_appointment.return_value = self.appointment
        await self.assert_http_error(409, self.service.update_appointment(self.tenant.account_id, self.request, str(self.appointment.id)))


class AppointmentRepositoryTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        # Chạy SQL thật trên SQLite trong bộ nhớ qua adapter async phục vụ test.
        # Đây không phải kiểm thử driver asyncmy hay khóa đồng thời của MySQL.
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.session = Session(self.engine, expire_on_commit=False)
        self.db = AsyncMock(spec=AsyncSession)
        self.db.execute.side_effect = self.session.execute
        self.db.add.side_effect = self.session.add
        self.db.flush.side_effect = self.session.flush
        self.db.commit.side_effect = self.session.commit
        self.db.rollback.side_effect = self.session.rollback
        self.repository = AppointmentRepository(self.db)
        self.tenant_account = Account(id=uuid4(), phone_number="001", password="hash", role="TENANT", state="ok")
        self.landlord_account = Account(id=uuid4(), phone_number="002", password="hash", role="LANDLORD", state="ok")
        self.tenant = Tenant(id=uuid4(), account_id=self.tenant_account.id, full_name="Tenant", gender="OTHER", avatar="", description="")
        self.landlord = LandLord(id=uuid4(), account_id=self.landlord_account.id, full_name="Landlord", gender="OTHER", avatar="", description="")
        self.location = Location(id=uuid4(), name="Location", longitude=106.7, latitude=10.8, type="WARD")
        self.room = Room(
            id=uuid4(), landlord_id=self.landlord.id, location_id=self.location.id,
            name="Room", area=20, water_fee=0, service_fee=0, parking_fee=0,
            rental_price=100, electricity_fee=0, status="AVAILABLE", room_type="ROOM"
        )
        self.session.add_all([self.tenant_account, self.landlord_account, self.tenant, self.landlord, self.location, self.room])
        self.session.commit()
        self.meet_at = datetime(2030, 1, 1, 10)

    def tearDown(self):
        self.session.close()
        self.engine.dispose()

    async def test_create_lookup_and_notification_use_model_fields(self):
        appointment = await self.repository.create_appointment(self.room.id, self.tenant.id, self.meet_at)
        self.assertIsNotNone(appointment.id)
        self.assertEqual((await self.repository.get_appointment_by_id(appointment.id)).status, "PENDING")
        notification = await self.repository.create_notification(self.landlord_account.id, "New appointment")
        self.assertFalse(notification.is_read)
        self.assertEqual(self.session.get(Notification, notification.id).id_account, self.landlord_account.id)

    async def test_online_creation_persists_one_notification_despite_push_failure(self):
        push_service = create_autospec(PushNotificationService, instance=True)
        push_service.send_notification.side_effect = RuntimeError("Firebase unavailable")
        service = AppointmentService(self.repository, push_service)
        socket = SimpleNamespace(send_json=AsyncMock())
        account_id = self.landlord_account.id
        previous_socket = websocket_user.connections.get(account_id)
        websocket_user.connections[account_id] = socket
        request = AppointmentRequest(id_room=self.room.id, meet_at=self.meet_at)
        try:
            with self.assertLogs("services.appointment_service", level="ERROR"):
                response = await service.send_appointment(request, self.tenant_account.id)
            # Dữ liệu đã commit phải còn sau rollback và khi đọc lại từ DB.
            self.session.rollback()
            self.session.expunge_all()
            appointments = self.session.execute(select(Appointment)).scalars().all()
            notifications = self.session.execute(select(Notification)).scalars().all()
            self.assertEqual([str(item.id) for item in appointments], [response.id_appointment])
            self.assertEqual(len(notifications), 1)
            self.assertEqual(notifications[0].id_account, account_id)
            socket.send_json.assert_awaited_once()
            push_service.send_notification.assert_awaited_once()
            self.db.commit.assert_awaited_once()
        finally:
            if previous_socket is None:
                websocket_user.connections.pop(account_id, None)
            else:
                websocket_user.connections[account_id] = previous_socket

    async def test_commit_failure_rolls_back_appointment_and_notification_without_push(self):
        push_service = create_autospec(PushNotificationService, instance=True)
        service = AppointmentService(self.repository, push_service)
        self.db.commit.side_effect = RuntimeError("commit failed")
        request = AppointmentRequest(id_room=self.room.id, meet_at=self.meet_at)
        with self.assertRaises(HTTPException) as error:
            await service.send_appointment(request, self.tenant_account.id)
        self.assertEqual(error.exception.status_code, 500)
        self.assertEqual(self.session.execute(select(Appointment)).scalars().all(), [])
        self.assertEqual(self.session.execute(select(Notification)).scalars().all(), [])
        push_service.send_notification.assert_not_awaited()

    async def test_conflicts_cover_room_or_tenant_and_ignore_inactive_or_self(self):
        appointment = await self.repository.create_appointment(self.room.id, self.tenant.id, self.meet_at)
        self.assertIsNotNone(await self.repository.get_conflicting_appointment(self.room.id, uuid4(), self.meet_at))
        self.assertIsNotNone(await self.repository.get_conflicting_appointment(uuid4(), self.tenant.id, self.meet_at))
        self.assertIsNone(await self.repository.get_conflicting_appointment(self.room.id, self.tenant.id, self.meet_at, appointment.id))
        self.assertIsNone(await self.repository.get_conflicting_appointment(self.room.id, self.tenant.id, self.meet_at + timedelta(hours=1)))
        for status in ("REJECTED", "CANCELLED", "COMPLETED"):
            appointment.status = status
            self.assertIsNone(await self.repository.get_conflicting_appointment(self.room.id, self.tenant.id, self.meet_at))
        appointment.status = "CONFIRMED"
        self.assertIsNotNone(await self.repository.get_conflicting_appointment(self.room.id, self.tenant.id, self.meet_at))

    async def test_list_is_scoped_to_tenant_and_room_owner(self):
        await self.repository.create_appointment(self.room.id, self.tenant.id, self.meet_at)
        for account_id in (self.tenant_account.id, self.landlord_account.id):
            rows = await self.repository.get_appointments_by_id_account(account_id)
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0].name_tenant, self.tenant.full_name)
            self.assertEqual(rows[0].name_room, self.room.name)
        self.assertEqual(await self.repository.get_appointments_by_id_account(uuid4()), [])


if __name__ == "__main__":
    unittest.main()
