# 06 · Deployment

## Thành phần cần chạy

| Thành phần | Vai trò và trạng thái theo source |
| --- | --- |
| FastAPI/Uvicorn | **Implemented** entry point `BE app.main:app`. Cần chạy từ root Backend để đọc `.env` và service-account file theo đường dẫn tương đối. |
| MySQL | **Implemented** qua async SQLAlchemy/asyncmy và MySQL spatial functions. Cần schema cơ sở, migration head và dữ liệu catalog. Phiên bản và schema server đang chạy **Unknown**. |
| Redis | **Implemented** cho OTP và QR thuê. Redis server phải hỗ trợ `SET NX EX` và `GETDEL`. Cấu hình persistence/TLS/HA hiện **Unknown**. |
| Firebase, SMS, Cloudinary | **Implemented** adapter Backend. Firebase credential cần khi startup. SMS và Cloudinary được gọi theo nghiệp vụ. Tài khoản/quota, delivery và cấu hình server hiện **Unknown**. |
| Flutter | **Implemented** entry point `FE lib/main.dart`. Android có cấu hình Firebase, quyền location/camera/network/notification. FCM native Android là phạm vi có code support. Dịch vụ Goong cần cho autocomplete địa chỉ. |
| Reverse proxy, Docker, CI/CD, health/readiness, metrics | **Planned** theo roadmap. Không tìm thấy cấu hình deploy/CI hoặc app health route trong hai snapshot. Một URL HTTPS cố định trong Flutter là cấu hình client. Trạng thái host production **Unknown**. |

## Biến môi trường và file cấu hình

`BE core/config.py::Settings` đọc biến môi trường hoặc `.env`, phân biệt hoa thường. Tất cả field dưới đây là bắt buộc trong Settings. Quản lý giá trị bằng secret store hoặc file local có quyền đọc hạn chế.

| Biến Backend | Mục đích |
| --- | --- |
| `DATABASE_URL` | Async DSN MySQL cho app. Dùng dialect `mysql+asyncmy`. |
| `DB_ECHO` | Boolean bật SQL echo. Đặt false ở môi trường vận hành để tránh SQL và tham số trong log. |
| `REDIS_URL` | DSN Redis theo môi trường. |
| `JWT_SECRET` | Khóa ký/xác minh JWT. |
| `JWT_ALGORITHM` | Thuật toán PyJWT dùng để ký/xác minh. |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | TTL access token theo phút. |
| `REFRESH_TOKEN_EXPIRE_DAYS` | TTL refresh token theo ngày. |
| `CLOUDINARY_CLOUD_NAME` | Cloudinary cloud cho ảnh. |
| `CLOUDINARY_API_KEY` | ID xác thực Cloudinary. |
| `CLOUDINARY_API_SECRET` | Secret xác thực Cloudinary. |
| `SMS_BASE_URL` | Base URL nhà cung cấp SMS. Adapter nối `/sms/send`. |
| `SMS_ACCESS_TOKEN` | Credential gọi provider SMS. |

| Cấu hình ngoài Settings | Mục đích |
| --- | --- |
| `BE alembic.ini::sqlalchemy.url` | Async DSN riêng cho migration. `alembic/env.py` không lấy từ `DATABASE_URL`. File Git hiện có userinfo trong URL local. Dùng file cấu hình riêng được provision và đồng bộ database đích với app. |
| `BE secret/firebase-service-account.json` | `core/firebase.py` nạp credential từ đường dẫn này khi Firebase app chưa khởi tạo. Mount/provision file ngoài Git. Chỉ kiểm tra cách nạp credential. |
| `FE android/app/google-services.json` | Cấu hình Firebase client theo Android application ID, plugin Google Services xử lý ở build. Không dùng service-account file Backend cho app. |
| `FE GOONG_API_KEY` | Compile-time define được đọc trong `GoongPlacesApiService`. Có thể cấp bằng file local `places.local.json`, được ghi trong `.gitignore`. Key đưa vào build là client credential, cần giới hạn theo ứng dụng/quota. |
| `FE lib/core/constants/constants.dart::baseUrl` | URL API build cố định hiện dùng HTTPS. Không có biến define cho URL này trong source. `ChatWebSocketService` dùng cùng host, chuyển HTTPS→WSS và thay path bằng `/ws/user/notifications`. |

## Chạy Backend local

Chạy ở root Backend. Python 3.12 là phiên bản môi trường local từng tạo theo `.venv/pyvenv.cfg`. Virtualenv trong snapshot trỏ đến Python Store không khởi động được từ môi trường phân tích, nên tạo venv riêng cho môi trường cần chạy. Cấu hình đủ Settings, Firebase file, MySQL và Redis trước khi start.

```powershell
python -m venv venv
.\venv\Scripts\python.exe -m pip install -r requirements.txt
.\venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Swagger mặc định FastAPI ở `/docs`. Để app chạy được nghiệp vụ cần schema đã sẵn sàng và đúng DSN. Kiểm tra migration trước khi đưa traffic.

### Database migrations

Với **database hiện hữu**, xác nhận backup, revision và schema tương ứng baseline. Tạo cấu hình Alembic local ngoài Git, giữ `script_location` trỏ đúng thư mục migration và điền URL an toàn. Ví dụ dưới dùng `.env.alembic.ini`, khớp ignore pattern `.env.*`. Cần tự provision file này ở root Backend.

```powershell
.\venv\Scripts\python.exe -m alembic -c .env.alembic.ini heads
.\venv\Scripts\python.exe -m alembic -c .env.alembic.ini current
.\venv\Scripts\python.exe -m alembic -c .env.alembic.ini upgrade head
```

Head trong source là `130e66057c34`. Kiểm tra schema trước `upgrade`, gồm tình trạng index `room_images.public_id` trước revision `cbc71fc0ff5e`. Với **database trống**, source hiện thiếu baseline DDL. Cần schema baseline đã kiểm chứng hoặc tạo baseline migration hoàn chỉnh trước khi chạy chuỗi. `db/init_db.py` chỉ import 16 model và đã tạo index mà migration thêm lại, nên không ghép mù script này với `upgrade head`. Chỉ `stamp` sau khi chứng minh schema khớp revision tương ứng. Xem [chuỗi migrations và drift](04-DATABASE-DESIGN.md#alembic-và-bootstrap).

`.\venv\Scripts\python.exe -m db.seed` thêm amenity/interior bằng `add_all` và commit, dùng DSN app. Chỉ chạy khi catalog đích chưa seed, vì tên có unique constraint. Script không seed `locations.type='area'`. Danh mục khu vực cần nguồn dữ liệu riêng đã kiểm chứng.

### Redis, Firebase và Cloudinary

- Redis cần reachable từ Backend. Kiểm tra `PING` và hỗ trợ `GETDEL` trên môi trường đích. Cấp ACL/TLS phù hợp nếu dùng service từ xa, tách môi trường để OTP/QR không chia keyspace. Dữ liệu OTP có TTL 120 giây và QR 60 giây. Xem `RedisClient`, `AccountService`, `RentalService`.
- Firebase Admin startup cần file credential đọc được ở root Backend theo đường dẫn cấu hình hiện tại. Kiểm tra Firebase project của Android và của Backend khớp nhau. Kiểm tra POST device trả ID và gửi thử trên thiết bị sau khi xử lý contract ở [roadmap](07-TECHNICAL-DEBT-AND-ROADMAP.md).
- Cloudinary cần cloud và quyền upload/xóa ảnh. Hai folder lấy từ `core/cloudinary_custom.py`. Kiểm tra quota, loại ảnh, kiểm soát upload và cleanup trước public.
- SMS cần provider HTTPS và hợp đồng query/response khớp `core/sms_custom.py`. Kiểm tra quota và delivery trên môi trường thử nghiệm.

## Chạy Flutter local

Chạy ở root Flutter `Frontend/roomio`. Dùng Flutter phù hợp lockfile, Android SDK và JDK 17. Snapshot Android dùng Gradle 8.14, Android Gradle Plugin 8.11.1, Kotlin 2.2.20 và Google Services plugin 4.5.0, theo `android/gradle/wrapper/gradle-wrapper.properties`, `android/settings.gradle.kts`, `android/app/build.gradle.kts`.

```powershell
flutter pub get
flutter devices
flutter run -d <android-device> --dart-define-from-file=places.local.json
```

`places.local.json` cần có tên field `GOONG_API_KEY` và giá trị được cấp riêng. Có thể bỏ define nếu chỉ thử luồng không cần autocomplete Goong. Retrofit `*.g.dart` có sẵn trong source. Chỉ cần sinh lại khi đổi annotation/contract. Chạy mặc định sẽ trỏ đến base URL hiện có trong mã. Để trỏ tới Backend local, chọn cấu hình phát triển trong `constants.dart` trên checkout thử nghiệm. Chọn host mà thiết bị có thể truy cập. Dùng `10.0.2.2` với Android Emulator trên máy chạy Backend. Thiết bị thật cần địa chỉ LAN/tunnel và bind/firewall tương ứng. Catalog resolve path từ origin và WebSocket thay path tuyệt đối, nên triển khai dưới subpath cần kiểm thử hoặc điều chỉnh cả hai client này.

## HTTP/HTTPS và điều kiện production

- **Implemented** · Flutter dùng URL HTTPS cố định. WS tự đổi sang WSS. Android manifest chính cho phép cleartext. Backend CORS cho wildcard origins/methods/headers và credentials. Android build type release hiện ký bằng debug key. Xem `FE constants.dart`, `ChatWebSocketService`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts` và `BE app/main.py`.
- **Planned** · Chặn các P0 trước khi public. Cấp TLS ở reverse proxy, forward Upgrade/Authorization cho WS, tách origin và config từng môi trường, tắt cleartext ở release, thiết lập signing key. Đặt giới hạn body/rate, tránh log credential và bật backup/restore.
- **Planned** · Container hóa Backend sau khi baseline DB tái lập được. Pin runtime, mount secrets, chạy migration một lần như release job, readiness kiểm tra dependency thiết yếu và có lệnh rollback. Kiểm thử với MySQL/Redis tương thích. Một worker có thể dùng để kiểm tra WS hiện tại. Nhiều worker cần cơ chế fan-out/routing qua process. Không có bằng chứng topology production hiện tại.
- **Planned** · Smoke test trên database mới và database nâng cấp, Android login/refresh/logout, upload, chat WS, đăng ký thiết bị và Push cả foreground/background. Đo latency DB/FCM, log có correlation ID và thiết lập cảnh báo. Xem [roadmap](07-TECHNICAL-DEBT-AND-ROADMAP.md).
