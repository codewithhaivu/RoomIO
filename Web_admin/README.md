# Trọ Admin

Admin Panel tiếng Việt cho backend FastAPI hiện có. HTML5, Bootstrap **5.3.3 qua CDN**, CSS riêng và Vanilla JavaScript; không cần npm hoặc bước build.

## Chạy giao diện

Mở terminal tại thư mục `Web_admin`:

```powershell
python -m http.server 5500 --bind 127.0.0.1
```

Truy cập **http://127.0.0.1:5500**. Không mở `index.html` bằng `file://`. Máy cần truy cập Internet để tải Bootstrap từ jsDelivr.

Trong **Cài đặt kết nối**, nhập Base URL backend, mặc định `http://127.0.0.1:8000`, rồi bấm **Lưu & kiểm tra kết nối**. Không thêm `/admin` vào cuối URL. Nếu triển khai API với tiền tố, có thể dùng URL dạng `https://example.com/api/v1`. Access token tùy chọn được gửi bằng header `Authorization: Bearer …`.

## Hai cấu hình backend cần bổ sung

Khi kiểm tra mã nguồn hiện tại, `app/api/router.py` **chưa include router admin** và `app/main.py` **chưa cấu hình CORS**. Vì vậy các endpoint admin chưa truy cập được từ giao diện cho đến khi bổ sung cấu hình này. Toàn bộ mã frontend nằm trong `Web_admin`; backend chưa bị chỉnh sửa.

**1. Thêm vào `Backend/app/api/router.py`:**

```python
from app.api.v1.admin import router as admin_router

api_router.include_router(admin_router)
```

**2. Cấu hình `Backend/app/main.py`:**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://127.0.0.1:5500", "http://localhost:5500"],
    allow_credentials=False,
    allow_methods=["GET", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Accept", "Content-Type", "Authorization"],
)
app.include_router(api_router)
```

Chạy backend từ thư mục `Backend` trong môi trường Python đã cài dependencies:

```powershell
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Kiểm tra `http://127.0.0.1:8000/docs` có nhóm **Admin**. Nếu dùng origin khác cho frontend, cập nhật `allow_origins` tương ứng. Nếu frontend và backend cùng origin qua reverse proxy thì không cần CORS. Trang HTTPS cần gọi backend HTTPS.

## Cấu trúc

```text
Web_admin/
├── index.html       # Sidebar, bảng, bộ lọc, phân trang, form và dialog
├── css/style.css    # Giao diện responsive desktop/tablet/mobile
├── js/api.js        # Fetch, Base URL, headers, timeout, lỗi và hợp đồng API
├── js/main.js       # DOM, điều hướng, trạng thái, xác nhận, render
├── README.md
└── tests/           # Kiểm tra API bằng Node.js và luồng UI bằng Playwright
```

## Hợp đồng API được sử dụng

Các đường dẫn bên dưới tương đối với Base URL. Admin API thực tế sử dụng **GET, PATCH, DELETE**; không có POST/PUT hoặc CRUD tạo/sửa thành viên, tạo/sửa phòng trong `admin.py`.

| Chức năng | Phương thức / endpoint | Query hoặc JSON body | Response |
| --- | --- | --- | --- |
| Danh sách thành viên | `GET /admin/members` | `page=1&limit=10` | `{ "data": [User] }` |
| Xác minh chủ trọ | `PATCH /admin/verify-landlord` | `{ "id_account": "UUID" }` | `{ "id_account": "UUID", "state": "verified" }` |
| Khóa tài khoản | `PATCH /admin/locked-user` | `{ "id_user": "UUID" }` | `{ "message": "…" }` |
| Phòng của chủ trọ | `GET /admin/rooms/{id_landlord}` | `page=1&limit=10` | `{ "rooms": [RoomResponse] }` hoặc `{ "rooms": null }` |
| Xóa một / nhiều phòng | `DELETE /admin/rooms` | `{ "data": ["UUID", "UUID"] }` | `{ "message": "…" }` |

`page >= 1`, `1 <= limit <= 100`. Payload gửi đúng các trường schema vì `BaseSchema` cấu hình `extra="forbid"`. DELETE gửi JSON body theo endpoint hiện có.

## Hành vi và giới hạn theo backend

- **Xác minh dùng ID tài khoản:** gửi `id_account` lấy trực tiếp từ trường `ID tài khoản (accounts.id)` trong modal chi tiết thành viên. Nút xác minh chỉ xuất hiện cho chủ trọ chưa được xác minh. Có thể xác minh từ nút ở hàng thành viên (ID điền sẵn, chỉ đọc) hoặc nhập UUID tài khoản trong form xác minh riêng.
- **Tra cứu phòng vẫn dùng ID hồ sơ chủ trọ:** `GET /admin/rooms/{id_landlord}` nhận `landlords.id`, khác `accounts.id`. API thành viên chưa trả ID này, nên giao diện tra cứu phòng vẫn yêu cầu nhập UUID hồ sơ chủ trọ.
- **Phân trang không có `total`:** dùng Trước/Sau; nút Sau bật khi trang trả đủ `limit` bản ghi. Trang kế tiếp có thể trống. Có thể quay lại trang trước. Không hiển thị tổng số trang hoặc tổng thành viên toàn hệ thống.
- **Thống kê, tìm kiếm, bộ lọc và danh sách chủ trọ chỉ áp dụng cho trang thành viên đã tải.** Không có endpoint tìm kiếm hoặc lọc toàn hệ thống. Muốn quản lý toàn bộ chủ trọ, duyệt các trang thành viên.
- `is_verify` của thành viên là chuỗi `"true"` / `"false"` hoặc `null`. Giao diện xử lý được cả boolean và chuỗi. Xác minh thành công tải lại danh sách từ backend để cập nhật trạng thái.
- Khóa tài khoản chuyển `state` sang `"not ok"`. API hiện không có mở khóa hoặc hủy xác minh; giao diện không tạo các thao tác này. Khóa và xóa cần xác nhận. Không có dữ liệu mẫu tự xuất hiện khi kết nối lỗi.
- Chi tiết phòng hiển thị vị trí và tọa độ, diện tích, loại, giá thuê, tất cả khoản phí, nội thất, tiện ích và ảnh. Chu kỳ/đơn vị phí điện nước không có trong schema nên không được tự suy đoán.
- Chọn nhiều phòng giới hạn trong trang hiện tại. Đổi trang, tải lại hoặc thay bộ lọc sẽ xóa lựa chọn để tránh xóa nhầm phòng bị ẩn. Backend xử lý cả lô trong một transaction. Xóa phòng cũng xóa các bản ghi liên quan theo repository hiện tại.
- Phản hồi 400/401/403/404/422/500, lỗi mạng/CORS, JSON sai và timeout 20 giây được hiển thị. Hủy yêu cầu cũ khi tải lại để tránh dữ liệu phản hồi muộn ghi đè trang mới. Khi xóa/khóa gặp timeout, tải lại để kiểm tra trạng thái trước khi thử lại vì backend có thể đã thực hiện thao tác.

## Dữ liệu và xác thực

Base URL được lưu trong `localStorage`; token được lưu trong `sessionStorage`, không lưu mật khẩu. `api.js` chỉ chuyển các trường thành viên cần thiết sang UI; trường `password` đang có trong response backend bị loại bỏ và không được render hoặc log.

Các endpoint admin hiện tại chỉ phụ thuộc `get_admin_service`; **chưa kiểm tra token hoặc vai trò admin ở backend**. Token tùy chọn trên frontend không thay thế kiểm soát quyền phía server. Trước khi triển khai công khai, cần thêm kiểm tra xác thực/phân quyền admin cho router và bỏ trường `password` khỏi response backend.

Không cần chạy migration hoặc thay schema để sử dụng frontend. Hai thay đổi đăng ký router/CORS bên trên chỉ là hướng dẫn tích hợp.

## Kiểm thử

Kiểm tra hợp đồng API, payload, loại bỏ mật khẩu, xử lý lỗi, hủy yêu cầu và timeout (Node.js 18+, không cần thư viện ngoài):

```powershell
node --test tests/api.test.cjs
```

Kiểm tra trình duyệt tùy chọn bằng Playwright. Toàn bộ API được giả lập, không đọc hoặc sửa dữ liệu backend thật:

```powershell
npm install --no-save playwright
$env:BROWSER_EXECUTABLE = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
node tests/browser-smoke.cjs
```

Có thể dùng đường dẫn Edge thay Chrome hoặc chạy `npx playwright install chromium` và bỏ biến `BROWSER_EXECUTABLE`. Bộ kiểm tra UI bao gồm tìm kiếm tiếng Việt, xác minh, xác nhận/hủy thao tác khóa, phân trang, xem phòng, xóa lô, thông báo lỗi, cài đặt token và bố cục mobile. Muốn lưu ảnh kiểm tra, đặt biến `ARTIFACT_DIR` tới thư mục đích. Nếu trình duyệt kiểm thử không truy cập được CDN, có thể đặt `BOOTSTRAP_CSS` tới bản CSS Bootstrap 5.3.3 đã tải sẵn; giao diện sản phẩm vẫn dùng CDN.
