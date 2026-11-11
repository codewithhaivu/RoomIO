from fastapi import APIRouter ,Depends

from app.api.deps import get_amenitie_service
from schemas.amenitie import  ListAmenityResponse

router = APIRouter(
    prefix="/amenitie",
    tags=["Amenitie"]
)

@router.get('',response_model=ListAmenityResponse)
async def get_amenities(
        service = Depends(get_amenitie_service)
) :
    return await service.get_amenities()