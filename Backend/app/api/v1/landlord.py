from fastapi import APIRouter, Depends, UploadFile, File

from app.api.deps import  get_current_account, get_landlord_service
from schemas.landlord import CreateProfileRequest, ProfileResponse, UpdateProfileRequest, ImageResponse

router = APIRouter(
    prefix="/landlords",
    tags=["LandLord"]
)


@router.post('/profile',response_model=ProfileResponse)
async def create_profile(request: CreateProfileRequest ,
    service =Depends(get_landlord_service),
    id_account = Depends(get_current_account)) :
    return await service.create_profile(request,id_account)

@router.get('/profile', response_model=ProfileResponse)
async def get_profile(
    service =Depends(get_landlord_service),
    id_account = Depends(get_current_account)) :
    return await service.get_profile(id_account)

@router.post('/profile/upload-avatar',response_model=ImageResponse)
async def upload_avatar(
        image: UploadFile = File(...),
        service=Depends(get_landlord_service)
) :
    return await service.upload_avatar(image)

@router.patch('/profile',response_model=ProfileResponse)
async def update_profile(request: UpdateProfileRequest ,
    service =Depends(get_landlord_service),
    id_account = Depends(get_current_account)) :
    return await service.update_profile(request,id_account)