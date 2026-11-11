from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.location import Location
from models.room import Room
from models.room_image import RoomImage
from models.room_saved import RoomSaved
from models.tenant import Tenant


class RoomSaveRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_tenant_by_id_account(self, id_account):
        result = await self.db.execute(
            select(Tenant)
            .where(Tenant.account_id == id_account)
        )

        return result.scalar_one_or_none()

    async def save_room(self, room_id, tenant_id):
        result = await self.db.execute(
            select(RoomSaved)
            .where(
                RoomSaved.id_room == room_id,
                RoomSaved.id_tenant == tenant_id,
            )
            .with_for_update()
        )
        save_room = result.scalar_one_or_none()
        if save_room is None:
            save_room = RoomSaved(id_room=room_id, id_tenant=tenant_id)
            self.db.add(save_room)
        else:
            # Soft-deleted rows keep their composite primary key.
            save_room.status = "active"
        await self.db.commit()
        await self.db.refresh(save_room)
        return save_room

    async def get_list_room(self, id_tenant):
        result = await self.db.execute(
            select(Room,RoomImage,Location.name)
            .join(RoomSaved ,
                  RoomSaved.id_room == Room.id)
            .join(RoomImage ,
                  RoomImage.room_id == Room.id)
            .join(Location ,
                  Location.id == Room.location_id)
            .where(RoomSaved.id_tenant == id_tenant , RoomSaved.status =='active' , RoomImage.is_thumbnail ==True)
        )

        return result.tuples().all()

    async def delete_saved_room(self, room_id, id_tenant):
        result = await self.db.execute(
            select(RoomSaved)
            .where(
                RoomSaved.id_tenant == id_tenant,
                RoomSaved.id_room == room_id
            )
        )

        save_room = result.scalar_one_or_none()

        if save_room is None:
            return None

        save_room.status = "inactive"

        await self.db.commit()
        return save_room
