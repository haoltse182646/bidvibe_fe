# API FE đang dùng và phần chờ nối

Nguồn gốc hợp đồng: `docs/api.md`, `docs/socket.md`, `docs/bidvibe.postman_collection.json`, `docs/bidvibe.postman_environment.json` trong source BE được cung cấp. Dùng docs BE để tra toàn bộ body, enum và lỗi. Bảng này là bản đồ tích hợp FE, không phải bản thay thế đặc tả BE.

## Quy ước

- ApiClient.baseUrl chỉ chứa địa chỉ gốc; từng path đã có /api. Socket dùng baseUrl gốc.
- Token từ đăng nhập hiện tại, header Authorization: Bearer token. Không dùng biến Postman như token_bidder làm chuỗi token trong Flutter.
- Đọc wrapper success/data/error tại ApiClient. Không coi status 200 đơn lẻ là bằng chứng đầy đủ nếu phản hồi dữ liệu không hợp lệ.
- ID từ BE thường được chuẩn hóa String trong FE. Phân biệt accountId, listingId, auctionId, orderId, disputeId và addressId.
- Các endpoint sau đã có trong bộ code Hào; trạng thái merge xem progress.md.

## API đã tích hợp trong phần Hào

| Màn / module | Method và endpoint | Khi gọi / dữ liệu chính |
|---|---|---|
| Đăng nhập | POST /api/auth/login | Email/password cho người dùng |
| Đăng nhập ops | POST /api/auth/ops/login | Chế độ nhân viên/quản trị |
| Đăng ký | POST /api/auth/register | Thông tin tài khoản, role được BE cho phép |
| Hồ sơ/xác minh phiên | GET /api/me | Sau auth, restore và tải Hồ sơ |
| Hồ sơ | PATCH /api/me | Chỉ trường đổi: fullName, phone, avatarUrl; shopName cho seller |
| Mật khẩu | POST /api/me/password | currentPassword/newPassword; giữ nguyên khoảng trắng của mật khẩu |
| Avatar | POST /api/uploads/images?purpose=avatar | Multipart files; nhận URL rồi PATCH me khi lưu |
| Danh mục | GET /api/categories | Code/name từ BE |
| Khám phá | GET /api/auctions | Tìm kiếm, status/category/sort và limit/offset theo repository |
| Chi tiết phiên | GET /api/auctions/:id | Giá, trạng thái, cọc, lượt giá, won/leading và dữ liệu riêng |
| Ví | GET /api/wallet | balance/held/available; không trừ held lần nữa khỏi available |
| Giao dịch ví | GET /api/wallet/transactions | limit/offset; lấy total từ BE |
| Nạp ví | POST /api/wallet/topup | Chỉ amount nguyên; BE mô phỏng nạp |
| Tham gia/cọc | POST /api/auctions/:id/join | Không body; BE quyết định số cọc |
| Đặt giá | POST /api/bids | auctionId và amount tuyệt đối; không gửi đồng thời increment |
| Báo cáo phiên | POST /api/auctions/:id/report | reason và note tùy chọn; xử lý ALREADY_REPORTED |
| Danh sách thông báo | GET /api/notifications | limit/offset; unreadCount của toàn tài khoản, không có total |
| Đọc thông báo | POST /api/notifications/:id/read | Không body; khi chọn thông báo chưa đọc |
| Đọc tất cả | POST /api/notifications/read-all | Không body; chỉ khi bấm nút đọc tất cả |
| Hồ sơ, tóm tắt đơn | GET /api/orders/mine | Đọc đơn gần nhất; chưa thay cho chi tiết/thanh toán |
| Sổ địa chỉ | GET /api/addresses | Địa chỉ mặc định đứng đầu |
| Thêm địa chỉ | POST /api/addresses | recipientName, phone, addressLine, city; ward/district/isDefault tùy chọn |
| Sửa địa chỉ | PATCH /api/addresses/:id | Chỉ trường đổi; có thể nhận ID mới từ BE |
| Mặc định | POST /api/addresses/:id/default | Không body; không gửi isDefault thay cho endpoint này trong PATCH |
| Xóa địa chỉ | DELETE /api/addresses/:id | Không body; cần xác nhận UI và kiểm tra deleted=true |
| Gửi chat | POST /api/chat/messages | content; sessionId khi tiếp tục hội thoại |
| Lịch sử chat | GET /api/chat/sessions/:id/messages | Khi mở lại hoặc tải lại session thuộc tài khoản |

Sổ địa chỉ mới đang chờ Hào xác nhận ghép/test local sau lỗi import. Chat không có API liệt kê/xóa session trong BE được cung cấp. Không tự thêm API giả để gọi.

## API cần Hiệu tích hợp/nối vào module thật

| Chức năng | Endpoint chính | Điểm bàn giao |
|---|---|---|
| Danh sách và chi tiết đơn thắng | GET /api/orders/mine; GET /api/orders/:id | Mở bằng orderId; tóm tắt Hồ sơ chỉ là điểm vào |
| Gắn địa chỉ vào đơn | POST /api/orders/:id/shipping-address | Body addressId từ ShippingAddress.id |
| Thanh toán | POST /api/orders/:id/pay | method theo BE; wallet thật trong hệ thống, qr/card mô phỏng |
| Theo dõi/xác nhận | GET /api/orders/:id/tracking; POST /api/orders/:id/confirm-delivery | Xác nhận không body; kiểm tra trạng thái và quyền |
| Seller | Nhóm /api/listings và /api/uploads/images | Tạo/sửa/ảnh/submit/resubmit theo docs BE |
| Đơn đã bán | GET /api/orders/selling; POST /api/orders/:id/ship-to-warehouse | Seller thao tác đúng đơn, đúng giai đoạn |
| Tranh chấp người dùng | POST /api/disputes; GET /api/disputes/mine | Dùng orderId; màn nhận disputeId để tìm đúng tranh chấp |

Chưa có bằng chứng các endpoint này đã được tích hợp trên nhánh riêng Hiệu; cần người phụ trách cập nhật tiến độ. Địa chỉ trong sổ và shippingAddress của đơn phải được phân biệt rõ.

## Admin/ops

Khang phụ trách xác nhận các API Admin trong task K01–K04. Nhóm Appraiser/Warehouse K05–K06 đang là phân công đề xuất. Dùng nhóm endpoint /api/admin, /api/appraisals, /api/warehouse trong BE theo role; không cho giao diện bidder tự gọi endpoint nội bộ.

## Socket

| Sự kiện | Chiều | Hành vi FE |
|---|---|---|
| auction:join | FE → BE | Vào phòng phiên để nhận thay đổi; không đặt cọc |
| auction:leave | FE → BE | Rời phòng khi đóng màn |
| auction:update | BE → FE | Cập nhật giá/thời gian/trạng thái; đồng bộ GET chi tiết |
| auction:ended | BE → FE | Tải lại kết quả; không tự đoán người thắng |
| notification:new | BE → FE | Cập nhật list/badge, snackbar; điều hướng theo data |
| account:disconnected | BE → FE | Dừng kết nối và xử lý đăng xuất theo lý do |

Đặt giá qua REST, không emit sự kiện đặt giá tự nghĩ ra. Khi reconnect, vào lại phòng cần thiết và GET lại dữ liệu bỏ lỡ.

## Lỗi cần thể hiện rõ

| Nhóm | Ví dụ | Hành vi |
|---|---|---|
| Phiên đăng nhập | UNAUTHORIZED, ACCOUNT_SUSPENDED | Dừng nghiệp vụ/socket, xử lý đăng xuất |
| Quyền/đối tượng | FORBIDDEN, NOT_FOUND | Giải thích và dừng thao tác không hợp lệ |
| Đặt giá/cọc | INSUFFICIENT_FUNDS, BID_TOO_LOW, ALREADY_LEADING, DEPOSIT_REQUIRED, AUCTION_PAUSED, AUCTION_ENDED | Hiện lỗi phù hợp, đồng bộ lại trạng thái |
| Thanh toán | ALREADY_PAID, PAYMENT_EXPIRED | Hiển thị theo đơn mới nhất; không báo thanh toán lại |
| Địa chỉ của đơn | ALREADY_SHIPPED | Không cho rằng đã đổi shippingAddress |
| Ghi không rõ kết quả | TIMEOUT, NETWORK, INVALID_RESPONSE | Không tự gửi lại; hướng dẫn kiểm tra trạng thái/lịch sử |

Không tự thêm endpoint logout/refresh, OTP hoặc danh sách thiết bị khi chưa có trong BE. Đăng xuất hiện là xóa phiên local.
