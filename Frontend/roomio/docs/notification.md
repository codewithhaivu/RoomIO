# Notification

Đã nối Home → Thông báo → AppRoutes.notifications cho khách thuê và chủ trọ.

## REST

- GET /notifications/?page=1: nhận {"data": [...]} với notification_id, content, is_read, created_at.
- Backend phân trang cố định 10 bản ghi. Trang dưới 10 bản ghi kết thúc danh sách; nếu đúng 10, frontend cho phép tải tiếp.
- PATCH /notifications/{notification_id}/read: nhận {"message": "..."}.
- Retrofit được sinh lại bằng dart run build_runner build. Giữ các tên class API/model hiện có để tương thích code dự án.
- Timestamp backend lưu UTC; chuỗi không có offset được hiểu là UTC rồi chuyển giờ địa phương khi hiển thị.

## Luồng giao diện

- Thông báo mới nhất ở đầu, thông báo chưa đọc có màu nền và chấm đánh dấu.
- Chạm để xem đầy đủ nội dung trong bottom sheet và gọi PATCH đánh dấu đã đọc.
- Chỉ cập nhật isRead sau API thành công. Nếu thất bại, giữ chưa đọc và có thể mở lại để thử lại.
- Tải thêm khi gần cuối danh sách; có nút tải thêm nếu trang chưa đủ dài để cuộn.
- Có kéo làm mới, nút làm mới, tự tải lại trang đầu khi app quay lại foreground.
- Lỗi phân trang giữ nguyên dữ liệu, thử lại cùng trang. BLoC chống gọi PATCH/tải thêm trùng và bỏ qua response cũ sau refresh.
- Không có API đánh dấu tất cả; giao diện chỉ dùng chức năng backend hiện có.

## Phạm vi dữ liệu

Feature này hiển thị lịch sử thông báo được lưu ở backend qua REST, không mở thêm WebSocket.
Response notification chỉ có nội dung, trạng thái đọc và thời gian, nên chạm thông báo hiển thị nội dung thay vì suy đoán route phòng/lịch hẹn.
Backend lịch hẹn hiện lưu notification khi người nhận offline; khi online có socket, nó gửi event lịch hẹn trực tiếp và không lưu notification.
Do đó danh sách REST phản ánh các bản ghi backend đã lưu, không phải toàn bộ sự kiện realtime từng gửi.
Không thay đổi backend hoặc kết nối chat trong feature này.

## Kiểm thử

flutter test --no-pub test/features/notification

Kiểm thử payload/endpoint, phân trang, lỗi JSON/HTTP, timezone, dedup, response cũ, đọc thông báo đồng thời refresh,
điều hướng Home, thử lại khi lỗi, kéo làm mới, cuộn tải thêm và bố cục hẹp với chữ lớn/theme tối.
