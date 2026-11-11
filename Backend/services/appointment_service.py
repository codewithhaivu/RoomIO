import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID
import traceback
from fastapi import HTTPException

from app.websocket.user import websocket_user
from repositories.appointment_repository import AppointmentRepository
from schemas.account import MessageResponse
from schemas.appointment import AppointmentRequest, AppointmentResponse, ListAppointmentResponse
from services.push_notification_service import PushNotificationService

logger = logging.getLogger(__name__)


class AppointmentService:

    def __init__(self, repository: AppointmentRepository ,firebase_service : PushNotificationService):
        self.repository = repository
        self.service = firebase_service

    def _normalize_meet_at(self, meet_at):
        # DateTime hiện tại không lưu timezone; dùng giờ Việt Nam cho lịch hẹn.
        local_timezone = timezone(timedelta(hours=7))
        if meet_at.tzinfo is not None:
            meet_at = meet_at.astimezone(local_timezone).replace(tzinfo=None)

        # MySQL DateTime hiện tại không khai báo độ chính xác phần thập phân.
        meet_at = meet_at.replace(microsecond=0)

        if meet_at <= datetime.now(local_timezone).replace(tzinfo=None):
            raise HTTPException(
                status_code=400,
                detail="Thời gian không hợp lệ"
            )

        return meet_at

    def _appointment_response(self, appointment, tenant, room):
        return AppointmentResponse(
            id_appointment=str(appointment.id),
            name_tenant=tenant.full_name,
            id_room=room.id,
            name_room=room.name,
            meet_at=appointment.meet_at,
            status=appointment.status
        )

    async def _get_appointment(self, appointment_id):
        try:
            appointment_id = UUID(str(appointment_id))
        except (ValueError, TypeError, AttributeError):
            raise HTTPException(
                status_code=400,
                detail="ID lịch hẹn không hợp lệ"
            )

        appointment = await self.repository.get_appointment_by_id(appointment_id)
        if appointment is None:
            raise HTTPException(
                status_code=404,
                detail="Không tìm thấy lịch hẹn"
            )

        return appointment

    async def _commit_and_notify(self, id_account, content, event, appointment, response):
        # Chỉ gửi realtime sau khi thay đổi lịch hẹn đã commit thành công.
        content = content[:500]
        websocket = websocket_user.connections.get(id_account)
        message = {
            "type": event,
            "content": content,
            "status": appointment.status,
            "data": response.model_dump(mode="json")
        }
        # Lưu lịch sử cho cả người nhận online và offline trong cùng transaction.
        await self.repository.create_notification(id_account, content)
        await self.repository.db.commit()

        if websocket is not None:
            try:
                await websocket.send_json(message)
            except Exception:
                # Người nhận có thể ngắt kết nối ngay sau lúc kiểm tra online.
                if websocket_user.connections.get(id_account) is websocket:
                    websocket_user.disconnect(id_account)
                logger.warning("Không gửi được thông báo lịch hẹn qua WebSocket", exc_info=True)

    async def _send_push_notification(self, id_account, title, body, appointment_id):
        try:
            await self.service.send_notification(
                id_account=id_account,
                title=title,
                body=body,
                data={"type": "appointment", "appointment_id": str(appointment_id)}
            )
        except Exception:
            # Lịch hẹn và lịch sử thông báo đã commit; chỉ ghi log lỗi Push.
            logger.exception("Không gửi được Push lịch hẹn tới tài khoản %s", id_account)

    async def send_appointment(self, request: AppointmentRequest, id_account: str) -> AppointmentResponse:
        meet_at = self._normalize_meet_at(request.meet_at)

        try:
            tenant = await self.repository.get_tenant_by_id_account(id_account)
            if tenant is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy khách thuê")

            room = await self.repository.get_room_by_id(request.id_room)
            if room is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy phòng")

            landlord = await self.repository.get_landlord_by_id(room.landlord_id)
            if landlord is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy chủ trọ")

            conflict = await self.repository.get_conflicting_appointment(room.id, tenant.id, meet_at)
            if conflict is not None:
                raise HTTPException(status_code=409, detail="Lịch hẹn bị trùng")

            appointment = await self.repository.create_appointment(room.id, tenant.id, meet_at)
            response = self._appointment_response(appointment, tenant, room)
            content = (
                f"{tenant.full_name} yêu cầu hẹn xem phòng {room.name} "
                f"vào {meet_at:%d/%m/%Y %H:%M:%S}."
            )
            await self._commit_and_notify(
                landlord.account_id, content, "appointment_created", appointment, response
            )
            await self._send_push_notification(
                landlord.account_id,
                "Yêu cầu xem phòng mới",
                "Bạn vừa nhận được một yêu cầu đặt lịch xem phòng.",
                response.id_appointment
            )
            return response
        except HTTPException:
            await self.repository.db.rollback()
            raise
        except Exception:
            await self.repository.db.rollback()
            traceback.print_exc()
            raise HTTPException(status_code=500, detail="Failed to send appointment")

    async def confirm_appointment(self, id_account: str, appointment_id: str, status: str) -> MessageResponse:
        status = status.upper()
        if status not in ("CONFIRMED", "REJECTED", "COMPLETED"):
            raise HTTPException(status_code=400, detail="Trạng thái lịch hẹn không hợp lệ")

        try:
            appointment = await self._get_appointment(appointment_id)
            room = await self.repository.get_room_by_id(appointment.id_room)
            if room is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy phòng")

            landlord = await self.repository.get_landlord_by_id(room.landlord_id)
            if landlord is None or str(landlord.account_id) != str(id_account):
                raise HTTPException(status_code=404, detail="Không tìm thấy lịch hẹn của chủ trọ")

            tenant = await self.repository.get_tenant_by_id(appointment.id_tenant)
            if tenant is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy khách thuê")

            required_status = "CONFIRMED" if status == "COMPLETED" else "PENDING"
            if appointment.status != required_status:
                raise HTTPException(status_code=409, detail="Không thể thay đổi trạng thái lịch hẹn")

            if status == "CONFIRMED":
                self._normalize_meet_at(appointment.meet_at)
                conflict = await self.repository.get_conflicting_appointment(
                    room.id, tenant.id, appointment.meet_at, appointment.id
                )
                if conflict is not None:
                    raise HTTPException(status_code=409, detail="Lịch hẹn bị trùng")

            if status == "COMPLETED":
                now = datetime.now(timezone(timedelta(hours=7))).replace(tzinfo=None)
                if appointment.meet_at > now:
                    raise HTTPException(status_code=400, detail="Lịch hẹn chưa diễn ra")

            appointment.status = status
            response = self._appointment_response(appointment, tenant, room)
            content = (
                f"Lịch hẹn xem phòng {room.name} vào {appointment.meet_at:%d/%m/%Y %H:%M:%S} "
                f"đã được cập nhật thành {status}."
            )
            await self._commit_and_notify(
                tenant.account_id, content, "appointment_status_updated", appointment, response
            )
            if status == "CONFIRMED":
                await self._send_push_notification(
                    tenant.account_id,
                    "Lịch hẹn đã được xác nhận",
                    "Chủ trọ đã xác nhận lịch hẹn xem phòng của bạn.",
                    response.id_appointment
                )
            return MessageResponse(message="Cập nhật trạng thái lịch hẹn thành công")
        except HTTPException:
            await self.repository.db.rollback()
            raise
        except Exception:
            await self.repository.db.rollback()
            raise HTTPException(status_code=500, detail="Failed to confirm appointment")

    async def get_all_appointment(self, id_account: str) -> ListAppointmentResponse:
        appointments = await self.repository.get_appointments_by_id_account(id_account)

        return ListAppointmentResponse(
            data=[
                AppointmentResponse(
                    id_appointment=str(appointment.id_appointment),
                    name_tenant=appointment.name_tenant,
                    id_room=appointment.id_room,
                    name_room=appointment.name_room,
                    meet_at=appointment.meet_at ,
                    status=appointment.status
                )
                for appointment in appointments
            ]
        )

    async def destroy_appointment(self, id_account: str, appointment_id: str) -> MessageResponse:
        try:
            tenant = await self.repository.get_tenant_by_id_account(id_account)
            if tenant is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy khách thuê")

            appointment = await self._get_appointment(appointment_id)
            if appointment.id_tenant != tenant.id:
                raise HTTPException(status_code=404, detail="Không tìm thấy lịch hẹn của khách thuê")
            if appointment.status not in ("PENDING", "CONFIRMED"):
                raise HTTPException(status_code=409, detail="Không thể hủy lịch hẹn")

            room = await self.repository.get_room_by_id(appointment.id_room)
            if room is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy phòng")
            landlord = await self.repository.get_landlord_by_id(room.landlord_id)
            if landlord is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy chủ trọ")

            appointment.status = "CANCELLED"
            response = self._appointment_response(appointment, tenant, room)
            content = (
                f"{tenant.full_name} đã hủy lịch hẹn xem phòng {room.name} "
                f"vào {appointment.meet_at:%d/%m/%Y %H:%M:%S}."
            )
            await self._commit_and_notify(
                landlord.account_id, content, "appointment_cancelled", appointment, response
            )
            return MessageResponse(message="Hủy lịch hẹn thành công")
        except HTTPException:
            await self.repository.db.rollback()
            raise
        except Exception:
            await self.repository.db.rollback()
            raise HTTPException(status_code=500, detail="Failed to cancel appointment")

    async def update_appointment(
            self, id_account: str, request: AppointmentRequest, appointment_id: str
    ) -> MessageResponse:
        meet_at = self._normalize_meet_at(request.meet_at)

        try:
            tenant = await self.repository.get_tenant_by_id_account(id_account)
            if tenant is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy khách thuê")

            appointment = await self._get_appointment(appointment_id)
            if appointment.id_tenant != tenant.id:
                raise HTTPException(status_code=404, detail="Không tìm thấy lịch hẹn của khách thuê")
            if appointment.status not in ("PENDING", "CONFIRMED"):
                raise HTTPException(status_code=409, detail="Không thể thay đổi lịch hẹn")
            if request.id_room != appointment.id_room:
                raise HTTPException(status_code=400, detail="Không thể thay đổi phòng của lịch hẹn")

            room = await self.repository.get_room_by_id(appointment.id_room)
            if room is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy phòng")
            landlord = await self.repository.get_landlord_by_id(room.landlord_id)
            if landlord is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy chủ trọ")

            conflict = await self.repository.get_conflicting_appointment(
                room.id, tenant.id, meet_at, appointment.id
            )
            if conflict is not None:
                raise HTTPException(status_code=409, detail="Lịch hẹn bị trùng")

            appointment.meet_at = meet_at
            appointment.status = "PENDING"
            response = self._appointment_response(appointment, tenant, room)
            content = (
                f"{tenant.full_name} đổi lịch hẹn xem phòng {room.name} "
                f"sang {meet_at:%d/%m/%Y %H:%M:%S}, đang chờ xác nhận."
            )
            await self._commit_and_notify(
                landlord.account_id, content, "appointment_updated", appointment, response
            )
            return MessageResponse(message="Thay đổi lịch hẹn thành công")
        except HTTPException:
            await self.repository.db.rollback()
            raise
        except Exception:
            await self.repository.db.rollback()
            raise HTTPException(status_code=500, detail="Failed to update appointment")
