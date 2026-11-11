import asyncio

from core.config import AsyncSessionLocal
from models.amenitie import Amenity
from models.interior import Interior


async def seed_data():
    async with AsyncSessionLocal() as db:

        interiors = [
            Interior(name="Giường"),
            Interior(name="Đệm"),
            Interior(name="Tủ quần áo"),
            Interior(name="Bàn"),
            Interior(name="Ghế"),
            Interior(name="Điều hòa"),
            Interior(name="Tủ lạnh"),
            Interior(name="Bình nóng lạnh"),
            Interior(name="Kệ bếp"),
            Interior(name="Máy giặt"),
        ]

        amenities = [
            Amenity(name="Wifi"),
            Amenity(name="Chỗ để xe"),
            Amenity(name="Camera an ninh"),
            Amenity(name="Bảo vệ"),
            Amenity(name="Cổng vân tay"),
            Amenity(name="Giờ giấc tự do"),
            Amenity(name="Máy giặt chung"),
            Amenity(name="Sân thượng"),
            Amenity(name="Thang máy"),
            Amenity(name="Cho nuôi thú cưng"),
            Amenity(name="Không chung chủ"),
        ]

        db.add_all(interiors)
        db.add_all(amenities)

        await db.commit()


asyncio.run(seed_data())