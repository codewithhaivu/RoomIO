from fastapi import APIRouter, Depends

from app.api.deps import get_rental_service, get_current_account
from schemas.account import MessageResponse
from schemas.rental import RentalResponse, RentalVerifyResponse, RentalVerifyRequest, CurrentTenantsResponse, \
    MyRentedRoomsResponse

router = APIRouter(
    prefix="/rentals",
    tags=["Rental"]
)

# chủ trọ tạo mã qr để khách thuê quét mục đích tạo mối quan hệ giữa phòng trọ và người thuê
# Sử dụng redis để taọ chuỗi gồm 6 số gửi cho khách thuê , mã chỉ dùng 1 lần , thời gian tồn tại là 60s
@router.post('/{room_id}/qr-code',response_model=RentalResponse)
async def create_qr_code(
    room_id : str ,
    service =Depends(get_rental_service),
    id_account = Depends(get_current_account)
):
    return await service.create_qr_code(room_id,id_account)

# khách thuê gửi token lên nhằm xác nhận mối quan hệ giữa chủ trọ và khách thuê
@router.post('/qr-code/verify',response_model=RentalVerifyResponse)
async def verify_qr_code(
    request : RentalVerifyRequest,
    service =Depends(get_rental_service),
    id_account = Depends(get_current_account)
):
    return await service.verify_qr_code(request,id_account)

# Chủ trọ hủy quan hệ thuê với khách đang thuê phòng ( set status thành deactivate)
@router.delete('/{rental_relation_id}',response_model=MessageResponse)
async def destroy_relation(
    rental_relation_id : str ,
    service =Depends(get_rental_service),
    id_account = Depends(get_current_account)
):
    return await service.destroy_relation(rental_relation_id,id_account)

#Chủ trọ lấy ra danh sách những người đang thuê trọ ( status =active )
@router.get('/',response_model=CurrentTenantsResponse)
async def get_my_tenants(
    service =Depends(get_rental_service),
    id_account = Depends(get_current_account)
):
    return await service.get_current_tenants_for_landlord(id_account)


# Khách thuê lấy danh sách những phòng trọ mình ĐANG thuê (status = active)
@router.get('/my-rooms', response_model=MyRentedRoomsResponse)
async def get_my_rented_rooms(
    service = Depends(get_rental_service),
    id_account = Depends(get_current_account)
):
    return await service.get_rented_rooms_for_tenant(id_account)
