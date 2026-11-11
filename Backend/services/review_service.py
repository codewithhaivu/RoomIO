from math import isfinite
from uuid import UUID

from fastapi import HTTPException, status

from models.review import Review
from repositories.review_repository import ReviewRepository
from schemas.account import MessageResponse
from schemas.review import (
    ListReviewResponse,
    ReviewRequest,
    ReviewResponse,
    ReviewUpdateRequest,
    UserReview,
)


class ReviewService:
    def __init__(self, repository: ReviewRepository) -> None:
        self.repository = repository

    @staticmethod
    def _parse_uuid(value: str | UUID, field_name: str) -> UUID:
        if isinstance(value, UUID):
            return value
        try:
            return UUID(value)
        except (ValueError, TypeError, AttributeError) as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{field_name} phải là UUID hợp lệ",
            ) from exc

    @staticmethod
    def _validate_content(content: str) -> str:
        if not content.strip() or len(content) > 255:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Nội dung đánh giá không được để trống hoặc vượt quá 255 ký tự",
            )
        return content

    @staticmethod
    def _parse_rating(rating: str) -> float:
        # Requests use str, whereas the database column stores a Float.
        try:
            value = float(rating)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Điểm đánh giá phải là một số hữu hạn",
            ) from exc
        if not isfinite(value):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Điểm đánh giá phải là một số hữu hạn",
            )
        return value

    @staticmethod
    def _to_response(review: Review) -> ReviewResponse:
        return ReviewResponse(
            id_review=review.id,
            id_tenant=review.id_tenant,
            content=review.content,
            rating=str(review.rating),
            created_at=review.created_at,
        )

    async def _get_owned_review(self, review_id: UUID, account_id: UUID) -> Review:
        record = await self.repository.get_review_by_id(review_id, for_update=True)
        if record is None or record[0].status != "active":
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy đánh giá đang hoạt động",
            )

        review, tenant = record
        if tenant.account_id != account_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Chỉ khách thuê tạo đánh giá mới được sửa hoặc xóa đánh giá này",
            )
        return review

    async def get_reviews(self, room_id: str | None = None) -> ListReviewResponse:
        parsed_room_id = (
            self._parse_uuid(room_id, "room_id") if room_id is not None else None
        )
        async with self.repository.transaction():
            if parsed_room_id is not None:
                room = await self.repository.get_room_by_id(parsed_room_id)
                if room is None:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Không tìm thấy phòng",
                    )

            records = await self.repository.get_reviews(parsed_room_id, status="active")
            # Both lists share the same order: user_review[i] authored data[i].
            return ListReviewResponse(
                user_review=[
                    UserReview(full_name=tenant.full_name, avatar=tenant.avatar or "")
                    for _, tenant in records
                ],
                data=[self._to_response(review) for review, _ in records],
            )

    async def update_review(
        self,
        review_id: str,
        request: ReviewUpdateRequest,
        id_account: str | UUID,
    ) -> ReviewResponse:
        parsed_review_id = self._parse_uuid(review_id, "review_id")
        account_id = self._parse_uuid(id_account, "id_account")
        async with self.repository.transaction():
            review = await self._get_owned_review(parsed_review_id, account_id)
            if request.content is None and request.rating is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cần cung cấp nội dung hoặc điểm đánh giá để cập nhật",
                )
            content = (
                self._validate_content(request.content)
                if request.content is not None
                else None
            )
            rating = (
                self._parse_rating(request.rating) if request.rating is not None else None
            )
            updated = await self.repository.update_review(
                review, content=content, rating=rating
            )
            # Map before commit so expire_on_commit=True is also supported.
            return self._to_response(updated)

    async def delete_review(
        self, review_id: str, id_account: str | UUID
    ) -> MessageResponse:
        parsed_review_id = self._parse_uuid(review_id, "review_id")
        account_id = self._parse_uuid(id_account, "id_account")
        async with self.repository.transaction():
            review = await self._get_owned_review(parsed_review_id, account_id)
            await self.repository.update_review(review, status="inactive")
            return MessageResponse(message="Xóa đánh giá thành công")

    async def post_review(
        self,
        room_id: str,
        request: ReviewRequest,
        id_account: str | UUID,
    ) -> ReviewResponse:
        parsed_room_id = self._parse_uuid(room_id, "room_id")
        account_id = self._parse_uuid(id_account, "id_account")
        content = self._validate_content(request.content)
        rating = self._parse_rating(request.rating)

        async with self.repository.transaction():
            room = await self.repository.get_room_by_id(parsed_room_id, for_update=True)
            if room is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Không tìm thấy phòng",
                )

            rental = await self.repository.get_rental_by_account_and_room(
                account_id, parsed_room_id, for_update=True
            )
            # Any historical rental qualifies, regardless of its current status.
            if rental is None:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Chỉ khách thuê đang thuê hoặc đã từng thuê phòng mới được đánh giá",
                )

            review = await self.repository.create_review(
                room_id=parsed_room_id,
                tenant_id=rental.id_tenant,
                content=content,
                rating=rating,
                status="active",
            )
            return self._to_response(review)
