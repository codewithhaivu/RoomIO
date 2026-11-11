from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError, NoResultFound

from repositories.admin_repository import AdminRepository
from schemas.account import MessageResponse
from schemas.admin import (
    LandlordVerifyRequest,
    LandlordVerifyResponse,
    ListRoomRequest,
    ListUser,
    User,
    UserRequest,
)
from schemas.room import (
    AmenityResponse,
    Image,
    InteriorResponse,
    ListImageResponse,
    ListRoomResponse,
    Location,
    RoomResponse,
)


class AdminService:

    def __init__(self, repository: AdminRepository) -> None:
        self.repository = repository

    @staticmethod
    def _pagination_offset(page: int, limit: int) -> int:
        if page < 1 or not 1 <= limit <= 100:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="page phải >= 1 và limit phải nằm trong khoảng 1 đến 100",
            )
        return (page - 1) * limit

    async def get_users(self, page: int, limit: int) -> ListUser:
        offset = self._pagination_offset(page, limit)
        records = await self.repository.get_users(offset=offset, limit=limit)
        return ListUser(
            data=[
                User(
                    id_account=record.account.id,
                    phone_number=record.account.phone_number,
                    password=record.account.password,
                    full_name=record.full_name,
                    role=record.account.role,
                    state=record.account.state,
                    # The existing response schema requires str | None, not bool.
                    is_verify=(
                        str(record.is_verify).lower()
                        if record.is_verify is not None
                        else None
                    ),
                )
                for record in records
            ]
        )

    async def verify_landlord(
        self, request: LandlordVerifyRequest
    ) -> LandlordVerifyResponse:
        landlord_id_account = await self.repository.verify_landlord(
            request.id_account, is_verify=True
        )
        if landlord_id_account is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy chủ trọ",
            )
        return LandlordVerifyResponse(id_account=landlord_id_account, state="verified")

    async def locked_user(self, request: UserRequest) -> MessageResponse:
        account_id = await self.repository.locked_user(request.id_user, state="not ok")
        if account_id is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy tài khoản",
            )
        return MessageResponse(message="Khóa tài khoản thành công")

    async def get_rooms(
        self, page: int, limit: int, id_account: str
    ) -> ListRoomResponse:
        offset = self._pagination_offset(page, limit)
        try:
            account_id = UUID(id_account)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="accountId phải là UUID hợp lệ",
            ) from exc

        records = await self.repository.get_rooms(
            id_landlord_account=account_id, offset=offset, limit=limit
        )
        return ListRoomResponse(
            rooms=[
                RoomResponse(
                    id=record.room.id,
                    name=record.room.name,
                    area=record.room.area,
                    water_fee=record.room.water_fee,
                    service_fee=record.room.service_fee,
                    parking_fee=record.room.parking_fee,
                    rental_price=record.room.rental_price,
                    electricity_fee=record.room.electricity_fee,
                    status=record.room.status,
                    room_type=record.room.room_type,
                    location=Location(
                        name=record.location.name,
                        longitude=record.location.longitude,
                        latitude=record.location.latitude,
                    ),
                    interiors=[
                        InteriorResponse(id=item.id, name=item.name)
                        for item in record.interiors
                    ],
                    amenities=[
                        AmenityResponse(id=item.id, name=item.name)
                        for item in record.amenities
                    ],
                    image=ListImageResponse(
                        response=[
                            Image(
                                image_url=image.image_url,
                                public_id=image.public_id,
                                is_thumbnail=image.is_thumbnail,
                            )
                            for image in record.images
                        ]
                    ),
                )
                for record in records
            ]
        )

    async def delete_rooms(self, request: ListRoomRequest) -> MessageResponse:
        if not request.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Danh sách phòng cần xóa không được để trống",
            )
        room_ids = list(dict.fromkeys(request.data))
        try:
            await self.repository.delete_rooms(room_ids)
        except NoResultFound as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Một hoặc nhiều phòng cần xóa không tồn tại",
            ) from exc
        except IntegrityError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Không thể xóa phòng do ràng buộc dữ liệu liên quan",
            ) from exc
        return MessageResponse(message="Xóa phòng thành công")
