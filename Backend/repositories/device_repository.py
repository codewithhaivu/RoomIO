from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession

from models.account import Account
from models.user_device import UserDevice


class DeviceRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_account_by_id(self, id_account):
        result  =await self.db.execute(
            select(Account)
            .where(Account.id == id_account)
        )
        return result.scalar_one_or_none()

    async def register_device(self, fcm_token, platform, id_account):
        device = UserDevice(
            fcm_token =fcm_token ,
            platform =  platform ,
            account_id = id_account
        )
        self.db.add(device)
        await self.db.commit()
        await self.db.refresh(device)
        return device

    async def update_device(self, fcm_token, id_devices, id_account):
        result = await self.db.execute(
            update(UserDevice)
            .where(
                UserDevice.id == id_devices,
                UserDevice.account_id == id_account
            )
            .values(fcm_token=fcm_token)
        )

        await self.db.commit()
        return result.rowcount > 0
    async def delete_device(self, id_device, id_account):
        result  = await self.db.execute(
            delete(UserDevice)
            .where(
                UserDevice.id == id_device,
                UserDevice.account_id == id_account
            )
        )

        await self.db.commit()

    async def get_devices_by_account(self, id_account):
        result = await self.db.execute(
            select(UserDevice)
            .where(UserDevice.account_id == id_account)
        )
        return result.scalars().all()