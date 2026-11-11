from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.amenitie import Amenity


class AmenityRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_amenities(self):
        result = await self.db.execute(
            select(Amenity)
        )
        return result.scalars().all()

