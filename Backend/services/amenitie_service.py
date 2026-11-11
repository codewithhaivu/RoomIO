from repositories.amenitie_repository import AmenityRepository
from schemas.amenitie import ListAmenityResponse, AmenityResponse


class AmenityService:

    def __init__(self, repository: AmenityRepository):
        self.repository = repository


    async def get_amenities(self) -> ListAmenityResponse:
        amenities = await self.repository.get_amenities()
        result = [
            AmenityResponse(
                id = amenity.id ,
                name = amenity.name
            )
            for amenity in amenities
        ]
        return ListAmenityResponse(
            data = result
        )

