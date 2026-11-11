from fastapi import APIRouter, Depends, status

from app.api.deps import get_room_save_service, get_current_account
from schemas.account import MessageResponse
from schemas.save_room import ListSavedRoomResponse

router = APIRouter(
    prefix="/saved-rooms",
    tags=["Saved Rooms"]
)

# Lưu phòng
@router.post(
    "/{room_id}",
    status_code=status.HTTP_201_CREATED,
    response_model=  MessageResponse
)
async def save_room(
    room_id : str ,
    id_account=Depends(get_current_account),
    service=Depends(get_room_save_service)
):
    return await service.save_room(id_account, room_id)


# Lấy danh sách phòng đã lưu
@router.get("/",
            response_model=ListSavedRoomResponse)
async def get_saved_rooms(
    id_account=Depends(get_current_account),
    service=Depends(get_room_save_service)
):
    return await service.get_saved_rooms(id_account)


# Bỏ lưu phòng
@router.delete(
    "/{room_id}" ,
    response_model=MessageResponse
)
async def delete_saved_room(
    room_id: str,
    id_account=Depends(get_current_account),
    service=Depends(get_room_save_service)
):
    return await service.delete_saved_room(id_account, room_id)