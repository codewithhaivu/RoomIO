from sqlalchemy import select, update, Select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from core.security import create_token, hash_token, get_password_hash
from models.account import Account
from models.rf_token import RefreshToken


class AccountRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_phone(self, phone_number: str):
        result = await self.db.execute(
            select(Account)
            .where(Account.phone_number == phone_number)
        )

        return result.scalar_one_or_none()
    async def get_token_by_id_account(self, account_id:str) :
        result = await self.db.execute(
            select(RefreshToken)
            .where(RefreshToken.account_id== account_id)
        )

        return result.scalar_one_or_none()

    async def create_refresh_token(self, account_id):
        token = create_token(account_id,"refresh_token")
        refresh_token = RefreshToken(
            token=hash_token(token),
            account_id=account_id,
        )
        self.db.add(refresh_token)

        await self.db.commit()
        await self.db.refresh(refresh_token)

        return token
    async def create_account(self,phone_number , password, role):
        new_account = Account(
            phone_number = phone_number ,
            password = get_password_hash(password) ,
            role = role  ,
            state = 'ok'
        )
        try:
            self.db.add(new_account)
            await self.db.commit()
            await self.db.refresh(new_account)
            return new_account

        except IntegrityError:
            await self.db.rollback()
            return None
    async def update_account(self,phone_number,password):
        account = await self.get_by_phone(phone_number)

        if account is None:
            return None

        account.password = get_password_hash(password)

        await self.db.commit()
        await self.db.refresh(account)

        return account

    async def get_rf_token_by_token(self,refresh_token):
        result = await self.db.execute(
            select(RefreshToken)
            .where(RefreshToken.token == hash_token(refresh_token))
        )
        return result.scalar_one_or_none()
    async def revoked_refresh_token(self, refresh_token):
        rf_token = await self.get_rf_token_by_token(refresh_token)
        if rf_token is None:
            return None
        rf_token.is_revoked =True
        await self.db.commit()

    async def revoke_all_refresh_tokens(self, account_id):
        await self.db.execute(
            update(RefreshToken)
            .where(RefreshToken.account_id == account_id)
            .values(is_revoked=True)
        )

        await self.db.commit()

    async def get_account_by_id(self, account_id):
        result  =await self.db.execute(
            Select(Account)
            .where(Account.id == account_id)
        )
        return result.scalar_one_or_none()