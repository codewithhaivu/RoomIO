# Rental

- Home → Khách đang thuê (Landlord) / Phòng đang thuê (Tenant).
- Chi tiết phòng → Tạo mã thuê phòng (Landlord).
- Phòng đang thuê → Xác nhận thuê phòng → nhập 6 chữ số hoặc quét QR (Tenant).
- Quét QR chỉ điền mã; người thuê bấm xác nhận để tạo quan hệ thuê.
- QR hết hạn theo TTL từ API, tính cả thời gian chờ mạng; tạo lại mã khi cần.
- Windows/Linux dùng nhập mã thủ công; camera cần kiểm tra trên thiết bị Android/iOS/macOS.

## API đã đồng bộ

- POST /rentals/{room_id}/qr-code
- POST /rentals/qr-code/verify — request {"token":"012345"}, response {"message":"...","id_valid":true}.
- GET /rentals/ và GET /rentals/my-rooms đều trả {"data":[...]}.
- DELETE /rentals/{rental_relation_id} chỉ dành cho chủ trọ.

## Backend cần bổ sung để kết thúc thuê từ danh sách khách

GET /rentals/ hiện trả tenant_id và room_id nhưng chưa trả ID quan hệ thuê.
Thêm rental_id vào từng TenantRentalResponse, lấy từ RoomRental.id trong query.
Flutter đã đọc rental_id dạng nullable: khi có ID, nút Kết thúc thuê xuất hiện
và gửi DELETE với đúng ID quan hệ; khi thiếu, không dùng tenant_id hoặc room_id thay thế.

## Thư viện

- QR: https://pub.dev/packages/qr_flutter
- Camera scanner: https://pub.dev/packages/mobile_scanner
