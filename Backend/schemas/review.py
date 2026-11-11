from datetime import datetime
from uuid import UUID

from schemas.base import BaseSchema


class ReviewUpdateRequest(BaseSchema):
    content : str| None =None
    rating : str | None = None


class ReviewResponse(BaseSchema) :
    id_review : UUID
    id_tenant : UUID
    content : str
    rating : str
    created_at : datetime

class UserReview(BaseSchema) :
    full_name : str
    avatar : str
class ReviewRequest(BaseSchema) :
    content : str
    rating : str

class ListReviewResponse(BaseSchema) :
    user_review :list[UserReview]
    data : list[ReviewResponse]