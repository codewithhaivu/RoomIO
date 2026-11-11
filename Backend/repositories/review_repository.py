from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.review import Review
from models.room import Room
from models.room_rental import RoomRental
from models.tenant import Tenant


class ReviewRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    @asynccontextmanager
    async def transaction(self) -> AsyncIterator[None]:
        """Finish one use case atomically using the request-scoped session."""
        try:
            yield
            await self.db.commit()
        except BaseException:
            # Also release locks when validation, authorization or cancellation
            # interrupts the use case before it can commit.
            await self.db.rollback()
            raise

    async def get_reviews(
        self, room_id: UUID | None, *, status: str
    ) -> list[tuple[Review, Tenant]]:
        statement = (
            select(Review, Tenant)
            .join(Tenant, Tenant.id == Review.id_tenant)
            .where(Review.status == status)
            .order_by(Review.created_at.desc(), Review.id.desc())
        )
        if room_id is not None:
            statement = statement.where(Review.id_rooms == room_id)

        result = await self.db.execute(statement)
        return list(result.tuples().all())

    async def get_review_by_id(
        self, review_id: UUID, *, for_update: bool = False
    ) -> tuple[Review, Tenant] | None:
        statement = (
            select(Review, Tenant)
            .join(Tenant, Tenant.id == Review.id_tenant)
            .where(Review.id == review_id)
        )
        if for_update:
            statement = statement.with_for_update()

        result = await self.db.execute(statement)
        return result.tuples().one_or_none()

    async def get_room_by_id(
        self, room_id: UUID, *, for_update: bool = False
    ) -> Room | None:
        statement = select(Room).where(Room.id == room_id)
        if for_update:
            statement = statement.with_for_update()

        result = await self.db.execute(statement)
        return result.scalar_one_or_none()

    async def get_rental_by_account_and_room(
        self, account_id: UUID, room_id: UUID, *, for_update: bool = False
    ) -> RoomRental | None:
        statement = (
            select(RoomRental)
            .join(Tenant, Tenant.id == RoomRental.id_tenant)
            .where(Tenant.account_id == account_id, RoomRental.id_room == room_id)
            .order_by(RoomRental.id)
            .limit(1)
        )
        if for_update:
            statement = statement.with_for_update()

        result = await self.db.execute(statement)
        return result.scalar_one_or_none()

    async def create_review(
        self,
        *,
        room_id: UUID,
        tenant_id: UUID,
        content: str,
        rating: float,
        status: str,
    ) -> Review:
        review = Review(
            id_rooms=room_id,
            id_tenant=tenant_id,
            content=content,
            rating=rating,
            status=status,
        )
        self.db.add(review)
        # Materialize the UUID and created_at defaults before response mapping.
        await self.db.flush()
        return review

    async def update_review(
        self,
        review: Review,
        *,
        content: str | None = None,
        rating: float | None = None,
        status: str | None = None,
    ) -> Review:
        if content is not None:
            review.content = content
        if rating is not None:
            review.rating = rating
        if status is not None:
            review.status = status

        await self.db.flush()
        return review
