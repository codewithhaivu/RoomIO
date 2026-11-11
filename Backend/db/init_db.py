import asyncio
from core.config import engine
from db.base import Base
from models import account , amenitie, interior,landlord,location,rf_token,room, room_amenitie, room_image, room_interior,tenant
from models import appointment, notification, room_rental, conversation, message



async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


asyncio.run(init_db())

