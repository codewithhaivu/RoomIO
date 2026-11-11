from fastapi import HTTPException
from fastapi.concurrency import run_in_threadpool
from core.cloudinary_custom import cloud_service
from repositories.tenant_repository import TenantRepository
from schemas.tenant import CreateProfileRequest, ProfileResponse, UpdateProfileRequest, ImageResponse


class TenantService:

    def __init__(self, repository: TenantRepository):
        self.repository = repository

    async def create_profile(self,request: CreateProfileRequest ,id_account: str ) -> ProfileResponse:
        new_profile = await self.repository.create_profile(request.fullName,request.gender,request.avatar,request.description,id_account)
        if new_profile is None :
            raise HTTPException(409 ,'Hồ sơ đã được tạo')

        return  ProfileResponse(
            fullName= new_profile.full_name,
            gender = new_profile.gender ,
            avatar= new_profile.avatar,
            description =new_profile.description ,
            message = 'Tạo mới dữ liệu thành công'
        )
    async def get_profile(self,id_account:str) ->ProfileResponse:
        profile = await self.repository.get_profile_by_id_account(id_account)
        if profile is None :
            raise  HTTPException(404,"Hồ sơ chưa được tạo")

        return ProfileResponse(
            fullName= profile.full_name,
            gender = profile.gender ,
            avatar= profile.avatar,
            description =profile.description ,
            message = 'Lấy dữ liệu thành công'
        )

    async def update_profile(self,request : UpdateProfileRequest , id_account :str) -> ProfileResponse:
        new_profile = await self.repository.update_profile(request.fullName, request.gender, request.avatar,
                                                           request.description, id_account)
        if new_profile is None:
            raise HTTPException(404, 'Hồ sơ chưa được tạo ')

        return ProfileResponse(
            fullName=new_profile.full_name,
            gender=new_profile.gender,
            avatar=new_profile.avatar,
            description=new_profile.description,
            message='Cập nhật dữ liệu thành công'
        )

    async def upload_avatar(self, image) -> ImageResponse:

        result = await run_in_threadpool(
            cloud_service.upload_image,
            image
        )

        return ImageResponse(
            image_url=result["url"],
            public_id=result["public_id"]
        )