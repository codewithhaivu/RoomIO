# Tài liệu kiến trúc RoomIO

Phân tích ngày **10/11/2026**, múi giờ Asia/Saigon. Tài liệu mô tả mã trong hai checkout tại thời điểm phân tích, gồm các thay đổi đang có trong working tree Backend.

| Codebase | Thư mục gốc | Phiên bản được phân tích |
| --- | --- | --- |
| Backend | `C:/Users/84981/Desktop/nam_4_ki_1/Project/Backend` | HEAD `2123bc2ea8d678d973c0e808f9736ca0af4a5216` và working tree. Có thay đổi sẵn ở `app/api/router.py`, `app/api/v1/device.py`, `services/{appointment,chat,device}_service.py` và `test/{test_appointment,test_chat}.py`. |
| Frontend | `C:/Users/84981/Desktop/nam_4_ki_1/Project/Frontend/roomio` | `pubspec.yaml` khai báo `1.0.0+1`. Không có metadata Git truy cập được ở thư mục này hoặc các thư mục cha. SHA-256 của manifest gồm 252 tệp `lib/**/*.dart`, `pubspec.yaml` và `pubspec.lock` là `f2dc10f4d5b127a83d10fe6c1cc89491f55bac2a5b5c990448ad010f9b495393`. Manifest có một dòng `<sha256 thường>  <đường dẫn tương đối>` mỗi tệp, đường dẫn dùng dấu `/`, sắp xếp theo thứ tự ký tự, phân biệt hoa thường, nối bằng LF, mã hóa UTF-8 và không có LF cuối. |

## Mục lục

1. [Tổng quan hệ thống](01-SYSTEM-OVERVIEW.md)
2. [Kiến trúc Backend và danh mục endpoint](02-BACKEND-ARCHITECTURE.md)
3. [Kiến trúc Frontend và cách thêm feature](03-FRONTEND-ARCHITECTURE.md)
4. [Thiết kế dữ liệu, ERD và Alembic](04-DATABASE-DESIGN.md)
5. [Luồng xử lý và sequence diagrams](05-SYSTEM-FLOWS.md)
6. [Chạy local và chuẩn bị deployment](06-DEPLOYMENT.md)
7. [Technical debt và roadmap theo mức ưu tiên](07-TECHNICAL-DEBT-AND-ROADMAP.md)

## Phạm vi và quy ước

- **Implemented** — mã đã nối các thành phần cần thiết cho phạm vi được mô tả. Trạng thái này đánh giá source.
- **Partial** — đã có mã nhưng còn thiếu một nhánh, lỗi contract, giới hạn nền tảng hoặc thiếu phần kết nối giữa các thành phần.
- **Planned** — công việc đề xuất trong bộ tài liệu, chưa có bằng chứng triển khai.
- **Unknown** — source và cấu hình có thể kiểm tra chưa đủ để kết luận về trạng thái thực tế.
- Ký hiệu **BE** và **FE** chỉ đường dẫn tương đối với hai thư mục gốc trong bảng. Dùng symbol, endpoint và đường dẫn để tra cứu khi số dòng thay đổi.
- Inventory route lấy từ các decorator Python trong 15 router được include. Inventory bảng lấy từ `Base.metadata` sau khi import 19 model, không truy vấn database. Các luồng đối chiếu từ entry point, service/repository, Flutter DI, UI và client API. OpenAPI được dựng bằng cấu hình giả, không chạy lifespan, và xác nhận 59 operation HTTP. Hai lỗi contract device/profile được tái hiện với Pydantic và input giả. Bộ test async chưa chạy xong vì Python bị kẹt khi tạo socket loopback cho event loop trong sandbox Windows. Database đang chạy, dịch vụ ngoài, cấu hình hạ tầng và luồng trên thiết bị thật chưa được xác minh. Không cần đọc giá trị bí mật để lập tài liệu.

## Cập nhật cùng code

1. Khi sửa API, cập nhật method/path, auth, schema và mã lỗi trong tài liệu Backend. Đối chiếu annotation, generated client, model mapping và sequence liên quan.
2. Khi sửa model/migration, cập nhật bảng, ERD, quy trình nâng cấp và chạy migration thử trên database dùng một lần. Ghi riêng tình trạng metadata và schema thực tế nếu có chênh lệch.
3. Khi sửa DI, navigation, storage hay tích hợp ngoài, đối chiếu entry point và cấu hình theo môi trường trước khi đổi trạng thái feature.
4. Cập nhật ngày, commit hoặc fingerprint và tình trạng working tree. Giữ mỗi đề xuất trong roadmap kèm bằng chứng, ảnh hưởng và hướng xử lý. Dùng placeholder khi viết ví dụ cấu hình.
