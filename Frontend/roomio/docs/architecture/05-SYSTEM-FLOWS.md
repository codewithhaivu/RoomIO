# 05 · Luồng xử lý hệ thống

Các sequence dưới đây mô tả mã hiện có. API path giữ nguyên prefix và dấu gạch cuối. `FE` và `BE` theo [quy ước đường dẫn](README.md#phạm-vi-và-quy-ước). HTTP 422 do FastAPI validation có thể xuất hiện trước service khi body/path/query không đúng schema.

## 1. Đăng ký và đăng nhập · Partial

Bắt đầu ở `CheckPhonePage`. `POST /auth/check-phone` nhận `phone_number` và trả `exist`. Với số mới, Flutter chọn role, gửi và xác minh OTP, đặt password rồi vào luồng login. Hai API `/auth/forgot-password/{send-otp,verify-otp}` dùng cùng service và cùng Redis key theo phone. Màn reset gọi `PATCH /auth/forgot-password/reset` với phone/password.

```mermaid
sequenceDiagram
    actor U as Người dùng
    participant F as Flutter auth
    participant A as AccountService
    participant D as MySQL
    participant S as SMS provider
    participant R as Redis
    participant K as SecureStorage
    U->>F: Nhập số điện thoại
    F->>A: POST /auth/check-phone
    A->>D: Tìm account theo phone_number
    A-->>F: exist
    opt Chưa có tài khoản
        F->>A: POST /auth/register/send-otp
        A->>S: Gửi OTP 4 chữ số
        A->>R: SET theo phone, TTL 120 giây
        F->>A: POST /auth/register/verify-otp
        A->>R: GET theo phone
        A-->>F: is_verified
        F->>A: POST /auth/register với phone, password, role
        A->>D: INSERT account với bcrypt hash
        A-->>F: MessageResponse
    end
    F->>A: POST /auth/login với phone và password
    A->>D: Đọc account, kiểm tra password/state, lưu hash refresh
    A-->>F: access_token, refresh_token, role
    F->>K: Lưu token và role
    F->>A: GET /tenants/profile hoặc /landlords/profile
    A-->>F: ProfileResponse hoặc lỗi
    F-->>U: Home hoặc tạo hồ sơ
```

OTP sai/hết hạn trả `is_verified=false`. SMS provider báo fail có thể trả 502, lỗi transport chưa map riêng. Đăng ký trùng có thể trả HTTP 200 với `Register Fail`. `RegisterPasswordPage` vẫn hiển thị thành công nếu BLoC nhận `DataSuccess`. Reset số không tồn tại cũng trả message thất bại trong 200. Đăng nhập sai trả 401. Account khóa trả 403. Server đăng ký/reset trực tiếp nhận body hiện có, không kiểm chứng kết quả OTP hoặc tiêu thụ OTP sau xác minh. `BE services/account_service.py`, `repositories/account_repository.py`, `schemas/account.py`. `FE RemoteRegisterBloc`, `RemoteLoginBloc`, `LoginPage`.

## 2. Khôi phục phiên đăng nhập · Partial

Bắt đầu ở `MyApp` qua `CheckAuthStatusEvent`. Storage có access token thì mở Home và bắt đầu device sync. Refresh xảy ra khi một HTTP request nhận 401.

```mermaid
sequenceDiagram
    participant M as MyApp / RemoteAppAuthBloc
    participant K as SecureStorage
    participant I as AppInterceptor / Dio
    participant A as FastAPI
    participant D as MySQL
    M->>K: Đọc access_token
    alt Có access token
        M->>I: Home hoặc device sync gọi API
        I->>A: HTTP với Bearer
        alt API trả 401 và có refresh token
            I->>K: Đọc refresh_token
            I->>A: POST /auth/refresh-token
            A->>D: Kiểm tra account và hash refresh còn hiệu lực
            alt Refresh thành công
                A-->>I: access_token mới
                I->>K: Ghi access token
                I->>A: Thử lại request qua Dio độc lập
            else Refresh lỗi
                A-->>I: Lỗi refresh
                Note over I: 401 có thể tái nhập interceptor
                I->>K: Xóa token nếu đi đến nhánh cleanup
                I-->>M: Callback phát TokenExpiredEvent qua get_it
            end
        else Response khác hoặc thiếu refresh token
            A-->>I: Response hoặc lỗi, cleanup trực tiếp nếu 401 thiếu refresh
        end
    else Không có access token
        M->>M: Mở CheckPhonePage
    end
```

Refresh hết hạn/không hợp lệ/revoked trả 401, account khóa trả 403. Retry thất bại trả lại lỗi ban đầu. Nếu 401 mà thiếu refresh, client đi thẳng đến cleanup. Event từ callback có thể vào instance BLoC khác với UI. `FE lib/core/network/app_interceptor.dart`, `lib/injection_container.dart`, `RemoteAppAuthBloc.checkAuthStatus`. `BE AccountService.refresh_token`.

## 3. Tạo và cập nhật phòng · Partial

Bắt đầu ở `MyRoomsPage`/`RoomDetailPage`, mở `RoomFormPage`. Chọn vị trí bằng `RoomFormLocationCubit`, Goong Places hoặc reverse geocoding thiết bị, tải catalog `GET /interior` và `GET /amenitie`. Form gửi thông số phòng, giá/phí, tọa độ, UUID catalog và metadata ảnh. Ảnh mới được upload trước nếu có.

```mermaid
sequenceDiagram
    actor L as Chủ trọ
    participant F as Form / BLoC / RoomRepositoryImpl
    participant A as Router / RoomService
    participant D as MySQL
    participant C as Cloudinary
    L->>F: Lưu form tạo hoặc sửa
    opt Có ảnh mới
        F->>A: POST /rooms/images/upload
        A->>C: Upload và trả metadata
    end
    alt Đăng phòng mới
        F->>A: POST /rooms với RoomRequest và Bearer
        A->>D: Kiểm tra landlord, verify và catalog
        A->>D: Tìm hoặc tạo location, ghi room và liên kết
        alt Thành công
            A->>D: Commit
            A-->>F: RoomResponse
        else Lỗi trong khối ghi
            A->>D: Rollback
            A->>C: Thử xóa ảnh theo public_id từ body
            A-->>F: 500
        end
    else Sửa dữ liệu phòng
        F->>A: PATCH /rooms/{room_id} với RoomRequestUpdate
        A-->>F: 500 do thiếu RoomService.updateRoom
    end
    opt Thao tác đổi trạng thái riêng
        F->>A: PATCH /rooms/{room_id}/{status}
        A->>D: Kiểm tra landlord verified rồi cập nhật trạng thái
        A-->>F: JSON có trường Message
    end
```

Tạo thiếu landlord trả 404, chưa verify trả 403, catalog ID không hợp lệ trả 400. Đổi trạng thái trả 401 nếu thiếu quyền theo profile/verify, 404 nếu phòng không có. Chưa kiểm tra owner của room và nhận status chuỗi tự do. `BE app/api/v1/room.py`, `services/room_service.py`, `schemas/room.py`. `FE RemoteLandlordRoomBloc` và `RoomApiService`.

## 4. Upload ảnh phòng và avatar · Implemented

Bắt đầu khi submit form phòng hoặc form hồ sơ có file mới từ image picker. Room gửi multipart `images` và `is_thumbnails` lặp. Avatar gửi multipart `image` theo nhánh role. Kết quả là URL HTTPS và `public_id`, room có cờ thumbnail. Các upload route hiện công khai.

```mermaid
sequenceDiagram
    actor U as Người dùng
    participant F as Flutter form / Retrofit
    participant A as FastAPI
    participant C as Cloudinary
    participant D as MySQL
    U->>F: Chọn ảnh và submit
    alt Ảnh phòng
        F->>A: POST /rooms/images/upload
        loop Từng cặp file và cờ thumbnail
            A->>C: Upload vào thư mục ảnh phòng
            C-->>A: secure_url và public_id
        end
        A-->>F: ListImageResponse.response
        F->>A: POST /rooms hoặc PATCH phòng với metadata
    else Avatar
        F->>A: POST /tenants/profile/upload-avatar hoặc /landlords/profile/upload-avatar
        A->>C: Upload vào thư mục ảnh hồ sơ
        C-->>A: secure_url và public_id
        A-->>F: ImageResponse
        F->>A: POST hoặc PATCH profile với avatar URL
    end
    opt API ghi hỗ trợ và xử lý thành công
        A->>D: Lưu URL và metadata theo loại
    end
```

Sai multipart có thể trả 422. Room service dùng `zip` nên số phần tử lệch bị cắt theo list ngắn hơn. Nếu một lần upload trong batch thất bại, ảnh đã upload trước có thể còn trên Cloudinary. Room edit hiện không persist. Avatar mới của chủ trọ có thể upload xong nhưng PATCH hồ sơ bị 422 vì `fullName` khác `full_name`. `BE core/cloudinary_custom.py`, `RoomService.upload_images/postRoom`, `TenantService.upload_avatar`, `LandlordService.upload_avatar`. `FE RoomApiService` và hai profile API service.

## 5. Tìm kiếm phòng theo vị trí · Implemented với tenant có hồ sơ

Bắt đầu ở `SearchRoomsPage`. Người dùng chọn GPS, nhập địa chỉ để geocode trên thiết bị, hoặc chọn khu vực từ catalog Backend. Position nhận lat/lng/radius. District nhận `location_id`, nhãn `district` và radius. Cả hai trả room card, khoảng cách km và `is_saved`.

```mermaid
sequenceDiagram
    actor U as Người dùng
    participant F as SearchRoomsPage / RemoteTenantRoomBloc
    participant G as GPS / Geocoding
    participant A as RoomService
    participant D as MySQL
    U->>F: Chọn chế độ tìm và bán kính
    alt GPS hoặc địa chỉ
        F->>G: Lấy tọa độ hoặc danh sách ứng viên
        G-->>F: lat/lng
        F->>A: GET /rooms/nearby/position
    else Chọn khu vực
        F->>A: GET /rooms/locations
        A->>D: Đọc location type area
        A-->>F: Danh sách khu vực
        F->>A: GET /rooms/nearby/district
        A->>D: Đọc tọa độ tâm theo location_id
    end
    A->>D: Tìm tenant nếu có Bearer, tính khoảng cách, join thumbnail
    D-->>A: Sắp xếp theo khoảng cách và trạng thái đã lưu
    A-->>F: rooms và district nếu có
```

Lỗi có thể đến từ quyền GPS, service tắt, thiết bị/geocoder không hỗ trợ hoặc timeout. Khu vực không tồn tại trả 404. Không có JWT thì `is_saved=false`. JWT hợp lệ mà không có tenant có thể lỗi tại `tenant.id`, kể cả chủ trọ đi qua route tìm kiếm. Query không lọc riêng trạng thái còn trống. `FE RoomLocationDataSource` và `RemoteTenantRoomBloc`. `BE RoomService.searchRoomByPosition/searchRoomsByArea`, `RoomRepository.getRoomByPositionDistance`.

## 6. Lưu phòng yêu thích · Implemented

Bắt đầu khi khách thuê bấm bookmark ở kết quả tìm kiếm hoặc mở `SavedRoomsPage`. `SavedRoomsCubit` dùng cùng trạng thái giữa hai màn hình. API yêu cầu Bearer và hồ sơ tenant.

```mermaid
sequenceDiagram
    actor U as Khách thuê
    participant F as SavedRoomsCubit
    participant A as RoomSaveService
    participant D as MySQL
    alt Lưu
        U->>F: Bấm bookmark
        F->>A: POST /saved-rooms/{room_id}
        A->>D: Tạo hoặc kích hoạt row theo PK room và tenant
        A-->>F: 201 MessageResponse
    else Bỏ lưu
        U->>F: Bỏ bookmark
        F->>A: DELETE /saved-rooms/{room_id}
        A->>D: Đặt status inactive
        A-->>F: MessageResponse
    end
    F->>A: GET /saved-rooms/ khi tải danh sách
    A->>D: Join row active, phòng, địa điểm và thumbnail
    A-->>F: rooms
```

Thiếu tenant hoặc bỏ lưu bản ghi không tồn tại trả 404. Room ID chuỗi sai UUID và FK room không tồn tại chưa được map thành lỗi nghiệp vụ rõ ràng. Danh sách yêu cầu thumbnail. State app được reset khi phiên đổi. `BE services/room_save_service.py` và `repositories/room_save_repository.py`. `FE SavedRoomsCubit`, `SavedRoomsScope`, `SavedRoomApiService`.

## 7. Đặt lịch xem phòng · Implemented

Bắt đầu ở action đặt lịch từ chi tiết phòng. Form gửi `id_room` và `meet_at` đến `POST /appointments/`. Service chuẩn hóa về giờ Việt Nam dạng naive, bỏ microseconds, yêu cầu tương lai và kiểm tra conflict cùng thời điểm theo room hoặc tenant.

```mermaid
sequenceDiagram
    actor T as Khách thuê
    participant F as AppointmentFormPage / BLoC
    participant A as AppointmentService
    participant D as MySQL
    participant W as WebSocket chủ trọ
    participant P as Firebase Push
    T->>F: Chọn ngày giờ và gửi
    F->>A: POST /appointments/
    A->>D: Kiểm tra tenant, room, landlord và conflict
    A->>D: Ghi lịch PENDING và notification, commit
    opt Chủ trọ có socket
        A-->>W: appointment_created
    end
    A->>P: Push với type appointment và appointment_id
    A-->>F: AppointmentResponse
```

Quá khứ/giờ không hợp lệ trả 400, thiếu entity trả 404, trùng slot active trả 409. `GET /appointments/` list theo người tham gia, bỏ `CANCELLED`. Khách thuê đổi giờ qua `PATCH /appointments/{appointment_id}` hoặc hủy bằng DELETE khi `PENDING/CONFIRMED`. Đổi giờ quay về `PENDING`, không đổi phòng. Hủy chuyển `CANCELLED`. Hai nhánh này lưu inbox và phát WS best effort. `BE AppointmentService.send_appointment/update_appointment/destroy_appointment` và `AppointmentRepository`. `FE AppointmentFormPage`.

## 8. Xác nhận lịch hẹn · Implemented

Bắt đầu ở `AppointmentsPage` của chủ trọ. `PATCH /appointments/{appointment_id}/{status}` lấy ID/status từ path và xác định actor bằng Bearer.

```mermaid
sequenceDiagram
    actor L as Chủ trọ
    participant F as AppointmentsPage / BLoC
    participant A as AppointmentService
    participant D as MySQL
    participant W as WebSocket khách thuê
    participant P as Firebase Push
    L->>F: Xác nhận, từ chối hoặc hoàn tất
    F->>A: PATCH /appointments/{appointment_id}/{status}
    A->>D: Lock lịch và phòng, kiểm tra chủ sở hữu
    A->>D: Kiểm tra transition, giờ và conflict nếu cần
    A->>D: Ghi trạng thái và notification, commit
    opt Có socket khách thuê
        A-->>W: appointment_status_updated
    end
    opt Trạng thái CONFIRMED
        A->>P: Push với appointment_id
    end
    A-->>F: MessageResponse
```

`PENDING → CONFIRMED/REJECTED` và `CONFIRMED → COMPLETED` sau giờ hẹn. Lỗi 400 với status/giờ không hợp lệ, 404 với ID không có hoặc không thuộc chủ trọ, 409 với transition/xung đột. WS/FCM lỗi sau commit được log. Lịch/inbox đã lưu. `BE AppointmentService.confirm_appointment/_commit_and_notify`. `FE RemoteAppointmentBloc`.

## 9. Thuê phòng qua QR · Implemented

Bắt đầu khi chủ trọ tạo QR cho phòng của mình. Khách thuê scan hoặc nhập mã sáu chữ số. Mã đi trong body `{token}`. DB chỉ ghi quan hệ thuê sau verify.

```mermaid
sequenceDiagram
    actor L as Chủ trọ
    participant F as Flutter QR / Scan
    actor T as Khách thuê
    participant A as RentalService
    participant R as Redis
    participant D as MySQL
    L->>F: Tạo QR
    F->>A: POST /rentals/{room_id}/qr-code
    A->>D: Kiểm tra role LANDLORD, hồ sơ và owner
    A->>R: SET rental:qr:{token} NX EX 60
    A-->>F: qr_token và expires_in_second
    T->>F: Scan hoặc nhập mã
    F->>A: POST /rentals/qr-code/verify
    A->>D: Kiểm tra CUSTOMER và hồ sơ tenant
    A->>R: GETDEL mã dùng một lần
    A->>D: Lock room, kiểm tra owner và rental active cùng cặp
    A->>D: INSERT room_rentals active, commit
    A-->>F: id_valid=true và message
```

Sai/hết hạn/đã dùng trả 400. Role/owner sai 403. Thiếu entity 404. Quan hệ active trùng 409. Redis lỗi 503. Nếu DB lỗi sau `GETDEL`, người dùng cần mã mới. Luồng không đổi `rooms.status`. `GET /rentals/` trả khách đang thuê cho chủ trọ, `GET /rentals/my-rooms` trả phòng active cho tenant. DELETE do chủ trọ đổi quan hệ thành `deactivate`. `BE RentalService` và `RentalRepository`. `FE RentalQRCodePage`, `RentalScanPage`, `RentalVerifyPage`.

## 10. Chat qua REST/WebSocket · Partial cho realtime

Bắt đầu từ danh sách chat hoặc nút liên hệ chủ trọ trên chi tiết phòng. Target dùng UUID account. Client tải danh sách và lịch sử qua REST, mở một socket broadcast dùng chung ở màn chat. Người gửi dùng REST.

```mermaid
sequenceDiagram
    participant F as Flutter người gửi
    participant A as ChatService / REST
    participant D as MySQL
    participant W as WebSocket endpoint
    participant T as Flutter người nhận
    F->>A: GET /chat/conversations và /chat/messages/{target_user_id}
    A->>D: Tìm hội thoại và lịch sử
    A-->>F: data hoặc danh sách rỗng
    opt Người nhận đang ở chat
        T->>W: Bearer handshake /ws/user/notifications
        W-->>T: Kết nối nhận sự kiện
    end
    F->>A: POST /chat/messages với receiver_id, content, created_at, status, type
    A->>D: Khóa account, lấy/tạo conversation, ghi message, commit
    opt Socket người nhận có trong process
        A->>W: JSON type và data
        W-->>T: Message event
    end
    A->>A: Gọi Push với sender_id
    A-->>F: id_valid=true
    T->>A: GET /chat/messages/{target_user_id} khi mở/tải lại
```

Tự gửi, content rỗng/quá 500 ký tự, time/status/type sai trả 400. Receiver không tồn tại trả 404. Lỗi WS/Push sau commit không làm mất lịch sử. Tin nhắn lưu thời điểm từ client đã chuẩn hóa UTC, `conversations.updated_at` dùng thời gian server. Socket chỉ có một entry/account/process. REST dùng để tải lại khi mất realtime. Flutter chỉ map event `chat_message` trong `ChatRepositoryImpl`. Các sự kiện lịch qua socket không được đưa vào BLoC lịch hiện tại. `BE ChatService.send_message`, `ChatRepository`, `app/api/v1/ws.py`. `FE ChatBloc`, `ChatRepositoryImpl`, `ChatWebSocketService`.

## 11. Đăng ký thiết bị và nhận Firebase Push · Partial

Bắt đầu sau login/restore trên Android. App xin quyền, lấy FCM registration token, dùng `sub` để tìm ID thiết bị trong storage riêng. `POST /devices/` nhận `fcm_token/platform`, PATCH nhận token, DELETE bỏ thiết bị của account hiện tại.

```mermaid
sequenceDiagram
    participant F as Android / NotificationDeviceSync
    participant M as Firebase Messaging
    participant A as DeviceService / PushNotificationService
    participant D as MySQL
    participant N as PushNotificationNavigator
    F->>M: Xin quyền và lấy FCM token
    alt Đã lưu id_device
        F->>A: PATCH /devices/{id_devices}
        A->>D: Update theo device ID và account
    else Chưa có ID hoặc device đã mất
        F->>A: POST /devices/ với fcm_token và platform
        A->>D: Insert và commit user_device
        Note over A,F: Pydantic từ chối UUID ở id_device str sau commit
    end
    Note over A: Sau commit chat hoặc lịch, lấy thiết bị người nhận
    A->>D: SELECT user_devices theo account
    A->>M: Gửi notification và data
    M-->>F: Push foreground, background hoặc cold start
    F->>N: Khi người dùng mở Push
    N->>F: Điều hướng theo sender_id hoặc appointment_id
```

Nếu register trả lỗi, app không có ID để PATCH/DELETE lần sau. Trường hợp token refresh, queue app áp dụng PATCH hoặc đăng ký lại khi 404 với đúng detail. Push type `chat` có `sender_id`. Type `appointment` có `appointment_id`. Firebase báo token unregistered thì Backend xóa device. App đang ở đúng hội thoại thì có thể ẩn banner foreground. Inbox REST vẫn độc lập. `BE DeviceService`, `DeviceRepository`, `schemas/device.py`, `PushNotificationService`. `FE FcmService`, `NotificationDeviceSync`, `PushNotificationNavigator`.

## 12. Đăng xuất · Implemented cho revoke, Partial cho cleanup khi lỗi

Bắt đầu ở `HomePage._onLogout` sau xác nhận. UI lấy refresh token, phát `LogoutEvent`. BLoC chờ cleanup thiết bị rồi gửi refresh token trong body `POST /auth/logout`.

```mermaid
sequenceDiagram
    actor U as Người dùng
    participant H as HomePage / RemoteAppAuthBloc
    participant F as NotificationDeviceSync
    participant A as FastAPI
    participant D as MySQL
    participant K as SecureStorage
    U->>H: Xác nhận đăng xuất
    H->>K: Đọc refresh_token
    H->>F: unregisterSession
    opt Có id_device
        F->>A: DELETE /devices/{id_devices}
        A->>D: Xóa thiết bị theo account
    end
    F->>F: Hủy local notifications, xóa token FCM nếu cần
    H->>A: POST /auth/logout
    A->>D: Tra hash và revoke refresh token nếu có
    alt REST thành công
        A-->>H: MessageResponse
        H->>K: Xóa token/role, reset SavedRoomsCubit
        H-->>U: CheckPhonePage
    else REST lỗi
        H->>H: RemoteAppAuthErrorState, giữ storage phiên
        H-->>U: HomePage vẫn điều hướng CheckPhonePage
    end
```

Token không tìm thấy vẫn được Backend trả message thành công. Revoke áp dụng refresh, access JWT hiện hữu vẫn được chấp nhận theo TTL tại các route chỉ dựa trên JWT. Cleanup thiết bị có fallback revoke token cục bộ khi API xóa thất bại. `BE AccountService.logout`, `AccountRepository.revoked_refresh_token`. `FE HomePage._onLogout`, `RemoteAppAuthBloc.logout`, `NotificationDeviceSync.unregisterSession`.
