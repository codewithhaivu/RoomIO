from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.interior import Interior


class InteriorRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_interiors(self):
        result = await self.db.execute(
            select(Interior)
        )
        return result.scalars().all()