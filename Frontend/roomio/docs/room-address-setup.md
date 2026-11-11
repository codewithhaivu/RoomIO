# Cấu hình địa chỉ phòng bằng Goong V2

## Phân tích luồng và phạm vi thay đổi

Luồng chủ trọ: `RoomLocationPicker` → `RoomFormLocationCubit` →
`AutocompleteRoomAddressUseCase` / `ResolveRoomPlaceUseCase` →
`RoomPlacesRepository` → `RoomPlacesRepositoryImpl` → `GoongPlacesApiService`.

- Tái sử dụng `RoomPlaceSuggestion`, `LocationEntity`, repository interface,
  hai UseCase và các lớp Params, Cubit/State, kiểm tra form và giao diện hiện có.
- Feature này dùng Cubit nên không có lớp Event autocomplete riêng. Event đăng/sửa
  phòng trong `RemoteLandlordRoomBloc` tiếp tục nhận location như trước.
- Giữ debounce 350 ms, ít nhất 3 ký tự sau trim, loading, empty/error/retry,
  tối đa 5 gợi ý và `_revision` để bỏ response đã cũ (cả autocomplete và detail).
- Thay service Dio riêng và cách đọc JSON trong repository. Tiếp tục dùng Dio
  trực tiếp như service cũ; không thêm abstraction, package hay codegen Retrofit.
- Bỏ session token và các header package/SHA-1/field mask dành riêng cho dịch vụ cũ.
- Bỏ phép chẩn đoán dịch vụ cũ ở `main.dart`; startup không tự gọi autocomplete.
- Nhãn nguồn gợi ý đổi thành Goong Maps; không tích hợp hoặc chỉnh SDK bản đồ.
- Luồng tenant vẫn dùng geocoding/geolocator và backend tìm phòng như trước.

## API và dữ liệu

Dio dùng riêng, không lấy instance có interceptor Authorization của backend Roomio.

- `GET https://rsapi.goong.io/v2/place/autocomplete`
  với `api_key`, `input`, `limit=5`.
- `GET https://rsapi.goong.io/v2/place/detail`
  với `api_key`, `place_id` lấy từ gợi ý đã chọn.

Goong V2 cung cấp dữ liệu địa chỉ Việt Nam và đơn vị hành chính mới. Không truyền
tham số quốc gia hoặc ngôn ngữ không được tài liệu API V2 hỗ trợ; không ép bán kính
về một thành phố cố định. Có thể bổ sung location bias nếu sản phẩm cần sau này.

Repository đọc `predictions[].place_id` / `description` và
`result.formatted_address` / `result.geometry.location.lat` / `lng`.
Nó chuyển dữ liệu sang các Entity hiện có, kiểm tra tọa độ hợp lệ và xử lý cả
HTTP error, network/timeout lẫn API status lỗi trong HTTP 200.

`LocationModel.fromEntity/fromJson/toJson`, `PostRoomRequestModel.toJson` và
`UpdateRoomRequestModel.toJson` giữ nguyên. Không thêm model riêng chỉ để bọc JSON.
Backend FastAPI tiếp tục nhận:

```json
{
  "location": {
    "name": "Địa chỉ đã chọn",
    "latitude": 10.85,
    "longitude": 106.75
  }
}
```

Không gửi `place_id` hay Goong API key cho backend. Khi sửa lại ô địa chỉ, tọa độ
đã chọn bị xóa và phải xác nhận địa chỉ mới trước khi đăng/lưu phòng.
GPS và reverse geocoding hiện tại vẫn dùng geolocator/geocoding của thiết bị.

## Cấu hình key và chạy app

Đăng ký tài khoản Goong, tạo **API Key** cho REST API (khác Maptiles Key).
Sao chép `places.example.json` thành `places.local.json` nếu chưa có, rồi điền:

```json
{
  "GOONG_API_KEY": "YOUR_GOONG_API_KEY"
}
```

`places.local.json` đã có trong `.gitignore`. File local đã được chuyển sang cấu
hình Goong; nếu chưa có key thì để trống. Không commit key thật. Thiếu key được
chuyển thành trạng thái chưa cấu hình, không gửi request và không làm app crash.

Từ thư mục `Frontend/roomio`:

```powershell
flutter run -d 32011a625a0b2627 --dart-define-from-file=places.local.json
```

Thay device ID theo `flutter devices` nếu cần. Khi thay key, dừng phiên chạy cũ
và chạy lại để biên dịch dart-define; hot reload không cập nhật giá trị này.

Key được nhúng trong bản Flutter vẫn có thể bị trích xuất. Áp dụng giới hạn key
phù hợp với các loại URL/IP mà Goong hỗ trợ; không mặc định Goong có cơ chế
package/SHA-1 giống SDK Android khác. Khi cần bảo vệ key và kiểm soát quota phía
server, dùng backend proxy có xác thực. Không ghi toàn bộ URI, query parameters
hoặc DioException chứa `api_key` vào log; không chia sẻ key qua chat hoặc Git.

## Kiểm tra tự động

```powershell
flutter test --no-pub test/features/room
flutter analyze --no-pub
```

Kết quả kiểm tra khi chuyển đổi: **118 test Room thành công**; phân tích riêng
14 file Dart thay đổi không có vấn đề. Phân tích toàn dự án không có error hoặc
warning, còn một lint mức info có sẵn ở `room_api_service.g.dart:73`
(`avoid_function_literals_in_foreach_calls`). File Retrofit generated đó không
được sửa trong lần chuyển đổi này. `flutter analyze --no-pub --no-fatal-infos`
trả exit code 0.

APK Android debug cũng đã build thành công bằng:

```powershell
flutter build apk --debug --no-pub --dart-define-from-file=places.local.json
```

Bản build này dùng cấu hình local chưa có Goong key thật; xác nhận biên dịch,
không xác nhận request live.

Các test dùng Dio giả lập, không gọi dịch vụ tính phí:

1. Dưới 3 ký tự không gọi API; từ 3 ký tự chờ đủ 350 ms mới gửi request.
2. Đọc đúng Goong V2 predictions, giới hạn 5 gợi ý và bỏ mục không hợp lệ.
3. Chọn đúng place_id; Place Detail cập nhật tên, latitude và longitude.
4. Địa chỉ Goong được serialize đúng ở request POST/PATCH backend hiện có.
5. ZERO_RESULTS hoặc predictions rỗng hiển thị trạng thái không có kết quả.
6. HTTP 401/403/429/500, API status lỗi, mất mạng, timeout và JSON thiếu/sai dữ
   liệu đều trở thành lỗi có thể xử lý; giao diện có nút Thử lại.
7. Response thành công hoặc lỗi của truy vấn cũ không ghi đè kết quả mới.
8. Sửa địa chỉ làm mất hiệu lực tọa độ cũ; response detail muộn không phục hồi nó.
9. Kiểm tra hồi quy luồng tenant, GPS và các form Room hiện có.

## Kiểm tra thủ công khi đã có Goong API Key

1. Điền key thật trong file local và chạy lệnh Flutter phía trên.
2. Mở form đăng phòng; nhập 1–2 ký tự rồi gõ tên đường từ 3 ký tự trở lên.
3. Gõ nhanh nhiều từ khóa; kiểm tra loading và gợi ý dưới ô nhập (tối đa 5 mục).
4. Chọn gợi ý; ô nhập hiển thị địa chỉ xác nhận và dòng đã xác định vị trí phòng.
5. Điền đủ thông tin/ảnh, đăng phòng trên môi trường kiểm thử; kiểm tra payload
   location ở backend có đúng name/latitude/longitude, không có field mới.
6. Thử địa chỉ không có kết quả, ngắt kết nối mạng hoặc dùng key sai trong bản
   thử nghiệm; kiểm tra thông báo lỗi và Thử lại, không crash.
7. Sửa địa chỉ đã chọn; kiểm tra form yêu cầu chọn lại trước khi gửi.

Chưa có Goong API Key thật thì chưa xác nhận được hạn mức, quyền key và kết quả
request live. Test giả lập không thay thế bước kiểm tra thủ công này.

## Danh sách thay đổi

Thêm:
- `lib/features/room/data/data_sources/remote/goong_places_api_service.dart`
- `test/features/room/goong_places_repository_test.dart`
- `test/features/room/goong_test_data.dart`
- `places.example.json`

Sửa:
- `lib/features/room/data/repository/room_places_repository_impl.dart`
- `lib/features/room/domain/repository/room_places_repository.dart`
- `lib/features/room/domain/usecases/landlord/autocomplete_room_address.dart`
- `lib/features/room/domain/usecases/landlord/resolve_room_place.dart`
- `lib/features/room/presentation/bloc/remote/landlord/room_form_location_cubit.dart`
- `lib/features/room/presentation/widgets/room_location_picker.dart`
- `lib/injection_container.dart`
- `lib/main.dart`
- `test/features/room/room_places_test_support.dart`
- `test/features/room/room_form_location_cubit_test.dart`
- `test/features/room/room_pages_test.dart`
- `docs/room-address-setup.md`
- `places.local.json` (file local được Git ignore)

Xóa:
- `lib/features/room/data/data_sources/remote/google_places_api_service.dart`
- `test/features/room/room_places_repository_test.dart` (thay bằng test Goong)
- `docs/places-api-diagnostics.md` (tài liệu chẩn đoán dịch vụ đã bỏ)

Không cần thay đổi dependency trong pubspec.yaml: service cũ dùng Dio có sẵn,
không có package Places SDK riêng để gỡ.

## Tài liệu chính thức

- Autocomplete V2: https://help.goong.io/kb/rest-api-v2/autocomplete-rest-api-v2/autocomplete-v2/
- Place Detail V2: https://help.goong.io/kb/rest-api-v2/place-detail-rest-api-v2/place-detail-place-detail-v2/
- Giới hạn key: https://help.goong.io/
