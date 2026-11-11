# Đối chiếu backend chat và cách bổ sung

Router trong app/api/v1/chat.py đã đúng cơ chế REST + WebSocket, không cần thêm endpoint tạo hội thoại.

## 1. Cho frontend biết gửi tin cho ai

POST /chat/messages cần receiver_id là Account.id.
GET /chat/conversations chỉ trả target_user_id cho hội thoại đã tồn tại, nên không giải quyết được trường hợp khách chưa từng nhắn.
Response chi tiết phòng hiện chỉ có full_name, gender, avatar, is_verify; frontend không thể suy ra Account.id từ các trường này.

Bổ sung vào schemas/room.py:

```python
class LandlordResponse(BaseSchema):
    account_id: UUID
    full_name: str
    gender: str
    avatar: str | None
    is_verify: bool
```

Trong services/room_service.py, tại landlord=LandlordResponse(...), thêm:

```python
landlord=LandlordResponse(
    account_id=landlord.account_id,
    full_name=landlord.full_name,
    gender=landlord.gender,
    avatar=landlord.avatar,
    is_verify=landlord.is_verify,
)
```

Dùng landlord.account_id, không dùng landlord.id: một giá trị là ID đăng nhập, một giá trị là ID hồ sơ.
Không cần đổi bảng DB vì models/landlord.py đã có account_id.

Frontend đã đọc landlord.account_id và nhúng ContactLandlordButton vào thông tin chủ trọ của RoomDetailPage.
Có ID thì khách thuê có thể bấm liên hệ; thiếu ID thì hiện "Chưa có thông tin liên hệ của chủ trọ." và không gửi tới một ID suy đoán.

## 2. Thực thi quy tắc ai được nhắn cho ai

services/chat_service.py hiện mới kiểm tra tài khoản tồn tại, tự gửi cho mình, nội dung, trạng thái và thời gian.
Nó chưa đọc accounts[sender_id].role hoặc accounts[receiver_id].role để phân quyền.
Vì vậy nếu gọi REST trực tiếp, chủ trọ vẫn có thể khởi tạo hội thoại và hai tài khoản cùng vai trò vẫn có thể gửi cho nhau.

Trong send_message(), ngay sau hai kiểm tra tài khoản tồn tại và trước get_conversation(...), bổ sung:

```python
tenant_roles = {"CUSTOMER", "TENANT"}
sender_role = str(accounts[sender_id].role).upper()
receiver_role = str(accounts[receiver_id].role).upper()

valid_pair = (
    sender_role in tenant_roles and receiver_role == "LANDLORD"
) or (
    sender_role == "LANDLORD" and receiver_role in tenant_roles
)
if not valid_pair:
    raise HTTPException(
        status_code=403,
        detail="Chỉ khách thuê và chủ trọ được nhắn tin cho nhau",
    )
```

Sau khi tìm conversation, trước khi tạo conversation mới, bổ sung:

```python
if conversation is None and sender_role not in tenant_roles:
    raise HTTPException(
        status_code=403,
        detail="Chỉ khách thuê được bắt đầu hội thoại",
    )
```

Giữ các kiểm tra trong try/except hiện tại để lỗi phân quyền được rollback và không tạo message hoặc phát socket.
Nếu đã có dữ liệu hội thoại sai vai trò từ trước, cần xử lý hoặc lọc chúng trong API đọc danh sách/lịch sử theo cùng quy tắc.

## Luồng sau khi bổ sung

1. Khách thuê mở chi tiết phòng, frontend nhận landlord.account_id.
2. Bấm Liên hệ chủ trọ: GET /chat/messages/{account_id}.
3. Có lịch sử: mở ChatPage ngay.
4. Chưa có lịch sử: nhập tin đầu tiên trong hộp thoại ở chi tiết phòng.
5. POST /chat/messages vừa tạo hội thoại vừa lưu tin nhắn. Thành công rồi frontend mở ChatPage.
6. Chủ trọ mở Tin nhắn để trả lời; không có nút tạo hội thoại.
7. Inbox chỉ hiển thị hội thoại có tin nhắn.

Các đoạn backend ở trên là hướng dẫn bổ sung, chưa được áp dụng vào thư mục Backend.
