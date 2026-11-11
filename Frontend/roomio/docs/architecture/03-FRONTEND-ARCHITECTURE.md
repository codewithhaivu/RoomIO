# 03 · Kiến trúc Frontend

## Tổ chức mã và ranh giới

`FE lib/main.dart` gọi `initializeDependencies()`, khởi tạo `FcmService` rồi chạy `MyApp`. `MaterialApp` dùng `AppRoutes.onGenerateRoute` và `PushNotificationNavigator`. `lib/core` chứa storage, interceptor, lớp kết quả và hạ tầng Firebase. `lib/config` chứa theme và route.

| Layer | Trách nhiệm và ví dụ |
| --- | --- |
| Presentation | Trang/widget gửi event hoặc gọi Cubit, đọc loading/data/error và điều hướng. `RemoteTenantRoomBloc` xử lý tìm kiếm, `RoomFormLocationCubit` xử lý địa chỉ, `SavedRoomsCubit` chia sẻ trạng thái yêu thích giữa các trang. |
| Domain | Entities, interface repository và use cases. `RoomRepository` tách khỏi `RoomRepositoryImpl`. Use case thường là wrapper một thao tác theo `lib/core/usecase/usecase.dart`. |
| Data | Retrofit API, generated code, JSON model, mapper, repository implementation và data source local. `RoomRepositoryImpl` đổi request entity thành model, gọi API rồi map `DataState`. `RoomLocationDataSource` bọc plugin thiết bị, `RoomCatalogApiService` và `GoongPlacesApiService` dùng Dio trực tiếp. |
| Application | `notification/application/notification_device_sync.dart` điều phối session, FCM token, thiết bị và cleanup ngoài UI. |

Đây là Clean Architecture theo feature với một số phụ thuộc xuyên layer. `core/resource/data_state.dart` mang `DioException` vào kiểu trả về dùng bởi domain. Chat dùng `Either<Failure, T>` từ dartz và một failure riêng trong `chat/domain/entities/chat.dart`. `AppInterceptor` và route gates lấy dependency qua `sl`, còn `RoomRouteGate` dựa vào access token và role trong storage. Các kiểm tra này phục vụ UX. Authorization thuộc Backend.

## 9 feature

| Thư mục dưới `lib/features/` | Entry point và trách nhiệm |
| --- | --- |
| `auth` | `CheckPhonePage`, `RemoteLoginBloc`, `RemoteRegisterBloc`, `RemoteForgotPasswordBloc` và `RemoteAppAuthBloc`. OTP, phiên, điều hướng từ login và `HomePage`. |
| `profile` | `CreateProfilePage`, `UpdateProfilePage` và `RemoteProfileBloc`. Chọn repository/use case tenant hoặc landlord, tải avatar rồi ghi hồ sơ. PATCH chủ trọ hiện lệch `fullName/full_name` giữa `ProfileRequestModel` và schema Backend. |
| `room` | `MyRoomsPage`, `RoomFormPage`, `SearchRoomsPage`, `RoomDetailPage`. BLoC/Cubit tách landlord, tenant, detail, catalog và vị trí. API room và catalog, Goong Places, geocoding. |
| `saved_room` | `SavedRoomsPage`, `SavedRoomsScope`, `SavedRoomsCubit`. Fetch, save, unsave và đồng bộ bookmark với kết quả tìm kiếm. |
| `appointment` | `AppointmentFormPage`, `AppointmentsPage`, `RemoteAppointmentBloc`. Action theo role và trạng thái, danh sách có thể lọc/focus theo args. |
| `rental` | `RentalsPage`, `RentalQRCodePage`, `RentalScanPage`, `RentalVerifyPage` và `RemoteRentalBloc`. Danh sách theo role, tạo/scan/xác nhận mã, chấm dứt quan hệ thuê. |
| `chat` | `ChatListPage`, `ChatPage`, `ContactLandlordButton`, `ChatBloc`. Hội thoại REST và receive-only WebSocket. |
| `notification` | `NotificationsPage`, `NotificationBloc`, `NotificationDeviceSync`. Inbox, đánh dấu đã đọc, đăng ký/đổi/hủy thiết bị. |
| `review` | `RoomReviewSection` được nhúng trong trang chi tiết, `ReviewBloc` theo room ID. Xem và thực hiện CRUD theo quyền Backend. |

## Dependency Injection, state và networking

- `lib/injection_container.dart::initializeDependencies` dùng get_it. Storage, Dio, API client, repository, use case và các adapter chia sẻ thường là lazy singleton. Các BLoC màn hình là factory. `RemoteProfileBloc` nhận role, `ChatBloc` nhận `ChatSession`, `ReviewBloc` nhận room ID qua factory param.
- `SavedRoomsCubit` là lazy singleton dùng chung. `SecureStorageService.onSessionChanged` gọi `reset()` khi đổi hoặc xóa phiên. `saveAccessToken` trong refresh giữ state của cùng phiên. `SavedRoomsScope` cung cấp instance đã có cho cây widget.
- Retrofit mô tả contract bằng `@RestApi`, `@GET`, `@POST`, `@PATCH`, `@DELETE`, `@Part` và sinh `*.g.dart`. `Dio` chung có connect/receive timeout 15 giây. `AppInterceptor.onRequest` đọc và gắn Bearer. `RoomCatalogApiService` dùng Dio chung để đọc `/amenitie`, `/interior`. Goong dùng Dio riêng 8 giây, không chuyển JWT RoomIO sang Goong.
- `RoomLocationDataSource` xin quyền GPS, dùng Geocoding theo locale `vi_VN` và có lỗi theo permission, service, platform, timeout. Goong autocomplete/detail dùng `GOONG_API_KEY`. `RoomFormLocationCubit` phối hợp việc chọn địa chỉ và reverse geocoding.
- `ChatWebSocketService` dùng `IOWebSocketChannel`, dẫn xuất WS/WSS từ base URL, mở với Bearer, dùng broadcast stream và đóng khi hết listener. `ChatRepositoryImpl` lọc event chat, `ChatBloc` có đường tải lại/subscription khi mất realtime. Đường gửi vẫn là REST. Khả năng chat trên trình duyệt chưa xác minh do adapter I/O hiện tại.
- Nhiều repository dùng `DataSuccess/DataError` và BLoC phát state tương ứng. Chat dùng failure riêng. Room và review có UI helper hiển thị lỗi. `FcmService`/`NotificationDeviceSync` ghi `debugPrint` ở các nhánh lỗi. Không thấy client telemetry tập trung hay cấu hình `LogInterceptor` trong DI.

## Authentication và routing

1. `RemoteLoginBloc.login` gọi REST, lưu access token, refresh token và role trong `FlutterSecureStorage`, rồi bắt đầu device session. `LoginPage` đọc hồ sơ theo role và điều hướng đến màn tạo hồ sơ hoặc Home.
2. `MyApp` tạo `RemoteAppAuthBloc`, phát `CheckAuthStatusEvent`. Chỉ cần access token tồn tại để vào Home. Backend xác thực token khi nhận request. Nếu access token vắng, mở `CheckPhonePage`.
3. Khi Dio nhận 401, interceptor gọi refresh qua cùng chuỗi API client, ghi access token mới và thử lại request một lần qua Dio mới. Chưa có loại trừ auth route/single-flight. Nếu refresh cũng 401 có thể tái nhập interceptor. Callback hết hạn gọi `sl<RemoteAppAuthBloc>()`, trong khi `registerFactory` tạo instance mới và UI giữ BLoC khác.
4. `HomePage` xác nhận logout, lấy refresh token hoặc chuỗi rỗng và phát `LogoutEvent`. `RemoteAppAuthBloc.logout` hủy đăng ký thiết bị trước, gọi revoke, xóa storage khi thành công. Lỗi chuyển sang `RemoteAppAuthErrorState`. `HomePage` vẫn điều hướng về `CheckPhonePage` sau cả hai kết quả.
5. `AppRoutes` dùng Navigator 1.0 và `MaterialPageRoute`. `RoomRouteGate` đọc storage, áp `landlordOnly/tenantOnly` khi route yêu cầu. `ChatSessionGate` giải mã `sub` cục bộ để xác định account hiện tại. Route detail, appointment, rental và chat có validation arguments riêng. Nhiều route auth dùng cast `Map<String, dynamic>`.

## Firebase Messaging

- `FcmService.isSupported` giới hạn Android native. Khởi tạo Firebase dựa vào cấu hình Android. Service xin quyền, lấy token, nghe token refresh, dùng channel `roomio_push` và local notification khi foreground. Background có handler khởi tạo Firebase. Notification payload do Android hiển thị theo trạng thái hệ điều hành.
- `NotificationDeviceSync` lưu ID thiết bị theo JWT `sub` ở namespace Android riêng `roomio_push_devices`. Sau login/restore, nó PATCH nếu có ID, POST nếu chưa có hoặc Backend trả đúng lỗi thiết bị không tồn tại. Queue và session identity hạn chế race với logout/token refresh. Luồng vẫn phụ thuộc lỗi contract UUID/str ở Backend.
- `PushNotificationNavigator` nhận notification đã mở/cold-start/local tap, chờ resolve startup rồi mở chat hoặc lịch hẹn. Chat tap tải danh sách hội thoại và fallback inbox chat khi chưa tìm thấy. Foreground ẩn banner khi đang xem đúng hội thoại. `NotificationBloc` lấy inbox qua REST, độc lập với Push.

## Khi thêm feature

1. Đối chiếu API thực và xác định entity, kiểu kết quả, interface repository, use case. Ghi rõ contract đối với UUID, snake_case, timezone, trường optional, envelope và mã lỗi.
2. Thêm API/data source, DTO/mapping và repository implementation. Với Retrofit, chạy `dart run build_runner build --delete-conflicting-outputs` ở root Flutter và kiểm tra generated path/body/query.
3. Đăng ký dependency theo vòng đời trong `injection_container.dart`. Factory cho state theo màn hình. Singleton chỉ khi thật sự chia sẻ state/transport và đã có cleanup.
4. Nối BLoC/Cubit với page, route argument và gate phù hợp trong `app_route.dart`. Kiểm tra cả entry point từ Home, deep link/Push nếu có, và hành vi logout.
5. Thử success, empty, validation, 401/403, timeout/retry và các nhánh từ thiết bị hoặc dịch vụ ngoài. `test/features` có mẫu cho repository, DI, BLoC/Cubit, widget, notification và WebSocket giả.
