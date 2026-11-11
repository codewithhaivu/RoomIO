from datetime import datetime
from uuid import UUID

from schemas.base import BaseSchema



class ConversationResponse(BaseSchema) :
    target_user_id : UUID
    target_user_name : str
    target_avatar_url : str
    last_message :str
    updated_at : datetime


class ListConversationResponse(BaseSchema) :
    data : list[ConversationResponse]

class MessageResponse(BaseSchema) :
    message_id :UUID
    sender_id : UUID
    receiver_id :UUID
    content : str
    status : str
    created_at : str

class ListMessageResponse(BaseSchema) :
    data : list[MessageResponse]

class ChatMessageRequest(BaseSchema) :
    receiver_id : UUID
    content : str
    created_at : str
    status : str
    type : str

class ChatMessageResponse(BaseSchema) :
    id_valid : bool
