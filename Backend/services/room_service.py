import logging
from uuid import UUID

from fastapi import HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from core.cloudinary_custom import cloud_service
from repositories.room_repository import RoomRepository
from schemas.room import RoomRequest, RoomResponse, InteriorResponse, AmenityResponse, ListImageResponse, \
    ListRoomResponse, Location, RoomDetailResponse, LandlordResponse, Image, ListRoomByPosition, RoomByPosition, \
    ListRoomByDistrict, LocationResponse, ListLocationResponse

logger = logging.getLogger(__name__)


class RoomService:
    def __init__(self, repository: RoomRepository):
        self.repository = repository

    async def postRoom(
            self,
            request: RoomRequest,
            id_account: str
    ) -> RoomResponse:

        # Kiểm tra xem chủ trọ có đủ điều kiện để đăng bài không
        landlord = await self.repository.get_landlord_by_id_account(id_account)

        if landlord is None:
            raise HTTPException(
                status_code=404,
                detail="Landlord not found"
            )

        if not landlord.is_verify:
            raise HTTPException(
                status_code=403,
                detail="Landlord is not verified"
            )

        # Kiểm tra các ID nội thất và tiện ích từ app có tồn tại đầy đủ trong database không
        interiors = await self.repository.get_interiors_by_ids(
            request.interiors
        )

        if len(interiors) != len(request.interiors):
            raise HTTPException(
                status_code=400,
                detail="Some interiors do not exist"
            )

        amenities = await self.repository.get_amenities_by_ids(
            request.amenities
        )

        if len(amenities) != len(request.amenities):
            raise HTTPException(
                status_code=400,
                detail="Some amenities do not exist"
            )
        # Lấy địa điểm từ database nếu địa điểm đã tồn tại
        location = await self.repository.get_location(
            request.location.name,
            request.location.longitude,
            request.location.latitude
        )
        try:
            # Nếu địa điểm chưa tồn tại trong database thì tạo mới
            if location is None:
                location = await self.repository.create_location(
                    request.location.name,
                    request.location.longitude,
                    request.location.latitude
                )
            # Nghiệp vụ chính đăng phòng
            room = await self.repository.post_room(
                request.name,
                request.area,
                request.water_fee,
                request.service_fee,
                request.parking_fee,
                request.electricity_fee,
                request.rental_price,
                request.status,
                request.room_type,
                location.id,
                landlord.id
            )

            for image in request.images:
                await self.repository.add_image_to_room(
                    room.id,
                    image.image_url,
                    image.public_id,
                    image.is_thumbnail
                )
            # Tạo các bản ghi liên kết giữa phòng với nội thất và tiện ích
            await self.repository.add_interiors_to_room(room.id, request.interiors)
            await self.repository.add_amenities_to_room(room.id, request.amenities)
            # Chuyển danh sách Model sang danh sách Response tương ứng
            interior_responses = [
                InteriorResponse(
                    id=interior.id,
                    name=interior.name
                )
                for interior in interiors
            ]
            amenity_responses = [
                AmenityResponse(
                    id=amenity.id,
                    name=amenity.name
                )
                for amenity in amenities
            ]
            # Trả về thông tin phòng vừa tạo
            room_response =  RoomResponse(
                id=room.id,
                name=room.name,
                area=room.area,
                water_fee=room.water_fee,
                service_fee=room.service_fee,
                parking_fee=room.parking_fee,
                rental_price=room.rental_price,
                electricity_fee=room.electricity_fee,
                status=room.status,
                room_type=room.room_type,
                location=Location(
                    name = location.name,
                    longitude= location.longitude,
                    latitude=location.latitude
                ),
                interiors=interior_responses,
                amenities=amenity_responses,
                image=ListImageResponse(
                    response=[
                        Image(
                            image_url=image.image_url,
                            public_id=image.public_id,
                            is_thumbnail=image.is_thumbnail
                        )
                        for image in request.images
                    ]
                )
            )
            await self.repository.db.commit()
            return room_response
        except Exception:
            # Nếu có lỗi trong quá trình đăng phòng thì rollback toàn bộ các thay đổi chưa commit
            await self.repository.db.rollback()
            # Xóa ảnh đã từng tải lên cloudinary
            for image in request.images:
                cloud_service.delete_image(image.public_id)
            raise HTTPException(
                status_code=500,
                detail="Failed to post room"
            )

    async def upload_images(self, images: list[UploadFile], is_thumbnails: list[bool]) -> ListImageResponse:
        result = []
        for is_thumbnail, image in zip(is_thumbnails, images):
            dict_result = await run_in_threadpool(
                cloud_service.upload_image_room,
                image,
                is_thumbnail
            )
            result.append(Image(
                image_url=dict_result['url'],
                public_id=dict_result['public_id'],
                is_thumbnail=dict_result['is_thumbnail']
            ))
        return ListImageResponse(
            response=result
        )

    # đang bị N + 1 querry
    async def getListRoom(self, id_account: str) -> ListRoomResponse:
        landlord = await self.repository.get_landlord_by_id_account(id_account)
        if landlord is None:
            raise HTTPException(404, "Not found LandLord")
        rooms = await self.repository.get_rooms_by_id_landlord(landlord.id)
        if len(rooms) == 0:
            return ListRoomResponse(
                rooms=[]
            )
        result = []
        for room in rooms:
            images = await self.repository.get_images_by_room(room.id)
            if len(images) == 0:
                raise HTTPException(404, "Lỗi dữ liệu Image not found ")
            location = await self.repository.get_location_by_id(room.location_id)
            if location is None:
                raise HTTPException(404, "Lỗi dữ liệu location not found ")

            interiors = await self.repository.get_interiors_by_room_id(room.id)
            amenities = await self.repository.get_amenities_by_room_id(room.id)

            result.append(
                RoomResponse(
                    id=room.id,
                    name=room.name,
                    area=room.area,
                    water_fee=room.water_fee,
                    service_fee=room.service_fee,
                    parking_fee=room.parking_fee,
                    rental_price=room.rental_price,
                    electricity_fee=room.electricity_fee,
                    status=room.status,
                    room_type=room.room_type,
                    location=Location(
                        name=location.name,
                        longitude=location.longitude,
                        latitude=location.latitude
                    ),
                    interiors=[InteriorResponse(
                        id=interior.id,
                        name=interior.name
                    ) for interior in interiors],
                    amenities=[AmenityResponse(
                        id=amenity.id,
                        name=amenity.name
                    ) for amenity in amenities],
                    image=ListImageResponse(
                        response=[
                            Image(
                                image_url=image.image_url,
                                public_id=image.public_id,
                                is_thumbnail=image.is_thumbnail
                            ) for image in images
                        ]
                    )
                )
            )
        return ListRoomResponse(
            rooms=result
        )

    # Truy vấn lấy ra chủ trọ Lấy ra phòng trọ , từ id phòng trọ lấy ra ảnh , địa điểm chính xác
    # lấy ra nội thất , tiện ích nữa
    # Sau đó sẽ trả về được kết quả

    async def getDetailRoom(self, room_id: UUID) -> RoomDetailResponse:
        room = await self.repository.get_room_by_id(room_id)
        if room is None:
            raise HTTPException(404, "Không tìm thấy phòng ")
        location = await self.repository.get_location_by_id(room.location_id)
        if location is None:
            raise HTTPException(401, "Lỗi địa điểm")
        landlord = await self.repository.get_landlord_by_id(room.landlord_id)

        if landlord is None:
            raise HTTPException(404, "Không thấy chủ phòng")

        interiors = await self.repository.get_interiors_by_room_id(room.id)
        amenities = await self.repository.get_amenities_by_room_id(room.id)
        images = await self.repository.get_images_by_room(room.id)
        if len(images) == 0:
            raise HTTPException(404, "Lỗi dữ liệu Image not found")

        return RoomDetailResponse(
            room=RoomResponse(
                id=room.id,
                name=room.name,
                area=room.area,
                water_fee=room.water_fee,
                service_fee=room.service_fee,
                parking_fee=room.parking_fee,
                rental_price=room.rental_price,
                electricity_fee=room.electricity_fee,
                status=room.status,
                room_type=room.room_type,
                location=Location(
                    name=location.name,
                    longitude=location.longitude,
                    latitude=location.latitude
                ),
                interiors=[InteriorResponse(
                    id=interior.id,
                    name=interior.name
                ) for interior in interiors],
                amenities=[AmenityResponse(
                    id=amenity.id,
                    name=amenity.name
                ) for amenity in amenities],
                image=ListImageResponse(
                    response=[
                        Image(
                            image_url=image.image_url,
                            public_id=image.public_id,
                            is_thumbnail=image.is_thumbnail
                        ) for image in images
                    ]
                )
            ),
            landlord=LandlordResponse(
                id_account= landlord.account_id ,
                full_name=landlord.full_name,
                gender=landlord.gender,
                avatar=landlord.avatar,
                is_verify=landlord.is_verify
            )
        )

    async def updateStatusRoom(self, room_id, id_account, status):
        landlord = await self.repository.get_landlord_by_id_account(id_account)
        if landlord is None or landlord.is_verify is False:
            raise HTTPException(401, "Không đủ thẩm quyền thay đổi trạng thái phòng ")
        room = await self.repository.get_room_by_id(room_id)
        if room is None:
            raise HTTPException(404, "Không tìm thấy phòng")

        room.status = status
        await self.repository.db.commit()
        return True

    async def searchRoomByPosition(self,latitude,longitude,radius,id_account) ->ListRoomByPosition:
        tenant_id =None
        if id_account is not None :
            tenant = await self.repository.get_tenant_by_id_account(id_account)
            tenant_id = tenant.id
        rooms = await self.repository.getRoomByPositionDistance(latitude,longitude,radius,tenant_id)
        result = [
            RoomByPosition(
                id= room.id,
                name =room.name,
                area = room.area ,
                rental_price = room.rental_price,
                status =room.status ,
                distance = room.distance_km,
                room_type = room.room_type,
                location_name = room.location_name,
                image_url = room.image_url,
                is_saved= room.is_saved
            )
            for room in rooms
        ]
        return ListRoomByPosition(
            rooms = result
        )

    async def searchRoomsByArea(self,location_id,radius,district,id_account)->ListRoomByDistrict:
        tenant_id =None
        if id_account is not None :
            tenant = await self.repository.get_tenant_by_id_account(id_account)
            tenant_id = tenant.id
        location = await self.repository.get_location_by_id(location_id)
        if location is None :
            raise HTTPException(404,"Not found Location")
        rooms = await self.repository.getRoomByPositionDistance(location.latitude,location.longitude,radius,tenant_id)
        result = [
            RoomByPosition(
                id= room.id,
                name =room.name,
                area = room.area ,
                rental_price = room.rental_price,
                status =room.status ,
                distance = room.distance_km,
                room_type = room.room_type,
                location_name = room.location_name,
                image_url = room.image_url ,
                is_saved= room.is_saved
            )
            for room in rooms
        ]
        return ListRoomByDistrict(
            rooms= result ,
            district= district
        )

    async def get_list_location_district(self) ->ListLocationResponse:
        locations = await self.repository.get_location_by_area()

        result = [
            LocationResponse(
                location_id= location.id ,
                name_district= location.name
            )
            for location in locations
        ]
        return ListLocationResponse(
            data=result
        )
