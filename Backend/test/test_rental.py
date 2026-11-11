import asyncio
import json
import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, create_autospec, patch
from uuid import uuid4

from fastapi import HTTPException
from redis.exceptions import RedisError
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from db.base import Base
from models.account import Account
from models.landlord import LandLord
from models.location import Location
from models.room import Room
from models.room_image import RoomImage
from models.room_rental import RoomRental
from models.tenant import Tenant
from repositories.rental_repository import RentalRepository
from schemas.rental import RentalVerifyRequest
from services.rental_service import RentalService


class RentalServiceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repository = create_autospec(RentalRepository, instance=True)
        self.repository.db = AsyncMock(spec=AsyncSession)
        self.service = RentalService(self.repository)
        self.account = Account(id=uuid4(), role="LANDLORD")
        self.landlord = LandLord(id=uuid4(), account_id=self.account.id)
        self.tenant = Tenant(id=uuid4(), account_id=uuid4())
        self.room = Room(id=uuid4(), landlord_id=self.landlord.id)
        self.rental = RoomRental(id=uuid4(), id_room=self.room.id, id_tenant=self.tenant.id, status="active")
        self.repository.get_account_by_id.return_value = self.account
        self.repository.get_landlord_by_id_account.return_value = self.landlord
        self.repository.get_tenant_by_id_account.return_value = self.tenant
        self.repository.get_room_by_id.return_value = self.room
        self.repository.get_active_rental.return_value = None
        self.repository.get_rental_by_id.return_value = self.rental
        self.payload = json.dumps({"room_id": str(self.room.id), "landlord_id": str(self.landlord.id)})
        self.redis = SimpleNamespace(
            set=AsyncMock(return_value=True), getdel=AsyncMock(return_value=self.payload)
        )
        self.redis_patch = patch("services.rental_service.redis_client", SimpleNamespace(client=self.redis))
        self.redis_patch.start()
        self.addCleanup(self.redis_patch.stop)

    async def assert_http_error(self, status_code, operation):
        with self.assertRaises(HTTPException) as error:
            await operation
        self.assertEqual(error.exception.status_code, status_code)

    async def create_code(self):
        return await self.service.create_qr_code(str(self.room.id), self.account.id)

    async def verify_code(self, token="123456"):
        self.account.role = "TENANT"
        return await self.service.verify_qr_code(RentalVerifyRequest(token=token), self.tenant.account_id)

    async def destroy(self):
        self.account.role = "LANDLORD"
        return await self.service.destroy_relation(str(self.rental.id), self.account.id)

    async def test_create_six_digit_code_with_ttl_and_collision_protection(self):
        with patch("services.rental_service.secrets.randbelow", return_value=42):
            response = await self.create_code()
        self.assertEqual(response.qr_token, "000042")
        self.assertEqual(response.expires_in_second, 60)
        args, kwargs = self.redis.set.await_args
        self.assertEqual(args[0], "rental:qr:000042")
        self.assertEqual(json.loads(args[1])["room_id"], str(self.room.id))
        self.assertEqual(kwargs, {"ex": 60, "nx": True})

    async def test_create_retries_collision_without_overwriting_existing_token(self):
        self.redis.set.side_effect = [False, True]
        with patch("services.rental_service.secrets.randbelow", side_effect=[123456, 654321]):
            response = await self.create_code()
        self.assertEqual(response.qr_token, "654321")
        self.assertEqual(self.redis.set.await_count, 2)

    async def test_create_exhausted_collisions_returns_503(self):
        self.redis.set.return_value = False
        await self.assert_http_error(503, self.create_code())
        self.assertEqual(self.redis.set.await_count, 10)

    async def test_create_rejects_wrong_role(self):
        self.account.role = "TENANT"
        await self.assert_http_error(403, self.create_code())
        self.redis.set.assert_not_awaited()

    async def test_create_checks_room_ownership(self):
        self.room.landlord_id = uuid4()
        await self.assert_http_error(403, self.create_code())
        self.redis.set.assert_not_awaited()

    async def test_create_validates_room_id(self):
        await self.assert_http_error(400, self.service.create_qr_code("bad-id", self.account.id))

    async def test_create_missing_account_profile_or_room(self):
        for method, value, status_code in (
            (self.repository.get_account_by_id, self.account, 401),
            (self.repository.get_landlord_by_id_account, self.landlord, 404),
            (self.repository.get_room_by_id, self.room, 404)
        ):
            with self.subTest(status_code=status_code):
                method.return_value = None
                await self.assert_http_error(status_code, self.create_code())
                method.return_value = value

    async def test_create_redis_failure_returns_503(self):
        self.redis.set.side_effect = RedisError("unavailable")
        await self.assert_http_error(503, self.create_code())

    async def test_verify_creates_relation_and_commits(self):
        response = await self.verify_code()
        self.assertTrue(response.id_valid)
        self.redis.getdel.assert_awaited_once_with("rental:qr:123456")
        self.repository.get_room_by_id.assert_awaited_once_with(self.room.id, for_update=True)
        self.repository.create_rental.assert_awaited_once_with(self.room.id, self.tenant.id)
        self.repository.db.commit.assert_awaited_once()

    async def test_verify_token_can_only_be_consumed_once_concurrently(self):
        values = {"rental:qr:123456": self.payload}
        self.redis.getdel.side_effect = lambda key: values.pop(key, None)
        outcomes = await asyncio.gather(self.verify_code(), self.verify_code(), return_exceptions=True)
        self.assertEqual(sum(isinstance(result, HTTPException) and result.status_code == 400 for result in outcomes), 1)
        self.assertEqual(sum(getattr(result, "id_valid", False) for result in outcomes), 1)
        self.repository.create_rental.assert_awaited_once()

    async def test_verify_rejects_expired_or_used_token(self):
        self.redis.getdel.return_value = None
        await self.assert_http_error(400, self.verify_code())
        self.repository.create_rental.assert_not_awaited()
        self.repository.db.rollback.assert_awaited_once()

    async def test_verify_validates_token_format_before_consuming(self):
        for token in ("", "12345", "1234567", "abcdef", "１２３４５６", " 12345"):
            with self.subTest(token=token):
                await self.assert_http_error(400, self.verify_code(token))
        self.redis.getdel.assert_not_awaited()

    async def test_verify_checks_role_before_consuming_token(self):
        await self.assert_http_error(403, self.service.verify_qr_code(RentalVerifyRequest(token="123456"), self.account.id))
        self.redis.getdel.assert_not_awaited()

    async def test_verify_missing_tenant_profile_does_not_consume_token(self):
        self.repository.get_tenant_by_id_account.return_value = None
        await self.assert_http_error(404, self.verify_code())
        self.redis.getdel.assert_not_awaited()

    async def test_verify_rejects_malformed_payload(self):
        for payload in ("bad json", "{}", "[]", '"text"', '{"room_id":"bad", "landlord_id":"bad"}'):
            with self.subTest(payload=payload):
                self.redis.getdel.return_value = payload
                await self.assert_http_error(400, self.verify_code())
        self.repository.create_rental.assert_not_awaited()

    async def test_verify_rechecks_room_existence_and_owner(self):
        self.repository.get_room_by_id.return_value = None
        await self.assert_http_error(404, self.verify_code())
        self.repository.get_room_by_id.return_value = self.room
        self.room.landlord_id = uuid4()
        await self.assert_http_error(400, self.verify_code())

    async def test_verify_duplicate_active_relation_returns_409(self):
        self.repository.get_active_rental.return_value = self.rental
        await self.assert_http_error(409, self.verify_code())
        self.repository.create_rental.assert_not_awaited()

    async def test_verify_redis_failure_returns_503(self):
        self.redis.getdel.side_effect = RedisError("unavailable")
        await self.assert_http_error(503, self.verify_code())
        self.repository.db.rollback.assert_awaited_once()

    async def test_verify_database_failure_rolls_back(self):
        for method in (self.repository.create_rental, self.repository.db.commit):
            with self.subTest(method=method):
                method.side_effect = RuntimeError("database failure")
                await self.assert_http_error(500, self.verify_code())
                method.side_effect = None
        self.assertEqual(self.repository.db.rollback.await_count, 2)

    async def test_destroy_deactivates_without_deleting_history(self):
        result = await self.destroy()
        self.assertTrue(result.id_valid)
        self.repository.deactivate_rental.assert_awaited_once_with(self.rental)
        self.repository.db.commit.assert_awaited_once()
        self.repository.db.delete.assert_not_awaited()

    async def test_destroy_checks_ownership(self):
        self.room.landlord_id = uuid4()
        await self.assert_http_error(403, self.destroy())
        self.repository.deactivate_rental.assert_not_awaited()

    async def test_destroy_rejects_missing_or_already_deactivated_relation(self):
        self.repository.get_rental_by_id.return_value = None
        await self.assert_http_error(404, self.destroy())
        self.repository.get_rental_by_id.return_value = self.rental
        self.rental.status = "deactivate"
        await self.assert_http_error(409, self.destroy())

    async def test_destroy_database_failure_rolls_back(self):
        self.repository.db.commit.side_effect = RuntimeError("commit failure")
        await self.assert_http_error(500, self.destroy())
        self.repository.db.rollback.assert_awaited_once()

    async def test_landlord_list_maps_schema_and_handles_empty_avatar(self):
        self.repository.get_current_tenants_for_landlord.return_value = [SimpleNamespace(
            tenant_id=self.tenant.id, full_name="Tenant", avatar_url=None,
            phone_number="0123456789", room_id=self.room.id, room_name="Room",
            start_date=datetime.now(timezone.utc), status="active"
        )]
        response = await self.service.get_current_tenants_for_landlord(self.account.id)
        self.assertEqual(response.data[0].avatar_url, "")
        self.assertEqual(response.data[0].tenant_id, self.tenant.id)
        self.repository.get_current_tenants_for_landlord.assert_awaited_once_with(self.landlord.id)

    async def test_tenant_list_maps_schema_and_handles_missing_thumbnail(self):
        self.account.role = "tenant"
        self.repository.get_rented_rooms_for_tenant.return_value = [SimpleNamespace(
            rental_id=self.rental.id, start_date=datetime.now(timezone.utc), status="active",
            room_id=self.room.id, room_name="Room", room_thumbnail=None,
            address="Address", price=1500000.0
        )]
        response = await self.service.get_rented_rooms_for_tenant(self.tenant.account_id)
        self.assertEqual(response.data[0].rental_id, self.rental.id)
        self.assertEqual(response.data[0].room_thumbnail, "")
        self.assertEqual(response.data[0].price, 1500000.0)

    async def test_lists_require_the_correct_role_and_allow_empty_results(self):
        self.repository.get_current_tenants_for_landlord.return_value = []
        self.repository.get_rented_rooms_for_tenant.return_value = []
        self.assertEqual((await self.service.get_current_tenants_for_landlord(self.account.id)).data, [])
        await self.assert_http_error(403, self.service.get_rented_rooms_for_tenant(self.account.id))
        self.account.role = "TENANT"
        self.assertEqual((await self.service.get_rented_rooms_for_tenant(self.tenant.account_id)).data, [])
        await self.assert_http_error(403, self.service.get_current_tenants_for_landlord(self.tenant.account_id))


class RentalRepositoryTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        # SQL thật trên SQLite trong bộ nhớ qua adapter async phục vụ test.
        # Không kiểm thử driver asyncmy hoặc cơ chế khóa đồng thời của MySQL.
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.session = Session(self.engine, expire_on_commit=False)
        self.db = AsyncMock(spec=AsyncSession)
        self.db.execute.side_effect = self.session.execute
        self.db.add.side_effect = self.session.add
        self.db.flush.side_effect = self.session.flush
        self.repository = RentalRepository(self.db)
        self.landlord_account = Account(id=uuid4(), phone_number="001", password="hash", role="LANDLORD", state="ok")
        self.tenant_account = Account(id=uuid4(), phone_number="002", password="hash", role="TENANT", state="ok")
        self.landlord = LandLord(id=uuid4(), account_id=self.landlord_account.id, full_name="Owner", gender="OTHER", avatar="", description="")
        self.tenant = Tenant(id=uuid4(), account_id=self.tenant_account.id, full_name="Tenant", gender="OTHER", avatar="avatar.jpg", description="")
        self.location = Location(id=uuid4(), name="Address", longitude=106.7, latitude=10.8)
        self.room = Room(
            id=uuid4(), landlord_id=self.landlord.id, location_id=self.location.id,
            name="Room", area=20, water_fee=0, service_fee=0, parking_fee=0,
            rental_price=1500000, electricity_fee=0, status="AVAILABLE", room_type="ROOM"
        )
        self.session.add_all([self.landlord_account, self.tenant_account, self.landlord, self.tenant, self.location, self.room])
        self.session.commit()

    def tearDown(self):
        self.session.close()
        self.engine.dispose()

    async def test_create_deactivate_and_create_new_relation_preserves_history(self):
        first = await self.repository.create_rental(self.room.id, self.tenant.id)
        self.assertIsNotNone(first.id)
        self.assertIsNotNone(first.rent_at)
        self.assertEqual((await self.repository.get_active_rental(self.room.id, self.tenant.id)).id, first.id)
        await self.repository.deactivate_rental(first)
        self.assertEqual(self.session.get(RoomRental, first.id).status, "deactivate")
        self.assertIsNone(await self.repository.get_active_rental(self.room.id, self.tenant.id))
        second = await self.repository.create_rental(self.room.id, self.tenant.id)
        self.assertNotEqual(first.id, second.id)
        self.assertEqual(self.session.query(RoomRental).count(), 2)

    async def test_tenant_list_uses_one_query_and_keeps_room_without_thumbnail(self):
        rental = await self.repository.create_rental(self.room.id, self.tenant.id)
        self.db.execute.reset_mock()
        rows = await self.repository.get_rented_rooms_for_tenant(self.tenant.id)
        self.db.execute.assert_awaited_once()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].rental_id, rental.id)
        self.assertIsNone(rows[0].room_thumbnail)
        self.assertEqual(rows[0].address, self.location.name)
        self.assertEqual(rows[0].price, self.room.rental_price)

    async def test_multiple_thumbnails_do_not_duplicate_rental_rows(self):
        await self.repository.create_rental(self.room.id, self.tenant.id)
        self.session.add_all([
            RoomImage(room_id=self.room.id, image_url="b.jpg", public_id="b", is_thumbnail=True),
            RoomImage(room_id=self.room.id, image_url="a.jpg", public_id="a", is_thumbnail=True),
            RoomImage(room_id=self.room.id, image_url="other.jpg", public_id="other", is_thumbnail=False)
        ])
        rows = await self.repository.get_rented_rooms_for_tenant(self.tenant.id)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].room_thumbnail, "a.jpg")

    async def test_landlord_list_joins_profile_account_and_room_in_one_query(self):
        await self.repository.create_rental(self.room.id, self.tenant.id)
        self.db.execute.reset_mock()
        rows = await self.repository.get_current_tenants_for_landlord(self.landlord.id)
        self.db.execute.assert_awaited_once()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].phone_number, self.tenant_account.phone_number)
        self.assertEqual(rows[0].avatar_url, self.tenant.avatar)
        self.assertEqual(rows[0].room_name, self.room.name)

    async def test_lists_are_scoped_by_owner_tenant_and_active_status(self):
        rental = await self.repository.create_rental(self.room.id, self.tenant.id)
        self.assertEqual(await self.repository.get_current_tenants_for_landlord(uuid4()), [])
        self.assertEqual(await self.repository.get_rented_rooms_for_tenant(uuid4()), [])
        for status in ("deactivate", "inactive"):
            rental.status = status
            self.assertEqual(await self.repository.get_current_tenants_for_landlord(self.landlord.id), [])
            self.assertEqual(await self.repository.get_rented_rooms_for_tenant(self.tenant.id), [])

    async def test_lookup_methods_return_existing_records_and_none_for_missing(self):
        self.assertEqual((await self.repository.get_account_by_id(self.tenant_account.id)).role, "TENANT")
        self.assertEqual((await self.repository.get_tenant_by_id_account(self.tenant_account.id)).id, self.tenant.id)
        self.assertEqual((await self.repository.get_landlord_by_id_account(self.landlord_account.id)).id, self.landlord.id)
        self.assertEqual((await self.repository.get_room_by_id(self.room.id, for_update=True)).id, self.room.id)
        self.assertIsNone(await self.repository.get_room_by_id(uuid4()))
        self.assertIsNone(await self.repository.get_rental_by_id(uuid4()))


if __name__ == "__main__":
    unittest.main()
