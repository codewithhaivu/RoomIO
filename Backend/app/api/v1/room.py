from uuid import UUID

from fastapi import APIRouter, Depends, UploadFile, File, Form

from app.api.deps import get_current_account, get_room_service, get_optional_account
from schemas.room import RoomResponse, RoomRequest, ListImageResponse, ListRoomResponse, RoomDetailResponse, \
    ListRoomByPosition, ListRoomByDistrict, RoomRequestUpdate, LocationResponse, ListLocationResponse

router = APIRouter(
    prefix="/rooms",
    tags=["Room"]
)

#Lấy ra danh sách các khu vực có type == 'area'
@router.get(
    "/locations",
    response_model=ListLocationResponse,
    summary="Lấy danh sách khu vực tìm kiếm phòng"
)
async def get_room_locations(
    service = Depends(get_room_service)
):
    return await service.get_list_location_district()

@router.post('', response_model=RoomResponse)
async def postRoom(request: RoomRequest,
                   id_account= Depends(get_current_account),
                   service= Depends(get_room_service)):
    return await service.postRoom(request, id_account)


@router.post("/images/upload", response_model=ListImageResponse)
async def upload_images(
        images: list[UploadFile] = File(...),
        is_thumbnails: list[bool] = Form(...),
        service=Depends(get_room_service)
):
    return await service.upload_images(images,is_thumbnails)


@router.get("/me", response_model=ListRoomResponse)
async def getListRoom(
        id_account= Depends(get_current_account),
        service= Depends(get_room_service)
):
    return await service.getListRoom(id_account)



@router.get("/{room_id}", response_model=RoomDetailResponse)
async def getDetailRoom(
        room_id: UUID,
        service= Depends(get_room_service)
):
    return await service.getDetailRoom(room_id)


@router.patch("/{room_id}/{status}")
async def updateStatusRoom(
        room_id: UUID,
        status: str,
        id_account= Depends(get_current_account),
        service= Depends(get_room_service)
):
    if await service.updateStatusRoom(room_id, id_account, status) is True:
        return {
            "Message": "Thay đổi trạng thái thành công"
        }
    return {
        "Message": "Thay đổi trạng thái thất bại"
    }

#Update thông tin phòng
# tác nhân duy nhất là chủ phòng trọ
@router.patch("/{room_id}", response_model=RoomDetailResponse)
async def updateRoom(
        room_id: UUID,
        request: RoomRequestUpdate,
        id_account= Depends(get_current_account),
        service= Depends(get_room_service)
):
    return await service.updateRoom(room_id,id_account,request)

@router.get("/nearby/position", response_model=ListRoomByPosition)
async def searchRoomByPosition(
        latitude: float,
        longitude: float,
        radius: float,
        id_account = Depends(get_optional_account),
        service= Depends(get_room_service)
):
    return await service.searchRoomByPosition(latitude,longitude,radius,id_account)

@router.get("/nearby/district", response_model=ListRoomByDistrict)
async def searchRoomsByArea(
        location_id :UUID ,
        district :str ,
        radius: float = 10,
        id_account = Depends(get_optional_account),
        service= Depends(get_room_service)
):
    return await service.searchRoomsByArea(location_id,radius,district,id_account)

