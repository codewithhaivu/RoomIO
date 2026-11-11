from fastapi import APIRouter, Depends, Query

from app.api.deps import  get_admin_service
from schemas.account import MessageResponse
from schemas.admin import ListUser, LandlordVerifyRequest, LandlordVerifyResponse, UserRequest, ListRoomRequest
from schemas.room import ListRoomResponse

router = APIRouter(
    prefix="/admin",
    tags=["Admin"]
)


# Lấy ra toàn bộ user trong ứng dụng, có kèm phân trang,
@router.get('/members', response_model=ListUser)
async def get_users(
    page: int = Query(1, ge=1, description="Trang hiện tại (bắt đầu từ 1)"),
    limit: int = Query(10, ge=1, le=100, description="Số lượng record trên mỗi trang (tối đa 100)"),
    service = Depends(get_admin_service)
):
    return await service.get_users(page=page, limit=limit)


# verify cho landlord để có thể dùng mọi chức năng ( is_verify = True )
@router.patch('/verify-landlord' ,response_model=LandlordVerifyResponse)
async def verify_landlord(
    request :LandlordVerifyRequest ,
    service = Depends(get_admin_service)
) :
    return await service.verify_landlord(request)

# Khoá tài khoản của 1 user nào đó ( Chuyển state về not ok)
@router.patch('/locked-user' ,response_model =MessageResponse)
async def locked_user(
    request :UserRequest ,
    service = Depends(get_admin_service)
) :
    return await service.locked_user(request)


# Lấy ra toàn bộ phòng của 1 landlord nào đó
@router.get('/rooms/{id_account}', response_model=ListRoomResponse)
async def get_rooms(
    id_account : str  ,
    page: int = Query(1, ge=1, description="Trang hiện tại (bắt đầu từ 1)"),
    limit: int = Query(10, ge=1, le=100, description="Số lượng record trên mỗi trang (tối đa 100)"),
    service = Depends(get_admin_service)
):
    return await service.get_rooms(page, limit,id_account)

#Xoá bài đăng  nào đó
@router.delete('/rooms', response_model=MessageResponse)
async def delete_rooms(
    request : ListRoomRequest ,
    service = Depends(get_admin_service)
):
    return await service.delete_rooms(request)