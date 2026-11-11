from repositories.interior_repository import InteriorRepository
from schemas.interior import InteriorResponse, ListInteriorResponse


class InteriorService:

    def __init__(self, repository: InteriorRepository):
        self.repository = repository


    async def get_interiors(self) -> ListInteriorResponse:
        interiors = await self.repository.get_interiors()
        result = [
            InteriorResponse(
                id = interior.id ,
                name = interior.name
            )
            for interior in interiors
        ]
        return ListInteriorResponse(
            data = result
        )