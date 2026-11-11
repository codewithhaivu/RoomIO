# 02 · Kiến trúc Backend

Backend là một ứng dụng FastAPI ghép 15 router vào một ASGI app. `app/main.py` tạo app, gắn `CORSMiddleware` và chạy `init_firebase()` trong lifespan. `app/api/router.py` include từng router. Thư mục `app/api/v1` tổ chức source, URL thực không có prefix `/api/v1`.

## Layers và Dependency Injection

| Thư mục | Trách nhiệm trong source |
| --- | --- |
| `app/api/v1/` | Định tuyến, schema body/query/path, response model, dependency xác thực và điều phối sang service. |
| `app/api/deps.py` | `get_db()` yield `AsyncSessionLocal()` và rollback khi có exception. Các factory `get_*_service()` dựng repository với session, sau đó dựng service. Chat và appointment nhận thêm `PushNotificationService` qua `Depends`. |
| `services/` | Quy tắc nghiệp vụ, chuyển đổi schema, commit/rollback ở một số luồng, gọi Redis/SMS/media/Push. |
| `repositories/` | SQLAlchemy `select`/`join`/`update`/`delete`, `flush`, `with_for_update` ở đường ghi có cạnh tranh. Một số repo tự commit, ví dụ account/device. Room/appointment/rental/chat commit ở service. Review dùng `ReviewRepository.transaction`. |
| `schemas/` | Pydantic request/response. `BaseSchema` cấm field ngoài contract bằng `extra="forbid"`. Kiểu envelope khác nhau theo module, ví dụ `data`, `rooms`, `response`. |
| `models/`, `db/`, `alembic/` | ORM trên `db.base.Base`, script bootstrap cũ, seed catalog và migrations. Xem [thiết kế dữ liệu](04-DATABASE-DESIGN.md). |
| `core/` | Pydantic Settings, async engine, JWT/password, Redis, SMS, Cloudinary, Firebase Admin. |
| `app/websocket/` | `ConnectionUser` giữ kết nối theo account trong bộ nhớ. |
| `test/` | Unit tests và repository tests cho appointment, chat, notification, rental. Có mock và SQLite in-memory. |

## Vòng đời request

1. Uvicorn chạy ASGI, CORS xử lý request theo cấu hình. FastAPI chọn route, giải dependency và parse schema/parameters. Lỗi validation chuẩn là 422.
2. `get_current_account` hoặc `get_optional_account` xử lý Bearer nếu router yêu cầu. `get_db` mở session theo request. Factory dựng repository/service và có thể dùng chung session qua cache dependency của FastAPI.
3. Service kiểm tra domain, gọi repository và adapter ngoài, ánh xạ kết quả. `get_db` không tự commit. Vị trí commit phụ thuộc module. Ví dụ, appointment commit lịch cùng inbox trước WS/Push, chat commit conversation/message trước delivery.
4. Handler trả response model hoặc `HTTPException`. Chưa thấy global error envelope/custom exception handler. Một số service bọc exception thành 500. Lỗi ngoài khối catch đi theo hành vi mặc định. Logger chuẩn Python có trong room, chat, appointment, push. Còn `print`/`traceback.print_exc` ở startup, WS và nghiệp vụ. `DB_ECHO` điều khiển SQL echo, `alembic.ini` có logging riêng cho migration.

## Authentication và Authorization

- `core/security.py` dùng bcrypt qua Passlib cho password, PyJWT ký token với `sub`, `type`, `exp`. `verify_token` xác minh chữ ký/expiry/type, đổi `sub` sang UUID và trả account ID. Dependency này không tải account, role hay state từ database.
- `AccountService.login` kiểm tra password và `state == 'not ok'`. `AccountRepository.create_refresh_token` lưu SHA-256 của refresh JWT trong `refresh_tokens`. Refresh kiểm tra type, account state và revoke, trả access mới. Logout thu hồi refresh tương ứng, reset thu hồi toàn bộ refresh theo account. Access đã phát vẫn qua dependency JWT cho đến expiry ở các route chỉ dùng dependency chung.
- `RentalService` kiểm tra role DB và owner, `AppointmentService` kiểm tra người tham gia hoặc chủ phòng theo từng hành động, `ReviewService` dùng quyền theo rental và tác giả, thông báo/thiết bị scope theo account. `RoomService.postRoom` yêu cầu hồ sơ chủ trọ đã verify.
- Ranh giới đang hở ở `app/api/v1/admin.py`, `AccountService.register/reset_password`, upload public, và `RoomService.updateStatusRoom` thiếu kiểm tra chủ sở hữu. Đọc [roadmap P0](07-TECHNICAL-DEBT-AND-ROADMAP.md#p0--xử-lý-trước-khi-public).

## Tích hợp

| Thành phần | Thực thi và giới hạn |
| --- | --- |
| WebSocket | `app/api/v1/ws.py::notification_websocket` gọi `HTTPBearer` thủ công trên WebSocket, xác thực access JWT, accept và ghi map theo UUID. Vòng lặp chỉ nhận text để duy trì kết nối, client gửi tin qua REST. `ChatService` và `AppointmentService` phát JSON sau commit. Map có một socket/account/process. Kết nối cũ disconnect có thể xóa entry mới. Không có broker, replay, theo dõi expiry sau handshake hay delivery acknowledgment trong mã này. |
| Redis | `core/redis_custom.py` dùng `redis.asyncio` và `REDIS_URL`. `AccountService` lưu OTP 4 chữ số theo phone trong 120 giây. `RentalService` đặt `rental:qr:{token}` bằng `SET NX EX` (60 giây) và tiêu thụ bằng `GETDEL`. Không dùng Redis để phát WS hay cache query. `RedisClient.close` tồn tại nhưng lifespan không gọi. |
| SMS | `core/sms_custom.py::SMSServiceCustom.send_otp` gửi `GET /sms/send` bằng HTTPX timeout 10 giây. Payload có phone/OTP và token nhà cung cấp trong query. JSON provider báo fail được ánh xạ 502. Tên provider và khả năng delivery thực tế chưa xác minh. |
| Firebase Admin SDK | `core/firebase.py::init_firebase` nạp service-account file lúc startup nếu chưa có app. `PushNotificationService.send_notification` đọc các `user_devices`, gửi từng token bằng `asyncio.to_thread(messaging.send, ...)`. Xóa device khi `UnregisteredError`, log `FirebaseError`. Caller hiện có là chat và tạo/xác nhận lịch. Push được await sau commit. |
| Cloudinary | `core/cloudinary_custom.py::CloudinaryService` cấu hình từ Settings. Upload trả `secure_url` và `public_id`. Room/avatar chạy SDK đồng bộ trong threadpool. `RoomService.postRoom` gọi delete bù trừ đồng bộ sau rollback nếu lỗi trong khối ghi DB. Upload là API riêng, trước khi tạo phòng. |

## Danh mục endpoint

Nguồn cho từng nhóm là `app/api/v1/<tên tệp>`, schema tương ứng ở `schemas/`. Inventory theo cặp method/path gồm **59 HTTP** (22 POST, 19 GET, 12 PATCH, 6 DELETE) và **1 WebSocket**. Không tính OpenAPI/Swagger/ReDoc hoặc route framework tự sinh. Các route được đếm dù còn lỗi thực thi. Path giữ nguyên dấu `/` cuối. HTTP thành công mặc định 200 nếu không ghi khác.

### `admin.py` (5)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| GET `/admin/members` | Công khai · P0 | query `page` (1), `limit` (10, tối đa 100) | `ListUser` |
| PATCH `/admin/verify-landlord` | Công khai · P0 | `LandlordVerifyRequest` | `LandlordVerifyResponse` |
| PATCH `/admin/locked-user` | Công khai · P0 | `UserRequest` | `MessageResponse` |
| GET `/admin/rooms/{id_account}` | Công khai · P0 | query `page` (1), `limit` (10, tối đa 100) | `ListRoomResponse` |
| DELETE `/admin/rooms` | Công khai · P0 | `ListRoomRequest` | `MessageResponse` |

### `amenitie.py` (1)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| GET `/amenitie` | Công khai | — | `ListAmenityResponse` |

### `appointment.py` (5)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| POST `/appointments/` | Bearer | `AppointmentRequest` | `AppointmentResponse` |
| GET `/appointments/` | Bearer | — | `ListAppointmentResponse` |
| PATCH `/appointments/{appointment_id}/{status}` | Bearer | — | `MessageResponse` |
| DELETE `/appointments/{appointment_id}` | Bearer | — | `MessageResponse` |
| PATCH `/appointments/{appointment_id}` | Bearer | `AppointmentRequest` | `MessageResponse` |

### `auth.py` (10)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| POST `/auth/check-phone` | Công khai | `CheckPhoneRequest` | `CheckPhoneResponse` |
| POST `/auth/login` | Công khai | `LoginRequest` | `LoginResponse` |
| POST `/auth/register/send-otp` | Công khai | `SendOTPRequest` | `SendOTPResponse` |
| POST `/auth/register/verify-otp` | Công khai | `VerifyOTPRequest` | `VerifyOTPResponse` |
| POST `/auth/register` | Công khai | `RegisterRequest` | `MessageResponse` |
| POST `/auth/forgot-password/send-otp` | Công khai | `SendOTPRequest` | `SendOTPResponse` |
| POST `/auth/forgot-password/verify-otp` | Công khai | `VerifyOTPRequest` | `VerifyOTPResponse` |
| PATCH `/auth/forgot-password/reset` | Công khai | `ResetPasswordRequest` | `MessageResponse` |
| POST `/auth/refresh-token` | Công khai | `RefreshRequest` | `RefreshResponse` |
| POST `/auth/logout` | Công khai | `RefreshRequest` | `MessageResponse` |

### `chat.py` (3)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| GET `/chat/conversations` | Bearer | — | `ListConversationResponse` |
| GET `/chat/messages/{target_user_id}` | Bearer | — | `ListMessageResponse` |
| POST `/chat/messages` | Bearer | `ChatMessageRequest` | `ChatMessageResponse` |

### `device.py` (3)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| POST `/devices/` | Bearer | `RegisterDeviceRequest` | `RegisterDeviceResponse` theo khai báo · **Partial**, UUID/str |
| PATCH `/devices/{id_devices}` | Bearer | `UpdateDeviceRequest` | `MessageResponse` |
| DELETE `/devices/{id_devices}` | Bearer | — | `MessageResponse` |

### `interior.py` (1)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| GET `/interior` | Công khai | — | `ListAmenityResponse` (service trả `ListInteriorResponse` cùng shape) |

### `landlord.py` (4)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| POST `/landlords/profile` | Bearer | `CreateProfileRequest` | `ProfileResponse` |
| GET `/landlords/profile` | Bearer | — | `ProfileResponse` |
| POST `/landlords/profile/upload-avatar` | Công khai | multipart `image` | `ImageResponse` |
| PATCH `/landlords/profile` | Bearer | `UpdateProfileRequest` | `ProfileResponse` theo khai báo · **Partial**, client gửi `fullName` thay vì `full_name` |

### `notification.py` (2)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| GET `/notifications/` | Bearer | query `page` (bắt buộc) | `ListNotificationResponse` |
| PATCH `/notifications/{notification_id}/read` | Bearer | — | `MessageResponse` |

### `rental.py` (5)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| POST `/rentals/{room_id}/qr-code` | Bearer | — | `RentalResponse` |
| POST `/rentals/qr-code/verify` | Bearer | `RentalVerifyRequest` | `RentalVerifyResponse` |
| DELETE `/rentals/{rental_relation_id}` | Bearer | — | `MessageResponse` |
| GET `/rentals/` | Bearer | — | `CurrentTenantsResponse` |
| GET `/rentals/my-rooms` | Bearer | — | `MyRentedRoomsResponse` |

### `review.py` (4)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| GET `/reviews/{room_id}` | Công khai | — | `ListReviewResponse` |
| PATCH `/reviews/{review_id}` | Bearer | `ReviewUpdateRequest` | `ReviewResponse` |
| DELETE `/reviews/{review_id}` | Bearer | — | `MessageResponse` |
| POST `/reviews/{room_id}` | Bearer | `ReviewRequest` | `ReviewResponse` |

### `room.py` (9)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| GET `/rooms/locations` | Công khai | — | `ListLocationResponse` |
| POST `/rooms` | Bearer | `RoomRequest` | `RoomResponse` |
| POST `/rooms/images/upload` | Công khai | multipart `images[]`, `is_thumbnails[]` | `ListImageResponse` |
| GET `/rooms/me` | Bearer | — | `ListRoomResponse` |
| GET `/rooms/{room_id}` | Công khai | — | `RoomDetailResponse` |
| PATCH `/rooms/{room_id}/{status}` | Bearer | — | JSON `{Message: string}` |
| PATCH `/rooms/{room_id}` | Bearer | `RoomRequestUpdate` | `RoomDetailResponse` theo khai báo · **Partial**, thiếu service method |
| GET `/rooms/nearby/position` | Bearer tùy chọn | query `latitude`, `longitude`, `radius` | `ListRoomByPosition` |
| GET `/rooms/nearby/district` | Bearer tùy chọn | query `location_id`, `district`, `radius` (mặc định 10) | `ListRoomByDistrict` |

### `room_saved.py` (3)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| POST `/saved-rooms/{room_id}` | Bearer | — | `MessageResponse` (201) |
| GET `/saved-rooms/` | Bearer | — | `ListSavedRoomResponse` |
| DELETE `/saved-rooms/{room_id}` | Bearer | — | `MessageResponse` |

### `tenant.py` (4)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| POST `/tenants/profile` | Bearer | `CreateProfileRequest` | `ProfileResponse` |
| GET `/tenants/profile` | Bearer | — | `ProfileResponse` |
| POST `/tenants/profile/upload-avatar` | Công khai | multipart `image` | `ImageResponse` |
| PATCH `/tenants/profile` | Bearer | `UpdateProfileRequest` | `ProfileResponse` |

### `ws.py` (1)

| Method và path | Auth ở route | Body/query ngoài path | Response |
| --- | --- | --- | --- |
| WEBSOCKET `/ws/user/notifications` | Bearer handshake | — | JSON event từ server |

## Contract cần lưu ý

- `PATCH /landlords/profile` nhận `full_name` theo `schemas/landlord.py`. `FE ProfileRequestModel.toJson` gửi `fullName`, hợp lệ cho create và tenant update, nhưng field này bị cấm trong landlord update.
- `POST /devices/` dựng `RegisterDeviceResponse(id_device: str)` từ ORM UUID sau khi commit. Kiểm tra contract cùng `FE notification/data/models/notification.dart`, nơi app cần chuỗi ID để lưu và tiếp tục PATCH/DELETE. Probe cục bộ của service với UUID giả tái hiện lỗi Pydantic `string_type`.
- `GET /interior` khai báo `ListAmenityResponse`, còn `InteriorService.get_interiors` tạo `ListInteriorResponse`. Hai schema có cùng envelope `data` và item `id/name`.

## Khi thêm API

1. Khai báo path và `response_model` trong module phù hợp. Include router mới trong `app/api/router.py`. Đặt route tĩnh trước route động có thể match cùng method/segment. Kiểm tra status và envelope cho generated client.
2. Đưa input vào Pydantic schema với constraint phù hợp. Áp auth, role và object ownership phía server. Lấy actor từ Bearer. Chốt trạng thái lỗi cho UUID, dữ liệu không tồn tại, xung đột và lỗi provider.
3. Dùng `Depends(get_db)` qua factory. Xác định ranh giới transaction, thứ tự khóa và xử lý retry trước khi gọi dịch vụ ngoài. Commit nghiệp vụ trước realtime/Push, bảo toàn cách đọc lại khi delivery thất bại.
4. Nếu đổi schema vật lý, thêm migration và kiểm tra cả database đã có dữ liệu. Cập nhật Retrofit DTO, API inventory và sequence. Thử cả request từ caller thật và quyền truy cập.
