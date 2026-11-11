import logging
from datetime import datetime, timezone
from uuid import UUID

from fastapi import HTTPException

from app.websocket.user import websocket_user
from repositories.chat_repository import ChatRepository
from schemas.chat import (
    ChatMessageRequest, ChatMessageResponse, ConversationResponse, ListConversationResponse,
    ListMessageResponse, MessageResponse
)
from services.push_notification_service import PushNotificationService

logger = logging.getLogger(__name__)


class ChatService:

    def __init__(self, repository: ChatRepository , firebase_service :PushNotificationService):
        self.repository = repository
        self.service = firebase_service

    def _parse_uuid(self, value):
        try:
            return UUID(str(value))
        except (ValueError, TypeError, AttributeError):
            raise HTTPException(status_code=400, detail="ID tài khoản không hợp lệ")

    def _parse_created_at(self, value):
        try:
            created_at = datetime.fromisoformat(value)
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="Thời gian tin nhắn không hợp lệ")

        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)

        # DateTime trên MySQL hiện lưu đến giây; thống nhất về UTC.
        return created_at.astimezone(timezone.utc).replace(microsecond=0)

    def _message_response(self, message, receiver_id):
        created_at = message.created_at
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)

        return MessageResponse(
            message_id=message.id,
            sender_id=message.sender_id,
            receiver_id=receiver_id,
            content=message.content,
            status=message.status,
            created_at=created_at.astimezone(timezone.utc).isoformat()
        )

    async def get_conversations(self, id_account: str) -> ListConversationResponse:
        conversations = await self.repository.get_conversations(id_account)

        return ListConversationResponse(
            data=[
                ConversationResponse(
                    target_user_id=conversation.target_user_id,
                    target_user_name=conversation.target_user_name,
                    target_avatar_url=conversation.target_avatar_url,
                    last_message=conversation.last_message,
                    updated_at=conversation.updated_at
                )
                for conversation in conversations
            ]
        )

    async def get_message(self, id_account: str, target_user_id: UUID) -> ListMessageResponse:
        conversation = await self.repository.get_conversation(id_account, target_user_id)
        if conversation is None:
            return ListMessageResponse(data=[])

        messages = await self.repository.get_messages(conversation.id)

        return ListMessageResponse(
            data=[
                self._message_response(
                    message,
                    conversation.user2_id if message.sender_id == conversation.user1_id else conversation.user1_id
                )
                for message in messages
            ]
        )

    async def send_message(self, id_account: str, request: ChatMessageRequest) -> ChatMessageResponse:
        sender_id = self._parse_uuid(id_account)
        receiver_id = request.receiver_id
        if sender_id == receiver_id:
            raise HTTPException(status_code=400, detail="Không thể gửi tin nhắn cho chính mình")
        if not request.content.strip() or len(request.content) > 500:
            raise HTTPException(status_code=400, detail="Nội dung tin nhắn phải từ 1 đến 500 ký tự")
        if request.status not in ("active", "deactivate"):
            raise HTTPException(status_code=400, detail="Trạng thái tin nhắn không hợp lệ")
        if not request.type.strip():
            raise HTTPException(status_code=400, detail="Loại sự kiện tin nhắn không hợp lệ")

        created_at = self._parse_created_at(request.created_at)

        try:
            # Khóa hai tài khoản theo cùng thứ tự để tránh tạo trùng hội thoại
            # khi hai bên gửi tin nhắn đầu tiên cùng lúc.
            accounts = {}
            for account_id in sorted((sender_id, receiver_id)):
                accounts[account_id] = await self.repository.get_account_by_id(account_id, for_update=True)

            if accounts[sender_id] is None:
                raise HTTPException(status_code=401, detail="Tài khoản người gửi không tồn tại")
            if accounts[receiver_id] is None:
                raise HTTPException(status_code=404, detail="Không tìm thấy người nhận")

            conversation = await self.repository.get_conversation(sender_id, receiver_id, for_update=True)
            # updated_at phản ánh lúc server nhận tin, không phụ thuộc đồng hồ client.
            updated_at = datetime.now(timezone.utc).replace(microsecond=0)
            if conversation is None:
                user1_id, user2_id = sorted((sender_id, receiver_id))
                conversation = await self.repository.create_conversation(
                    user1_id, user2_id, request.content, updated_at
                )

            message = await self.repository.create_message(
                conversation.id, sender_id, request.content, request.status, created_at
            )
            await self.repository.update_conversation(conversation, message.content, updated_at)
            response = self._message_response(message, receiver_id)
            # type chỉ phân biệt sự kiện WebSocket; model Message không có cột type.
            event = {"type": request.type, "data": response.model_dump(mode="json")}
            await self.repository.db.commit()
        except HTTPException:
            await self.repository.db.rollback()
            raise
        except Exception:
            await self.repository.db.rollback()
            raise HTTPException(status_code=500, detail="Failed to send message")

        # Tin nhắn offline đã nằm trong Messages và được lấy lại qua API lịch sử.
        websocket = websocket_user.connections.get(receiver_id)
        if websocket is not None:
            try:
                await websocket.send_json(event)
            except Exception:
                if websocket_user.connections.get(receiver_id) is websocket:
                    websocket_user.disconnect(receiver_id)
                # Không báo gửi thất bại sau commit khiến client gửi trùng tin nhắn.
                logger.warning("Không gửi được tin nhắn qua WebSocket", exc_info=True)

        try:
            await self.service.send_notification(
                id_account=receiver_id,
                title="Tin nhắn mới",
                body="Bạn có một tin nhắn mới trên RoomIO",
                data={"type": "chat", "sender_id": str(sender_id)}
            )
        except Exception:
            # Tin nhắn đã commit; lỗi Push không làm thất bại nghiệp vụ.
            logger.exception("Không gửi được Push tin nhắn tới tài khoản %s", receiver_id)

        return ChatMessageResponse(id_valid=True)
