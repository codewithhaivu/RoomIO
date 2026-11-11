from uuid import UUID

from fastapi import HTTPException

from repositories.device_repository import DeviceRepository
from schemas.account import MessageResponse
from schemas.device import RegisterDeviceRequest, RegisterDeviceResponse, UpdateDeviceRequest


class DeviceService:

    def __init__(self, repository: DeviceRepository):
        self.repository = repository

    async def register_device(self,request : RegisterDeviceRequest , id_account) -> RegisterDeviceResponse:
        account  =await self.repository.get_account_by_id(id_account)
        if account is None or account.state == 'not ok' :
            raise HTTPException(404 , 'not found account or account is locked')

        devices = await self.repository.register_device(request.fcm_token, request.platform,id_account)

        return RegisterDeviceResponse(
            id_device = str(devices.id)
        )

    async def update_device(self,request :UpdateDeviceRequest,id_devices,id_account) -> MessageResponse:
        id_devices =UUID(id_devices)
        account  =await self.repository.get_account_by_id(id_account)
        if account is None or account.state == 'not ok' :
            raise HTTPException(404 , 'not found account or account is locked')

        updated = await self.repository.update_device(request.fcm_token,id_devices,id_account)
        if not updated :
            raise HTTPException(404 , 'not found devices')
        return MessageResponse(
            message= "Update Successful"
        )

    async def delete_device(self,id_device,id_account) -> MessageResponse:
        id_device =UUID(id_device)
        deleted = await self.repository.delete_device(id_device,id_account)
        return MessageResponse(
            message= "Delete Successful"
        )