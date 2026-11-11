from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from models.appointment import Appointment
from models.landlord import LandLord
from models.notification import Notification
from models.room import Room
from models.tenant import Tenant


class AppointmentRepository:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_tenant_by_id_account(self, id_account):
        result = await self.db.execute(
            select(Tenant)
            .where(Tenant.account_id == id_account)
            .with_for_update()
        )

        return result.scalar_one_or_none()

    async def get_tenant_by_id(self, id_tenant):
        result = await self.db.execute(
            select(Tenant)
            .where(Tenant.id == id_tenant)
        )

        return result.scalar_one_or_none()

    async def get_room_by_id(self, id_room):
        result = await self.db.execute(
            select(Room)
            .where(Room.id == id_room)
            .with_for_update()
        )

        return result.scalar_one_or_none()

    async def get_landlord_by_id(self, id_landlord):
        result = await self.db.execute(
            select(LandLord)
            .where(LandLord.id == id_landlord)
        )

        return result.scalar_one_or_none()

    async def get_appointment_by_id(self, appointment_id):
        result = await self.db.execute(
            select(Appointment)
            .where(Appointment.id == appointment_id)
            .with_for_update()
        )

        return result.scalar_one_or_none()

    async def get_conflicting_appointment(self, id_room, id_tenant, meet_at, appointment_id=None):
        query = (
            select(Appointment)
            .where(
                or_(Appointment.id_room == id_room, Appointment.id_tenant == id_tenant),
                Appointment.meet_at == meet_at,
                Appointment.status.in_(("PENDING", "CONFIRMED"))
            )
        )

        if appointment_id is not None:
            query = query.where(Appointment.id != appointment_id)

        result = await self.db.execute(query.limit(1))

        return result.scalar_one_or_none()

    async def create_appointment(self, id_room, id_tenant, meet_at):
        appointment = Appointment(
            id_room=id_room,
            id_tenant=id_tenant,
            meet_at=meet_at,
            status="PENDING"
        )

        self.db.add(appointment)
        await self.db.flush()
        return appointment

    async def get_appointments_by_id_account(self, id_account):
        result = await self.db.execute(
            select(
                Appointment.id.label("id_appointment"),
                Tenant.full_name.label("name_tenant"),
                Room.id.label("id_room"),
                Room.name.label("name_room"),
                Appointment.meet_at ,
                Appointment.status
            )
            .select_from(Appointment)
            .join(Tenant, Appointment.id_tenant == Tenant.id)
            .join(Room, Appointment.id_room == Room.id)
            .join(LandLord, Room.landlord_id == LandLord.id)
            .where(or_(Tenant.account_id == id_account, LandLord.account_id == id_account))
            .where(Appointment.status != "CANCELLED")
            .order_by(Appointment.meet_at, Appointment.id)
        )

        return result.all()

    async def create_notification(self, id_account, content):
        notification = Notification(
            id_account=id_account,
            content=content,
            is_read=False
        )

        self.db.add(notification)
        await self.db.flush()
        return notification
