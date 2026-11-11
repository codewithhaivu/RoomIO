# Chat

## Luồng đã nối

- Home → Tin nhắn → `AppRoutes.chatList`.
- Danh sách chỉ hiện hội thoại có `last_message` khác rỗng; không có nút tạo hội thoại.
- `ChatPage` chỉ cho trả lời một hội thoại có lịch sử. Không có nút nhắn lần đầu.
- `ContactLandlordButton` chỉ hiển thị cho CUSTOMER/TENANT. Hội thoại có sẵn được mở ngay; nếu chưa có, nút yêu cầu người dùng nhập tin đầu tiên rồi gửi REST trước khi mở chat.
- Gửi qua Retrofit `POST /chat/messages`. Nhận qua WebSocket `/ws/user/notifications`, header `Authorization: Bearer <access_token>`.
- Chỉ event `chat_message` được parse; các notification khác trên cùng socket được bỏ qua.
- Inbox và màn hội thoại dùng chung một kết nối. Đóng màn hội thoại không ngắt socket của inbox. Listener cuối cùng rời đi sẽ đóng kết nối.
- Có nút kết nối lại; khi ứng dụng trở lại foreground, lịch sử được đồng bộ lại. Không tự gửi lại một POST đã được backend xác nhận.

## Nhúng vào chi tiết phòng

```dart
import 'package:roomio/features/chat/presentation/widgets/contact_landlord_button.dart';

ContactLandlordButton(
  landlordAccountId: landlordAccountId,
  landlordName: detail.landlord.fullName,
  landlordAvatarUrl: detail.landlord.avatar,
)
```

`landlordAccountId` phải là ID **tài khoản** của chủ trọ, không phải ID phòng hoặc ID hồ sơ Landlord.
Frontend hỗ trợ cả `landlord.account_id` và `landlord.id_account` (ưu tiên `account_id` nếu có cả hai); giá trị backend cần lấy từ `landlord.account_id`, không phải `landlord.id`.
API chi tiết phòng hiện chỉ trả tên, giới tính, avatar và trạng thái xác minh của chủ trọ; chưa trả `account_id`.
Frontend đã ánh xạ trường tùy chọn `account_id` vào `LandlordInfoEntity`/`LandlordInfoModel` và gắn nút vào `RoomDetailPage` cho khách thuê.
Khi backend trả `landlord.account_id`, nút liên hệ hoạt động; khi thiếu, trang hiện chưa có thông tin liên hệ và không đoán ID người nhận.
Các thay đổi backend cụ thể được ghi tại [chat-backend-review.md](chat-backend-review.md).

## Đồng bộ với backend hiện có

Backend chưa có endpoint tạo hội thoại riêng. `POST /chat/messages` đã tạo hoặc tái sử dụng hội thoại trong cùng transaction,
nên `ContactLandlordUseCase` dùng chính API này với nội dung do người dùng nhập. Không gửi lời chào tự động hoặc tin rỗng.

REST giữ `DataState` để khớp kiến trúc hiện tại; realtime trả `Stream<Either<Failure, MessageEntity>>`.
`MessageEntity` là alias của `MessageResponse` hiện có. Các use case REST kế thừa `UseCase`; use case stream là class riêng vì base `UseCase` trả `Future`.
API gửi trả `{ "id_valid": true }`, nên BLoC tải lại lịch sử để lấy ID tin nhắn thực từ server. Socket không cần echo về người gửi.

Frontend giới hạn các luồng tạo hội thoại cho khách thuê và chỉ cung cấp nút liên hệ chủ trọ.
Backend hiện chưa kiểm tra cặp role CUSTOMER/TENANT ↔ LANDLORD hoặc chặn LANDLORD tạo hội thoại mới trong `ChatService.send_message`;
API danh sách cũng chưa trả role của đối tác. Để bảo đảm nghiệp vụ với mọi client/API caller,
backend cần xác thực hai role và chỉ cho tenant tạo khi hội thoại chưa tồn tại. Frontend không thể thay thế kiểm tra này.

Dùng `ChatSessionGate` để đọc `role` và JWT `sub` từ secure storage; JWT chỉ được giải mã để hiển thị/lọc dữ liệu.
Xác thực chữ ký và phân quyền là trách nhiệm của backend.

## Kiểm thử

```sh
flutter test --no-pub test/features/chat
flutter analyze --no-pub lib/features/chat lib/core/error/failure.dart lib/injection_container.dart lib/config/route/app_route.dart lib/features/auth/presentation/pages/home_page.dart test/features/chat
```

Các test dùng REST/socket giả để kiểm tra payload, JSON lỗi, tách notification, kết nối dùng chung,
subscription cleanup, race tải lịch sử, chống trùng tin/gửi liên tiếp, auto-scroll, giữ draft khi lỗi,
liên hệ lần đầu, điều hướng và bố cục màn hình hẹp. Cần kiểm tra thêm end-to-end với hai tài khoản trên backend đang chạy.
