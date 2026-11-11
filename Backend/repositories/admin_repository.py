from collections.abc import Sequence
from dataclasses import dataclass, field
from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from models.account import Account
from models.amenitie import Amenity
from models.appointment import Appointment
from models.interior import Interior
from models.landlord import LandLord
from models.location import Location
from models.room import Room
from models.room_amenitie import RoomAmenity
from models.room_image import RoomImage
from models.room_interior import RoomInterior
from models.room_rental import RoomRental
from models.tenant import Tenant


@dataclass(frozen=True, slots=True)
class AdminUserRecord:
    account: Account
    full_name: str
    is_verify: bool | None


@dataclass(frozen=True, slots=True)
class AdminRoomRecord:
    room: Room
    location: Location
    interiors: list[Interior] = field(default_factory=list)
    amenities: list[Amenity] = field(default_factory=list)
    images: list[RoomImage] = field(default_factory=list)


class AdminRepository:

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_users(self, offset: int, limit: int) -> list[AdminUserRecord]:
        # Profile account_id is not unique in the current models. Aggregate it
        # before joining so duplicate profiles cannot duplicate paginated users.
        landlords = (
            select(
                LandLord.account_id,
                func.min(LandLord.full_name).label("full_name"),
                func.max(LandLord.is_verify).label("is_verify"),
            )
            .group_by(LandLord.account_id)
            .subquery()
        )
        tenants = (
            select(Tenant.account_id, func.min(Tenant.full_name).label("full_name"))
            .group_by(Tenant.account_id)
            .subquery()
        )
        statement = (
            select(
                Account,
                func.coalesce(landlords.c.full_name, tenants.c.full_name, ""),
                landlords.c.is_verify,
            )
            .outerjoin(landlords, landlords.c.account_id == Account.id)
            .outerjoin(tenants, tenants.c.account_id == Account.id)
            .order_by(Account.id)
            .offset(offset)
            .limit(limit)
        )
        try:
            result = await self.db.execute(statement)
            return [
                AdminUserRecord(account, full_name, is_verify)
                for account, full_name, is_verify in result.tuples()
            ]
        except Exception:
            await self.db.rollback()
            raise

    async def verify_landlord(self, id_account: UUID, is_verify: bool) -> UUID | None:
        try:
            result = await self.db.execute(
                select(LandLord)
                .where(LandLord.account_id == id_account).with_for_update()
            )
            landlord = result.scalar_one_or_none()
            if landlord is None:
                await self.db.rollback()
                return None

            landlord.is_verify = is_verify
            await self.db.commit()
            # Return the supplied ID without accessing an expired ORM instance.
            return id_account
        except Exception:
            await self.db.rollback()
            raise

    async def locked_user(self, id_user: UUID, state: str) -> UUID | None:
        try:
            result = await self.db.execute(
                select(Account).where(Account.id == id_user).with_for_update()
            )
            account = result.scalar_one_or_none()
            if account is None:
                await self.db.rollback()
                return None

            account.state = state
            await self.db.commit()
            return id_user
        except Exception:
            await self.db.rollback()
            raise

    async def get_rooms(
        self, id_landlord_account: UUID, offset: int, limit: int
    ) -> list[AdminRoomRecord]:
        try:
            result = await self.db.execute(
                select(Room, Location)
                .join(Location, Location.id == Room.location_id)
                .join(LandLord,LandLord.id == Room.landlord_id )
                .where(LandLord.account_id == id_landlord_account)
                .order_by(Room.id)
                .offset(offset)
                .limit(limit)
            )
            records = {
                room.id: AdminRoomRecord(room=room, location=location)
                for room, location in result.tuples()
            }
            if not records:
                return []

            room_ids = list(records)
            # Fetch each collection once for the whole page; never query per room
            # or join all collections into a multiplying Cartesian result.
            interiors = await self.db.execute(
                select(RoomInterior.id_room, Interior)
                .join(Interior, Interior.id == RoomInterior.id_interior)
                .where(RoomInterior.id_room.in_(room_ids))
                .order_by(RoomInterior.id_room, Interior.id)
            )
            for room_id, interior in interiors.tuples():
                records[room_id].interiors.append(interior)

            amenities = await self.db.execute(
                select(RoomAmenity.id_room, Amenity)
                .join(Amenity, Amenity.id == RoomAmenity.id_amenity)
                .where(RoomAmenity.id_room.in_(room_ids))
                .order_by(RoomAmenity.id_room, Amenity.id)
            )
            for room_id, amenity in amenities.tuples():
                records[room_id].amenities.append(amenity)

            images = await self.db.execute(
                select(RoomImage)
                .where(RoomImage.room_id.in_(room_ids))
                .order_by(RoomImage.room_id, RoomImage.id)
            )
            for image in images.scalars():
                records[image.room_id].images.append(image)

            return list(records.values())
        except Exception:
            await self.db.rollback()
            raise

    async def delete_rooms(self, room_ids: Sequence[UUID]) -> None:
        """Delete the entire batch atomically, or raise NoResultFound if incomplete."""
        try:
            result = await self.db.execute(
                select(Room.id)
                .where(Room.id.in_(room_ids))
                .order_by(Room.id)
                .with_for_update()
            )
            if set(result.scalars()) != set(room_ids):
                raise NoResultFound("One or more rooms do not exist")

            # The current foreign keys have no ON DELETE CASCADE. Remove every
            # dependent row before the rooms, within the same transaction.
            await self.db.execute(delete(RoomImage).where(RoomImage.room_id.in_(room_ids)))
            await self.db.execute(delete(RoomInterior).where(RoomInterior.id_room.in_(room_ids)))
            await self.db.execute(delete(RoomAmenity).where(RoomAmenity.id_room.in_(room_ids)))
            await self.db.execute(delete(Appointment).where(Appointment.id_room.in_(room_ids)))
            await self.db.execute(delete(RoomRental).where(RoomRental.id_room.in_(room_ids)))
            await self.db.execute(delete(Room).where(Room.id.in_(room_ids)))
            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise
