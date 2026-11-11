from fastapi import APIRouter, Depends, status

from app.api.deps import get_current_account, get_appointment_service
from schemas.account import MessageResponse
from schemas.appointment import AppointmentResponse, AppointmentRequest, ListAppointmentResponse

router = APIRouter(
    prefix="/appointments",
    tags=["Appointment"]
)


# dành cho khách thuê muốn lên lịch
# muốn gửi realtime khi chủ trọ onl , nếu offline thì lưu vào notifications
@router.post('/', response_model=AppointmentResponse,
             responses={
                 status.HTTP_400_BAD_REQUEST: {
                     "description": "Thời gian không hợp lệ",
                 },
                 status.HTTP_409_CONFLICT: {
                     "description": "Lịch hẹn bị trùng",
                 },
             })
async def send_appointment(request: AppointmentRequest,
                           id_account=Depends(get_current_account),
                           service=Depends(get_appointment_service)):
    return await service.send_appointment(request, id_account)


# cả 2 tác nhân đều có thể sử dụng endpoint này
@router.get('/', response_model=ListAppointmentResponse)
async def get_all_appointment(
        id_account=Depends(get_current_account),
        service=Depends(get_appointment_service)):
    return await service.get_all_appointment(id_account)


# dành cho chủ trọ xử lí yêu cầu hẹn lịch
# muốn gửi realtime khi khách thuê onl , nếu offline thì lưu vào notifications
@router.patch('/{appointment_id}/{status}', response_model=MessageResponse)
async def confirm_appointment(
        appointment_id: str,
        status: str,
        id_account=Depends(get_current_account),
        service=Depends(get_appointment_service)
):
    return await service.confirm_appointment(id_account, appointment_id, status)


# dành cho khách hàng muốn hủy cuộc hẹn
@router.delete('/{appointment_id}', response_model=MessageResponse)
async def destroy_appointment(
        appointment_id: str,
        id_account=Depends(get_current_account),
        service=Depends(get_appointment_service)
):
    return await service.destroy_appointment(id_account, appointment_id)


# dành cho khách hàng muốn thay đổi lịch hẹn
@router.patch('/{appointment_id}', response_model=MessageResponse,
              responses={
                  status.HTTP_400_BAD_REQUEST: {
                      "description": "Thời gian không hợp lệ",
                  },
                  status.HTTP_409_CONFLICT: {
                      "description": "Lịch hẹn bị trùng",
                  },
              })
async def update_appointment(
        appointment_id : str ,
        request: AppointmentRequest,
        id_account=Depends(get_current_account),
        service=Depends(get_appointment_service)
):
    return await service.update_appointment(id_account, request,appointment_id)
