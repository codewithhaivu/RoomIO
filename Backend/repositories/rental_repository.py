from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models.account import Account
from models.landlord import LandLord
from models.location import Location
from models.room import Room
from models.room_image import RoomImage
from models.room_rental import RoomRental
from models.tenant import Tenant


class RentalRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_account_by_id(self, id_account):
        result = await self.db.execute(
            select(Account)
            .where(Account.id == id_account)
        )

        return result.scalar_one_or_none()

    async def get_landlord_by_id_account(self, id_account):
        result = await self.db.execute(
            select(LandLord)
            .where(LandLord.account_id == id_account)
        )

        return result.scalar_one_or_none()

    async def get_tenant_by_id_account(self, id_account):
        result = await self.db.execute(
            select(Tenant)
            .where(Tenant.account_id == id_account)
        )

        return result.scalar_one_or_none()

    async def get_room_by_id(self, room_id, for_update=False):
        query = select(Room).where(Room.id == room_id)
        if for_update:
            query = query.with_for_update()

        result = await self.db.execute(query)

        return result.scalar_one_or_none()

    async def get_active_rental(self, room_id, tenant_id):
        result = await self.db.execute(
            select(RoomRental)
            .where(
                RoomRental.id_room == room_id,
                RoomRental.id_tenant == tenant_id,
                RoomRental.status == "active"
            )
            .limit(1)
            .with_for_update()
        )

        return result.scalar_one_or_none()

    async def create_rental(self, room_id, tenant_id):
        rental = RoomRental(
            id_room=room_id,
            id_tenant=tenant_id,
            status="active"
        )

        self.db.add(rental)
        await self.db.flush()
        return rental

    async def get_rental_by_id(self, rental_relation_id):
        result = await self.db.execute(
            select(RoomRental)
            .where(RoomRental.id == rental_relation_id)
            .with_for_update()
        )

        return result.scalar_one_or_none()

    async def deactivate_rental(self, rental):
        rental.status = "deactivate"
        await self.db.flush()
        return rental

    async def get_current_tenants_for_landlord(self, landlord_id):
        result = await self.db.execute(
            select(
                RoomRental.id ,
                Tenant.id.label("tenant_id"),
                Tenant.full_name,
                Tenant.avatar.label("avatar_url"),
                Account.phone_number,
                Room.id.label("room_id"),
                Room.name.label("room_name"),
                RoomRental.rent_at.label("start_date"),
                RoomRental.status
            )
            .select_from(RoomRental)
            .join(Room, RoomRental.id_room == Room.id)
            .join(Tenant, RoomRental.id_tenant == Tenant.id)
            .join(Account, Tenant.account_id == Account.id)
            .where(
                Room.landlord_id == landlord_id,
                RoomRental.status == "active"
            )
            .order_by(RoomRental.rent_at.desc(), RoomRental.id)
        )

        return result.all()

    async def get_rented_rooms_for_tenant(self, tenant_id):
        # Gom ảnh thumbnail để mỗi quan hệ thuê chỉ xuất hiện một lần.
        thumbnails = (
            select(
                RoomImage.room_id,
                func.min(RoomImage.image_url).label("room_thumbnail")
            )
            .where(RoomImage.is_thumbnail.is_(True))
            .group_by(RoomImage.room_id)
            .subquery()
        )

        result = await self.db.execute(
            select(
                RoomRental.id.label("rental_id"),
                RoomRental.rent_at.label("start_date"),
                RoomRental.status,
                Room.id.label("room_id"),
                Room.name.label("room_name"),
                thumbnails.c.room_thumbnail,
                Location.name.label("address"),
                Room.rental_price.label("price")
            )
            .select_from(RoomRental)
            .join(Room, RoomRental.id_room == Room.id)
            .join(Location, Room.location_id == Location.id)
            .outerjoin(thumbnails, Room.id == thumbnails.c.room_id)
            .where(
                RoomRental.id_tenant == tenant_id,
                RoomRental.status == "active"
            )
            .order_by(RoomRental.rent_at.desc(), RoomRental.id)
        )

        return result.all()
