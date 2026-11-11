from fastapi import APIRouter

from app.api.v1.auth import router as auth_router
from app.api.v1.room import router as room_router
from app.api.v1.tenant import router as tenant_router
from app.api.v1.landlord import router as landlord_router
from app.api.v1.amenitie import  router as amenity_router
from app.api.v1.interior import  router as interior_router
from app.api.v1.appointment import router as appointment_router
from app.api.v1.rental import router as rental_router
from app.api.v1.ws import router as websocket_router
from app.api.v1.notification import router as notification_router
from app.api.v1.chat import router as chat_router
from app.api.v1.admin import router as admin_router
from app.api.v1.review import router as review_router
from app.api.v1.room_saved import router as room_saved_router
from app.api.v1.device import router as device_router
api_router = APIRouter()

api_router.include_router(auth_router)
api_router.include_router(room_router)
api_router.include_router(tenant_router)
api_router.include_router(landlord_router)
api_router.include_router(amenity_router)
api_router.include_router(interior_router)
api_router.include_router(appointment_router)
api_router.include_router(websocket_router)
api_router.include_router(rental_router)
api_router.include_router(notification_router)
api_router.include_router(chat_router)
api_router.include_router(admin_router)
api_router.include_router(review_router)
api_router.include_router(room_saved_router)
api_router.include_router(device_router)