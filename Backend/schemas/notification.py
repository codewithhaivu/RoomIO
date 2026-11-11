from datetime import datetime
from uuid import UUID

from schemas.base import BaseSchema


class NotificationResponse(BaseSchema) :
    notification_id : UUID
    content : str
    is_read : bool
    created_at : datetime


class ListNotificationResponse(BaseSchema) :
    data : list[NotificationResponse]
