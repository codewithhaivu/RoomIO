from fastapi import APIRouter, Depends

from app.api.deps import get_current_account, get_device_service
from schemas.account import MessageResponse
from schemas.device import RegisterDeviceResponse, RegisterDeviceRequest, UpdateDeviceRequest

router = APIRouter(
    prefix="/devices",
    tags=["User Device"]
)


@router.post('/', response_model=RegisterDeviceResponse)
async def register_device(
    request : RegisterDeviceRequest ,
    id_account=Depends(get_current_account),
    service= Depends(get_device_service)
):
    return await service.register_device(request ,id_account)

@router.patch('/{id_devices}', response_model=MessageResponse)
async def update_device(
    id_devices : str ,
    request : UpdateDeviceRequest ,
    id_account=Depends(get_current_account),
    service= Depends(get_device_service)
):
    return await service.update_device(request,id_devices ,id_account)

@router.delete('/{id_devices}', response_model=MessageResponse)
async def delete_device(
    id_devices : str ,
    id_account=Depends(get_current_account),
    service= Depends(get_device_service)
):
    return await service.delete_device(id_devices ,id_account)
