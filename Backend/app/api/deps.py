from fastapi import Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from core.config import AsyncSessionLocal
from core.security import verify_token
from repositories.account_repository import AccountRepository
from repositories.admin_repository import AdminRepository
from repositories.amenitie_repository import AmenityRepository
from repositories.appointment_repository import AppointmentRepository
from repositories.chat_repository import ChatRepository
from repositories.device_repository import DeviceRepository
from repositories.interior_repository import InteriorRepository
from repositories.landlord_repository import LandlordRepository
from repositories.notification_repository import NotificationRepository
from repositories.rental_repository import RentalRepository
from repositories.review_repository import ReviewRepository
from repositories.room_repository import RoomRepository
from repositories.room_save_repository import RoomSaveRepository
from repositories.tenant_repository import TenantRepository
from services.account_service import AccountService
from services.admin_service import AdminService
from services.amenitie_service import AmenityService
from services.appointment_service import AppointmentService
from services.chat_service import ChatService
from services.device_service import DeviceService
from services.interior_service import InteriorService
from services.landlord_service import LandlordService
from services.notification_service import NotificationService
from services.push_notification_service import PushNotificationService
from services.rental_service import RentalService
from services.review_service import ReviewService
from services.room_save_service import RoomSaveService
from services.room_service import RoomService
from services.tenant_service import TenantService

security = HTTPBearer()
optional_security = HTTPBearer(auto_error=False)


async def get_db():
    async with AsyncSessionLocal() as db:
        try:
            yield db
        except Exception:
            await db.rollback()
            raise


def get_account_service(
        db=Depends(get_db)
):
    repository = AccountRepository(db)

    return AccountService(repository)

def get_push_notification_service(
    db= Depends(get_db)
) :

    repository = DeviceRepository(db)

    return PushNotificationService(repository)

def get_tenant_service(
        db=Depends(get_db)
):
    repository = TenantRepository(db)
    return TenantService(repository)


def get_landlord_service(
        db=Depends(get_db)
):
    repository = LandlordRepository(db)
    return LandlordService(repository)


def get_amenitie_service(
        db=Depends(get_db)
):
    repository = AmenityRepository(db)
    return AmenityService(repository)


def get_interior_service(
        db=Depends(get_db)
):
    repository = InteriorRepository(db)
    return InteriorService(repository)


def get_room_service(
        db=Depends(get_db)
):
    repository = RoomRepository(db)
    return RoomService(repository)


def get_appointment_service(
        db=Depends(get_db) ,
        firebase_service=Depends(get_push_notification_service)
):
    repository = AppointmentRepository(db)
    return AppointmentService(repository ,firebase_service)


def get_rental_service(
        db=Depends(get_db)
):
    repository = RentalRepository(db)
    return RentalService(repository)


def get_notification_service(
        db=Depends(get_db)
):
    repository = NotificationRepository(db)
    return NotificationService(repository)


def get_chat_service(
        db=Depends(get_db) ,
        firebase_service = Depends(get_push_notification_service)
):
    repository = ChatRepository(db)
    return ChatService(repository ,firebase_service)


def get_admin_service(
        db=Depends(get_db)
):
    repository = AdminRepository(db)
    return AdminService(repository)


def get_review_service(
        db=Depends(get_db)
):
    repository = ReviewRepository(db)
    return ReviewService(repository)


def get_room_save_service(
        db=Depends(get_db)
):
    repository = RoomSaveRepository(db)
    return RoomSaveService(repository)

def get_device_service(
        db=Depends(get_db)
):
    repository = DeviceRepository(db)
    return DeviceService(repository)

def get_current_account(
        credentials: HTTPAuthorizationCredentials = Depends(security)
):
    return verify_token(credentials.credentials)


def get_optional_account(
        credentials: HTTPAuthorizationCredentials | None = Depends(
            optional_security
        )
):
    if credentials is None:
        return None

    return verify_token(credentials.credentials)
