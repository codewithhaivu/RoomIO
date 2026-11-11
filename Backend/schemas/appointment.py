from datetime import datetime
from uuid import UUID

from schemas.base import BaseSchema


class AppointmentRequest(BaseSchema) :
    id_room : UUID
    meet_at : datetime
class AppointmentResponse(BaseSchema) :
    id_appointment: str
    name_tenant : str
    id_room: UUID
    name_room: str
    meet_at: datetime
    status : str

class ListAppointmentResponse(BaseSchema) :
    data : list[AppointmentResponse]
