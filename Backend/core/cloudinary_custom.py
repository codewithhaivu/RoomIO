from cloudinary import uploader
import cloudinary
from core.config import settings


class CloudinaryService:
    def __init__(self):
        cloudinary.config(
            cloud_name=settings.CLOUDINARY_CLOUD_NAME,
            api_key=settings.CLOUDINARY_API_KEY,
            api_secret=settings.CLOUDINARY_API_SECRET,
        )

    def upload_image_room(self, file, is_thumbnail):
        result = uploader.upload(
            file.file,
            folder="rental_app/rooms"
        )

        return {
            "url": result["secure_url"],
            "public_id": result["public_id"],
            "is_thumbnail" :is_thumbnail
        }

    def upload_image(self, file):
        result = uploader.upload(
            file.file,
            folder="rental_app/person"
        )

        return {
            "url": result["secure_url"],
            "public_id": result["public_id"],
        }

    def delete_image(self, public_id: str):
        result = uploader.destroy(
            public_id,
            resource_type="image",
        )

        return result

cloud_service = CloudinaryService()
