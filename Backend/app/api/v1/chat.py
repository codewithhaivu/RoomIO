from uuid import UUID
from fastapi import APIRouter, Depends
from app.api.deps import get_current_account, get_chat_service
from schemas.chat import ListConversationResponse, ListMessageResponse, ChatMessageRequest, ChatMessageResponse

router = APIRouter(
    prefix="/chat",
    tags=["Chat"]
)

# Lấy danh sách các cuộc hội thoại của user hiện tại.
# Logic cho Service/Repo:
# 1. Query bảng Conversations nơi (user1_id == id_account OR user2_id == id_account).
# 2. Sắp xếp giảm dần (DESC) theo trường updated_at.
@router.get('/conversations' , response_model=ListConversationResponse)
async def get_conversation(
    id_account=Depends(get_current_account),
    service=Depends(get_chat_service)
):
    return await service.get_conversations(id_account)


# Xem toàn bộ lịch sử tin nhắn với 1 đối tác cụ thể.
# Logic cho Service/Repo:
# 1. Tìm bản ghi trong Conversations khớp với cặp (id_account, target_user_id).
# 2. Lấy ra conversation_id. Nếu không tìm thấy, trả về list rỗng [].
# 3. Query bảng Messages theo conversation_id, sắp xếp tăng dần (ASC) theo created_at.
@router.get('/messages/{target_user_id}' , response_model=ListMessageResponse)
async def get_message(
    target_user_id : UUID ,
    id_account=Depends(get_current_account),
    service=Depends(get_chat_service)
):
    return await service.get_message(id_account,target_user_id)


# Gửi tin nhắn mới.
# Logic cho Service/Repo:
# 1. Kiểm tra conversation giữa người gửi (id_account) và người nhận (request.receiver_id) đã tồn tại chưa.
#    - Nếu chưa có: Tạo bản ghi mới trong bảng Conversations.
# 2. Insert nội dung vào bảng Messages kèm theo conversation_id.
# 3. UPDATE trường last_message và updated_at của bảng Conversations bằng dữ liệu mới nhất.
# 4. đẩy dữ liệu qua WebSocket  để thông báo cho người nhận.
@router.post('/messages' , response_model=ChatMessageResponse)
async def send_message(
    request : ChatMessageRequest ,
    id_account=Depends(get_current_account),
    service=Depends(get_chat_service)
):
    return await service.send_message(id_account ,request)