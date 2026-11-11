from fastapi import APIRouter, Depends

from app.api.deps import get_review_service, get_current_account
from schemas.account import MessageResponse
from schemas.review import ReviewUpdateRequest, ReviewResponse, ReviewRequest, ListReviewResponse

router = APIRouter(
    prefix="/reviews",
    tags=["Review"]
)
# Bất kì ai cũng có thể xem toàn bộ đánh giá cho 1 phòng
@router.get('/{room_id}',response_model=ListReviewResponse)
async def get_reviews(
    room_id :str ,
    service = Depends(get_review_service),
) :
   return await service.get_reviews(room_id)

#Update 1 review , chỉ có thể update review của bản thân ( cụ thể là tenant)
@router.patch('/{review_id}', response_model=ReviewResponse)
async def update_review(
    review_id : str,
    request : ReviewUpdateRequest ,
    service = Depends(get_review_service),
    id_account = Depends(get_current_account)
) :
   return await service.update_review(review_id,request,id_account)

# Xóa 1 reivew cụ thể ( chuyển status về inactive ) , chỉ có thể xóa review của bản thân ( tenant mới xóa được )
@router.delete('/{review_id}', response_model=MessageResponse)
async def delete_review(
    review_id : str,
    service = Depends(get_review_service),
    id_account = Depends(get_current_account)
) :
    return await service.delete_review(review_id,id_account)

#đánh giá 1 phòng cụ thể( chỉ khách hàng đang thuê hoặc đã thuê mới có thể đánh giá ( tồn tại trong bảng room_rental)
@router.post('/{room_id}', response_model=ReviewResponse)
async def post_review(
    room_id : str,
    request : ReviewRequest ,
    service = Depends(get_review_service),
    id_account = Depends(get_current_account)
) :
    return await service.post_review(room_id,request,id_account)



