# Màn hình và luồng nghiệp vụ

Đọc cùng [tiến độ](progress.md). Bảng này mô tả cách đi trong app và mục tiêu tích hợp; không xác nhận tất cả màn của mọi role đã dùng API.

## Màn thuộc phần Hào

| Màn / chức năng | File chính trong lib/ | Điểm vào | Ghi chú |
|---|---|---|---|
| Đăng nhập | screens/auth/auth_login.dart, auth_form.dart | Chưa có phiên hoặc đăng xuất | Người dùng hoặc chế độ ops; role do BE trả |
| Đăng ký | screens/auth/auth_register.dart, auth_form.dart | Từ đăng nhập | Chỉ role công khai theo BE |
| Khám phá | screens/bidder/bidder_home.dart | Tab Khám phá | Danh sách thật, tìm/lọc/sắp xếp/phân trang |
| Chi tiết phiên | screens/bidder/auction_detail_screen.dart | Bấm card hoặc thông báo phiên | Nhận auctionId, không phải listingId |
| Đặt cọc | screens/bidder/auction_join_panel.dart | Trong chi tiết phiên | Thiếu tiền mở Ví; quay về tải lại phiên |
| Đặt giá | screens/bidder/auction_bid_panel.dart | Trong chi tiết phiên | Amount VND tuyệt đối, BE quyết định hợp lệ |
| Báo cáo phiên | screens/bidder/auction_report_screen.dart | Nút báo cáo trong chi tiết | Report phiên khác với tranh chấp đơn |
| Ví | screens/bidder/bidder_wallet.dart | Tab Ví hoặc từ chi tiết | Số dư/lịch sử từ BE |
| Thông báo | screens/bidder/bidder_notifications.dart | Tab Thông báo/snackbar | Điều hướng theo data, không suy luận từ title |
| Hồ sơ | screens/auth/auth_profile.dart | Tab Hồ sơ | Giữ layout cũ; profile thật, tóm tắt đơn/địa chỉ |
| Chatbot | screens/customer/customer_chatbot.dart | Hồ sơ → Trợ lý hỗ trợ BidVibe | Session và câu trả lời từ BE |
| Sổ địa chỉ | screens/addresses/address_book_screen.dart | Hồ sơ → Quản lý địa chỉ giao hàng | Thêm/sửa/xóa/mặc định; selectionMode dùng lại cho đơn |

Các file `bidder_detail.dart`, `bidder_payment.dart`, `bidder_done.dart` cũ có thể vẫn tồn tại; không tự nối ID thật vào màn demo cũ. Kiểm tra repository và tham số màn trước khi sử dụng.

## Luồng bidder trước khi thắng

1. Đăng nhập/đăng ký → xác minh tài khoản bằng GET me → khung theo role.
2. Khám phá → mở phiên live → xem giá, bước giá, yêu cầu cọc.
3. Nếu cần, vào Ví và nạp thử qua BE → quay lại phiên.
4. Xác nhận đặt cọc → BE xác nhận joined/myDeposit → đặt giá hợp lệ.
5. Nhận cập nhật giá, bị vượt giá hoặc phiên kết thúc qua socket; tải lại BE để xác nhận trạng thái riêng.

Không kết luận thắng chỉ vì đồng hồ FE về 0. Dùng won/winnerId và trạng thái trả về từ BE.

## Luồng sau khi thắng — ghép với Hiệu

1. BE tự tạo đơn với trạng thái awaiting_payment, hạn thanh toán 24 giờ.
2. Bidder mở thông báo thắng hoặc Đơn hàng của tôi → chi tiết đơn bằng orderId.
3. Chọn địa chỉ đã lưu hoặc thêm trong sổ địa chỉ → POST shipping-address để gắn vào đơn.
4. Xem totalDue, depositApplied, amountToPay từ BE → xác nhận thanh toán.
5. Seller báo gửi về kho → kho nhận/kiểm định/đóng gói/gửi → bidder theo dõi.
6. Nhận hàng → kiểm tra → xác nhận; nếu có vấn đề thì tạo tranh chấp khi đủ điều kiện.

FE nên hướng dẫn chọn địa chỉ trước khi trả tiền. BE vẫn cho thanh toán khi chưa chọn địa chỉ, nhưng sẽ nhắc bổ sung và kho không gửi được. Có thể đổi địa chỉ của đơn trước khi kho gửi. Địa chỉ mặc định trong Hồ sơ không tự gắn vào mọi đơn.

Quá hạn thanh toán 24 giờ mất cọc theo BE. Sau khi giao, BE đặt mốc giải ngân 72 giờ; người mua xác nhận có thể giải ngân sớm, tranh chấp hợp lệ sẽ chặn giải ngân theo trạng thái BE. Hiển thị deadline/trạng thái thực, không tự thay đổi trạng thái bằng timer FE.

## Module của các thành viên khác

| Nhóm màn | Điểm cần kiểm tra | Phối hợp |
|---|---|---|
| Seller tạo/sửa tin | Draft → submit → thẩm định; ảnh và lý do bị từ chối/yêu cầu bổ sung | Hiệu + người nhận Appraiser |
| Seller đơn sau bán | Đã trả tiền → báo gửi về kho | Hiệu + người nhận Warehouse |
| Appraiser | Hàng chờ, chi tiết listing, quyết định theo quyền | Đề xuất Khang, nhóm cần chốt |
| Warehouse | Nhận → kiểm định → đóng gói → gửi → giao; nhánh mismatch | Đề xuất Khang, nhóm cần chốt |
| Admin | Cờ/report, tài khoản, tranh chấp, dashboard | Khang + Hào/Hiệu |

Quy tắc quyết định và trạng thái lấy từ docs BE. Khi chưa có endpoint cho một màn prototype, ghi rõ giới hạn thay vì dùng dữ liệu giả như dữ liệu thật.
