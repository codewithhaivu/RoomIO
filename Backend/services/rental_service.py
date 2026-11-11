import json
import secrets
from uuid import UUID

from fastapi import HTTPException
from redis.exceptions import RedisError

from core.redis_custom import redis_client
from repositories.rental_repository import RentalRepository
from schemas.account import MessageResponse
from schemas.rental import (
    RentalResponse, RentalVerifyRequest, RentalVerifyResponse, CurrentTenantsResponse,
    TenantRentalResponse, MyRentedRoomsResponse, RentalRoomResponse
)


class RentalService:
    def __init__(self, repository: RentalRepository):
        self.repository = repository

    def _parse_uuid(self, value):
        try:
            return UUID(str(value))
        except (ValueError, TypeError, AttributeError):
            raise HTTPException(status_code=400, detail="ID không hợp lệ")

    async def _get_landlord(self, id_account):
        account = await self.repository.get_account_by_id(id_account)
        if account is None:
            raise HTTPException(status_code=401, detail="Tài khoản không tồn tại")
        if account.role.upper() != "LANDLORD":
            raise HTTPException(status_code=403, detail="Chỉ chủ trọ được thực hiện thao tác này")

        landlord = await self.repository.get_landlord_by_id_account(id_account)
        if landlord is None:
            raise HTTPException(status_code=404, detail="Không tìm thấy hồ sơ chủ trọ")

        return landlord

    async def _get_tenant(self, id_account):
        account = await self.repository.get_account_by_id(id_account)
        if account is None:
            raise HTTPException(status_code=401, detail="Tài khoản không tồn tại")
        if account.role.upper() != "CUSTOMER":
            raise HTTPException(status_code=403, detail="Chỉ khách thuê được thực hiện thao tác này")

        tenant = await self.repository.get_tenant_by_id_account(id_account)
        if tenant is None:
            raise HTTPException(status_code=404, detail="Không tìm thấy hồ sơ khách thuê")

        return tenant

    async def create_qr_code(self, room_id: str, id_account: str) -> RentalResponse:
        room_id = self._parse_uuid(room_id)
        landlord = await self._get_landlord(id_account)
        room = await self.repository.get_room_by_id(room_id)
        if room is None:
            raise HTTPException(status_code=404, detail="Không tìm thấy phòng")
        if room.landlord_id != landlord.id:
            raise HTTPException(status_code=403, detail="Không có quyền tạo mã cho phòng này")

        payload = json.dumps({"room_id": str(room.id), "landlord_id": str(landlord.id)})
        try:
            for _ in range(10):
                token = str(secrets.randbelow(1000000)).zfill(6)
                # NX tránh ghi đè mã của phòng khác khi sinh ngẫu nhiên bị trùng.
                created = await redis_client.client.set(
                    f"rental:qr:{token}", payload, ex=60, nx=True
                )
                if created:
                    print(token)
                    return RentalResponse(qr_token=token, expires_in_second=60)
        except RedisError:
            raise HTTPException(status_code=503, detail="Dịch vụ mã thuê phòng tạm thời không khả dụng")

        raise HTTPException(status_code=503, detail="Không thể tạo mã thuê phòng, vui lòng thử lại")

    async def verify_qr_code(self, request: RentalVerifyRequest, id_account: str) -> RentalVerifyResponse:
        token = request.token
        if len(token) != 6 or not token.isascii() or not token.isdigit():
            raise HTTPException(status_code=400, detail="Mã thuê phòng phải gồm 6 chữ số")

        try:
            tenant = await self._get_tenant(id_account)
            # GETDEL đọc và xóa nguyên tử: chỉ một request có thể sử dụng mã.
            payload = await redis_client.client.getdel(f"rental:qr:{token}")
            if payload is None:
                raise HTTPException(status_code=400, detail="Mã thuê phòng sai, đã hết hạn hoặc đã sử dụng")

            try:
                data = json.loads(payload)
                room_id = self._parse_uuid(data["room_id"])
                landlord_id = self._parse_uuid(data["landlord_id"])
            except (ValueError, TypeError, KeyError):
                raise HTTPException(status_code=400, detail="Mã thuê phòng không hợp lệ")

            room = await self.repository.get_room_by_id(room_id, for_update=True)
            if room is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy phòng")
            if room.landlord_id != landlord_id:
                raise HTTPException(status_code=400, detail="Mã thuê phòng không còn hợp lệ")

            rental = await self.repository.get_active_rental(room.id, tenant.id)
            if rental is not None:
                raise HTTPException(status_code=409, detail="Khách thuê đã có quan hệ thuê đang hoạt động với phòng này")

            await self.repository.create_rental(room.id, tenant.id)
            await self.repository.db.commit()
            return RentalVerifyResponse(message="Xác nhận thuê phòng thành công", id_valid=True)
        except HTTPException:
            await self.repository.db.rollback()
            raise
        except RedisError:
            await self.repository.db.rollback()
            raise HTTPException(status_code=503, detail="Dịch vụ mã thuê phòng tạm thời không khả dụng")
        except Exception:
            await self.repository.db.rollback()
            raise HTTPException(status_code=500, detail="Failed to verify rental code")

    async def destroy_relation(self, rental_relation_id: str, id_account: str) -> MessageResponse:
        rental_relation_id = self._parse_uuid(rental_relation_id)
        try:
            landlord = await self._get_landlord(id_account)
            rental = await self.repository.get_rental_by_id(rental_relation_id)
            if rental is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy quan hệ thuê phòng")

            room = await self.repository.get_room_by_id(rental.id_room)
            if room is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy phòng")
            if room.landlord_id != landlord.id:
                raise HTTPException(status_code=403, detail="Không có quyền hủy quan hệ thuê phòng này")
            if rental.status != "active":
                raise HTTPException(status_code=409, detail="Quan hệ thuê phòng đã ngừng hoạt động")

            await self.repository.deactivate_rental(rental)
            await self.repository.db.commit()
            return MessageResponse(message="Hủy quan hệ thuê phòng thành công")
        except HTTPException:
            await self.repository.db.rollback()
            raise
        except Exception:
            await self.repository.db.rollback()
            raise HTTPException(status_code=500, detail="Failed to deactivate rental relation")

    async def get_current_tenants_for_landlord(self, id_account: str) -> CurrentTenantsResponse:
        landlord = await self._get_landlord(id_account)
        rentals = await self.repository.get_current_tenants_for_landlord(landlord.id)

        return CurrentTenantsResponse(
            data=[
                TenantRentalResponse(
                    rental_id=rental.id ,
                    tenant_id=rental.tenant_id,
                    full_name=rental.full_name,
                    avatar_url=rental.avatar_url or "",
                    phone_number=rental.phone_number,
                    room_id=rental.room_id,
                    room_name=rental.room_name,
                    start_date=rental.start_date,
                    status=rental.status
                )
                for rental in rentals
            ]
        )

    async def get_rented_rooms_for_tenant(self, id_account: str) -> MyRentedRoomsResponse:
        tenant = await self._get_tenant(id_account)
        rentals = await self.repository.get_rented_rooms_for_tenant(tenant.id)

        return MyRentedRoomsResponse(
            data=[
                RentalRoomResponse(
                    rental_id=rental.rental_id,
                    start_date=rental.start_date,
                    status=rental.status,
                    room_id=rental.room_id,
                    room_name=rental.room_name,
                    room_thumbnail=rental.room_thumbnail or "",
                    address=rental.address,
                    price=rental.price
                )
                for rental in rentals
            ]
        )
