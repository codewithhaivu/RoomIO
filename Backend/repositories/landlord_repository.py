from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.landlord import LandLord


class LandlordRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_profile_by_id_account(self, id_account):
        result = await self.db.execute(
            select(LandLord)
            .where(LandLord.account_id == id_account)
        )

        return result.scalar_one_or_none()

    async def create_profile(self,fullname,gender ,avatar ,description, id_account):
        result = await self.get_profile_by_id_account(id_account)
        if result is not None :
            return None # Kiểm tra xem profile đã từng được tạo hay chưa
        landlord = LandLord(
            full_name = fullname ,
            gender = gender,
            avatar = avatar ,
            description = description ,
            account_id = id_account
        )
        self.db.add(landlord)

        await self.db.commit()
        await self.db.refresh(landlord)

        return landlord

    async def update_profile(self, fullName, gender, avatar, description, id_account):
            profile = await self.get_profile_by_id_account(id_account)

            if profile is None:
                return None

            if fullName is not None:
                profile.full_name = fullName

            if gender is not None:
                profile.gender = gender

            if avatar is not None:
                profile.avatar = avatar

            if description is not None:
                profile.description = description

            await self.db.commit()
            await self.db.refresh(profile)

            return profile