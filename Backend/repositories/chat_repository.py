from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from models.account import Account
from models.conversation import Conversation
from models.landlord import LandLord
from models.message import Message
from models.tenant import Tenant


class ChatRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_account_by_id(self, id_account, for_update=False):
        query = select(Account).where(Account.id == id_account)
        if for_update:
            query = query.with_for_update()

        result = await self.db.execute(query)

        return result.scalar_one_or_none()

    async def get_conversations(self, id_account):
        target_user_id = case(
            (Conversation.user1_id == id_account, Conversation.user2_id),
            else_=Conversation.user1_id
        )

        result = await self.db.execute(
            select(
                target_user_id.label("target_user_id"),
                func.coalesce(LandLord.full_name, Tenant.full_name, Account.phone_number).label("target_user_name"),
                func.coalesce(LandLord.avatar, Tenant.avatar, "").label("target_avatar_url"),
                Conversation.last_message,
                Conversation.updated_at
            )
            .select_from(Conversation)
            .join(Account, Account.id == target_user_id)
            .outerjoin(
                LandLord,
                and_(LandLord.account_id == Account.id, func.upper(Account.role) == "LANDLORD")
            )
            .outerjoin(
                Tenant,
                and_(Tenant.account_id == Account.id, func.upper(Account.role).in_(("CUSTOMER", "TENANT")))
            )
            .where(or_(Conversation.user1_id == id_account, Conversation.user2_id == id_account))
            .order_by(Conversation.updated_at.desc(), Conversation.id.desc())
        )

        return result.all()

    async def get_conversation(self, id_account, target_user_id, for_update=False):
        query = (
            select(Conversation)
            .where(
                or_(
                    and_(Conversation.user1_id == id_account, Conversation.user2_id == target_user_id),
                    and_(Conversation.user1_id == target_user_id, Conversation.user2_id == id_account)
                )
            )
        )
        if for_update:
            query = query.with_for_update()

        result = await self.db.execute(query)

        return result.scalar_one_or_none()

    async def create_conversation(self, user1_id, user2_id, last_message, updated_at):
        conversation = Conversation(
            user1_id=user1_id,
            user2_id=user2_id,
            last_message=last_message,
            updated_at=updated_at
        )

        self.db.add(conversation)
        await self.db.flush()
        return conversation

    async def get_messages(self, conversation_id):
        result = await self.db.execute(
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at, Message.id)
        )

        return result.scalars().all()

    async def create_message(self, conversation_id, sender_id, content, status, created_at):
        message = Message(
            conversation_id=conversation_id,
            sender_id=sender_id,
            content=content,
            status=status,
            created_at=created_at
        )

        self.db.add(message)
        await self.db.flush()
        return message

    async def update_conversation(self, conversation, last_message, updated_at):
        conversation.last_message = last_message
        conversation.updated_at = updated_at
        await self.db.flush()
        return conversation
