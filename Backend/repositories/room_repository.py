from sqlalchemy import select, func, literal
from sqlalchemy.ext.asyncio import AsyncSession
from models.amenitie import Amenity
from models.interior import Interior
from models.landlord import LandLord
from models.location import Location
from models.room import Room
from models.room_amenitie import RoomAmenity
from models.room_image import RoomImage
from models.room_interior import RoomInterior
from models.room_saved import RoomSaved
from models.tenant import Tenant


class RoomRepository:
    def __init__(self, db: AsyncSession):
        self.db = db


    async def flush(self):
        await self.db.flush()

    async def get_landlord_by_id_account(self, id_account):
        result = await self.db.execute(
            select(LandLord)
            .where(LandLord.account_id == id_account)
        )

        return result.scalar_one_or_none()

    async def post_room(self, name, area, water_fee, service_fee, parking_fee, electricity_fee, rental_price, status,
                        room_type, location_id, id_landlord):
        room = Room(
            name=name,
            area=area,
            water_fee=water_fee,
            service_fee=service_fee,
            parking_fee=parking_fee,
            electricity_fee=electricity_fee,
            rental_price=rental_price,
            status=status,
            room_type=room_type,
            location_id=location_id,
            landlord_id=id_landlord
        )
        self.db.add(room)
        await self.db.flush()
        return room

    async def get_location(self, name, longitude, latitude):
        result = await self.db.execute(
            select(Location).where(
                Location.name == name,
                Location.longitude == longitude,
                Location.latitude == latitude
            )
        )

        return result.scalar_one_or_none()

    async def create_location(self, name, longitude, latitude):
        location = Location(
            name=name,
            longitude=longitude,
            latitude=latitude ,
            type = 'address'
        )

        self.db.add(location)
        await self.db.flush()
        return location

    async def get_interiors_by_ids(self, interiors):
        result = await self.db.execute(
            select(Interior).where(Interior.id.in_(interiors))
        )

        return result.scalars().all()

    async def get_amenities_by_ids(self, amenities):
        result = await self.db.execute(
            select(Amenity).where(Amenity.id.in_(amenities))
        )

        return result.scalars().all()

    async def add_interiors_to_room(self, id_room, interiors):
        room_interiors = [
            RoomInterior(
                id_room=id_room,
                id_interior=interior_id
            )
            for interior_id in interiors
        ]

        self.db.add_all(room_interiors)

    async def add_amenities_to_room(self, id_room, amenities):
        room_amenities = [
            RoomAmenity(
                id_room=id_room,
                id_amenity=amenity_id
            )
            for amenity_id in amenities
        ]

        self.db.add_all(room_amenities)

    async def add_image_to_room(self, room_id, image_url, public_id, is_thumbnail):
        room_images = RoomImage(
            room_id=room_id,
            image_url=image_url,
            public_id=public_id,
            is_thumbnail=is_thumbnail
        )
        self.db.add(room_images)

    async def get_rooms_by_id_landlord(self, id_landlord):
        result = await self.db.execute(
            select(Room)
            .where(Room.landlord_id == id_landlord)
        )

        return result.scalars().all()

    async def get_images_by_room(self, id_room):
        result = await self.db.execute(
            select(RoomImage)
            .where(RoomImage.room_id == id_room)
        )

        return result.scalars().all()

    async def get_location_by_id(self, location_id):
        result = await self.db.execute(
            select(Location)
            .where(Location.id == location_id)
        )

        return result.scalar_one_or_none()

    async def get_interiors_by_room_id(self, room_id):
        stmt = (
            select(Interior)
            .join(
                RoomInterior,
                RoomInterior.id_interior == Interior.id
            )
            .where(RoomInterior.id_room == room_id)
        )

        result = await self.db.execute(stmt)

        return result.scalars().all()

    async def get_amenities_by_room_id(self, room_id):
        stmt = (
            select(Amenity)
            .join(
                RoomAmenity,
                RoomAmenity.id_amenity == Amenity.id
            )
            .where(RoomAmenity.id_room == room_id)
        )

        result = await self.db.execute(stmt)

        return result.scalars().all()

    async def get_room_by_id(self, room_id):
        result = await self.db.execute(
            select(Room)
            .where(Room.id == room_id)
        )
        return result.scalar_one_or_none()



    async def get_landlord_by_id(self, landlord_id):
        result = await self.db.execute(
            select(LandLord)
            .where(LandLord.id == landlord_id)
        )

        return result.scalar_one_or_none()

    async def getRoomByPositionDistance(
            self,
            latitude,
            longitude,
            radius ,
            tenant_id
    ):
        if tenant_id is not None:
            is_saved = (
                select(RoomSaved.id_room)
                .where(
                    RoomSaved.id_room == Room.id,
                    RoomSaved.id_tenant == tenant_id,
                    RoomSaved.status == "active"
                )
                .exists()
                .label("is_saved")
            )
        else:
            is_saved = literal(False).label("is_saved")
        distance = (
                func.ST_Distance_Sphere(
                    func.POINT(
                        longitude,
                        latitude
                    ),
                    func.POINT(
                        Location.longitude,
                        Location.latitude
                    )
                ) / 1000
        )

        query = (
            select(
                Room.id,
                Room.name,
                Room.area,
                Room.rental_price,
                Room.status,
                Room.room_type,
                RoomImage.image_url,
                Location.name.label("location_name"),
                distance.label("distance_km"),
                is_saved
            ).select_from(Room)
            .join(
                Location,
                Room.location_id == Location.id
            )
            .join(
                RoomImage ,
                Room.id == RoomImage.room_id
            )
            .where(
                RoomImage.is_thumbnail ==True,
                distance <= radius
            )
            .order_by(distance)
        )

        result = await self.db.execute(query)

        return result.all()

    async def get_location_by_area(self):
        result = await self.db.execute(
            select(Location)
            .where(Location.type=='area')
        )

        return result.scalars().all()

    async def get_tenant_by_id_account(self, id_account):
        result = await self.db.execute(
            select(Tenant)
            .where(Tenant.account_id == id_account)
        )

        return result.scalar_one_or_none()

