from fastapi import APIRouter, Depends

from app.api.deps import get_current_account, get_notification_service
from schemas.account import MessageResponse
from schemas.notification import ListNotificationResponse

router = APIRouter(
    prefix="/notifications",
    tags=["Notification"]
)

# lấy các thông báo dành cho user hiện tại
@router.get('/' ,response_model=ListNotificationResponse)
async def get_notifications(
    page : int ,
    id_account=Depends(get_current_account),
    service=Depends(get_notification_service)
):
    return await service.get_notifications(page,id_account)

#Đánh dấu thông báo là đã đọc
@router.patch('/{notification_id}/read' ,response_model=MessageResponse)
async def read_notification(
    notification_id :str ,
    id_account=Depends(get_current_account),
    service=Depends(get_notification_service)
):
    return await service.read_notification(id_account,notification_id)
