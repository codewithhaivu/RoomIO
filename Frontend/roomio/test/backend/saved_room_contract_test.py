"""Saved-room API contract checks without connecting to the database.

Run with the Backend virtualenv's Python; backend location is relative to workspace.
"""
import ast
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import AsyncMock, Mock
from uuid import uuid4

BACKEND = Path(__file__).resolve().parents[4] / 'Backend'
sys.path.insert(0, str(BACKEND))
from fastapi import HTTPException
from models.room_saved import RoomSaved
from repositories.room_save_repository import RoomSaveRepository
from schemas.account import MessageResponse
from services.room_save_service import RoomSaveService


class SavedRoomContractTests(unittest.IsolatedAsyncioTestCase):
    async def test_delete_route_returns_service_response(self):
        source = ast.parse((BACKEND / 'app/api/v1/room_saved.py').read_text(encoding='utf-8'))
        endpoint = next(node for node in source.body if isinstance(node, ast.AsyncFunctionDef) and node.name == 'delete_saved_room')
        endpoint.decorator_list = []
        endpoint.args.defaults = []
        namespace = {}
        exec(compile(ast.fix_missing_locations(ast.Module(body=[endpoint], type_ignores=[])), '<saved-room-route>', 'exec'), namespace)
        message = MessageResponse(message='Successful')
        service = SimpleNamespace(delete_saved_room=AsyncMock(return_value=message))
        result = await namespace['delete_saved_room']('room', 'account', service)
        self.assertIs(result, message)
        self.assertEqual(MessageResponse.model_validate(result).message, 'Successful')

    async def test_saved_list_preserves_all_selected_columns(self):
        rows = [(SimpleNamespace(id=uuid4()), SimpleNamespace(image_url=''), 'Thủ Đức')]
        result = Mock()
        result.tuples.return_value.all.return_value = rows
        result.scalars.side_effect = AssertionError('GET must preserve room, image and location')
        repository = RoomSaveRepository(SimpleNamespace(execute=AsyncMock(return_value=result)))
        self.assertEqual(await repository.get_list_room(uuid4()), rows)

    async def test_get_service_maps_repository_tuples_into_response(self):
        room_id = uuid4()
        room = SimpleNamespace(id=room_id, name='Room', area=25, rental_price=4000000,
                               status='AVAILABLE', room_type='STUDIO')
        repository = SimpleNamespace(
            get_tenant_by_id_account=AsyncMock(return_value=SimpleNamespace(id=uuid4())),
            get_list_room=AsyncMock(return_value=[(room, SimpleNamespace(image_url=''), 'Thủ Đức')]),
        )
        response = await RoomSaveService(repository).get_saved_rooms(uuid4())
        self.assertEqual(response.rooms[0].id, room_id)
        self.assertEqual(response.rooms[0].location_name, 'Thủ Đức')

    async def test_save_reactivates_inactive_record_without_duplicate_primary_key(self):
        existing = RoomSaved(id_room=uuid4(), id_tenant=uuid4(), status='inactive')
        result = Mock()
        result.scalar_one_or_none.return_value = existing
        db = SimpleNamespace(execute=AsyncMock(return_value=result), add=Mock(),
                             commit=AsyncMock(), refresh=AsyncMock())
        saved = await RoomSaveRepository(db).save_room(existing.id_room, existing.id_tenant)
        self.assertIs(saved, existing)
        self.assertEqual(saved.status, 'active')
        db.add.assert_not_called()
        db.commit.assert_awaited_once()

    async def test_new_save_inserts_one_record(self):
        result = Mock()
        result.scalar_one_or_none.return_value = None
        db = SimpleNamespace(execute=AsyncMock(return_value=result), add=Mock(),
                             commit=AsyncMock(), refresh=AsyncMock())
        room_id, tenant_id = uuid4(), uuid4()
        saved = await RoomSaveRepository(db).save_room(room_id, tenant_id)
        self.assertEqual((saved.id_room, saved.id_tenant), (room_id, tenant_id))
        db.add.assert_called_once_with(saved)

    async def test_delete_converts_path_id_to_uuid_before_query(self):
        room_id, tenant_id = uuid4(), uuid4()
        repository = SimpleNamespace(
            get_tenant_by_id_account=AsyncMock(return_value=SimpleNamespace(id=tenant_id)),
            delete_saved_room=AsyncMock(return_value=object()),
        )
        response = await RoomSaveService(repository).delete_saved_room(uuid4(), str(room_id))
        self.assertEqual(response.message, 'Successful')
        repository.delete_saved_room.assert_awaited_once_with(room_id, tenant_id)

    async def test_missing_saved_room_is_404_not_authentication_failure(self):
        repository = SimpleNamespace(
            get_tenant_by_id_account=AsyncMock(return_value=SimpleNamespace(id=uuid4())),
            delete_saved_room=AsyncMock(return_value=None),
        )
        with self.assertRaises(HTTPException) as error:
            await RoomSaveService(repository).delete_saved_room(uuid4(), str(uuid4()))
        self.assertEqual(error.exception.status_code, 404)

    async def test_missing_tenant_raises_fastapi_exception(self):
        repository = SimpleNamespace(get_tenant_by_id_account=AsyncMock(return_value=None))
        with self.assertRaises(HTTPException) as error:
            await RoomSaveService(repository).get_saved_rooms(uuid4())
        self.assertEqual(error.exception.status_code, 404)


if __name__ == '__main__':
    unittest.main()
