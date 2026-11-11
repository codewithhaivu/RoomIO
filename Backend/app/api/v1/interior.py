from fastapi import APIRouter ,Depends

from app.api.deps import  get_interior_service
from schemas.amenitie import  ListAmenityResponse

router = APIRouter(
    prefix="/interior",
    tags=["Interior"]
)

@router.get('',response_model=ListAmenityResponse)
async def get_interiors(
        service = Depends(get_interior_service)
) :
    return await service.get_interiors()