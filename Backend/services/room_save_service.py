from fastapi import HTTPException
from uuid import UUID

from repositories.room_save_repository import RoomSaveRepository
from schemas.account import MessageResponse
from schemas.save_room import ListSavedRoomResponse ,RoomResponse


class RoomSaveService:
    def __init__(self, repository: RoomSaveRepository):
        self.repository = repository

    async def save_room(self,id_account ,room_id ) -> MessageResponse:
        room_id = UUID(room_id)
        tenant = await self.repository.get_tenant_by_id_account(id_account)
        if tenant is None :
            raise HTTPException(404, 'Not found user')
        await self.repository.save_room(room_id,tenant.id)
        return MessageResponse(
            message= "Successful"
        )

    async def get_saved_rooms(self,id_account) -> ListSavedRoomResponse:
        tenant = await self.repository.get_tenant_by_id_account(id_account)
        if tenant is None :
            raise HTTPException(404, 'Not found user')

        rooms = await self.repository.get_list_room(tenant.id)

        data =[
            RoomResponse(
                id = room.id,
                name =room.name ,
                area= room.area ,
                rental_price =room.rental_price ,
                status = room.status,
                room_type = room.room_type ,
                location_name  =location_name ,
                image_url = room_image.image_url
            )
            for room ,room_image, location_name in rooms
        ]
        return ListSavedRoomResponse(
            rooms = data
        )

    async def delete_saved_room(self,id_account ,room_id )-> MessageResponse:
        room_id = UUID(room_id)
        tenant = await self.repository.get_tenant_by_id_account(id_account)
        if tenant is None :
            raise HTTPException(404, 'Not found user')

        result = await self.repository.delete_saved_room(room_id,tenant.id)

        if result is None :
            raise HTTPException(404,'Room save is not found')
        return MessageResponse(
            message="Successful"
        )