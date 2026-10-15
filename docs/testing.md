# Kiểm thử FE và các luồng ghép nhóm

## Ba mức kiểm tra

1. Analyzer: kiểm tra lỗi code/lint trên nhánh hiện tại.
2. API/widget test: dùng HTTP/socket giả lập, không cần BE hoặc máy ảo.
3. Kiểm thử thủ công nhiều role: dùng BE thật và dữ liệu thử nghiệm chung, đối chiếu Postman.

Test tự động đạt không thay cho mức 3. Khi báo kết quả, ghi rõ mức kiểm tra, nhánh/commit, ngày, môi trường và giới hạn.

## Lệnh cơ bản

```powershell
flutter pub get
flutter analyze
```

Test từng nhóm:

```powershell
flutter test test/auction_repository_test.dart test/auction_detail_test.dart test/auction_join_test.dart test/auction_bidding_test.dart test/auction_report_test.dart
flutter test test/wallet_api_test.dart test/notification_api_test.dart test/notification_shell_test.dart
flutter test test/profile_api_test.dart test/profile_screen_test.dart test/chat_api_test.dart test/chat_screen_test.dart
flutter test test/address_api_test.dart test/address_screen_test.dart
```

Chép đủ các file cần dùng chung: chat_screen_test dùng fixture của chat_api_test và các test Hồ sơ; address_screen_test dùng fixture của address_api_test. Tại mốc soạn docs, test địa chỉ đã có trong bộ bàn giao nhưng chưa thấy trên checkout local của Hào. Nếu báo không tìm thấy file, bổ sung đúng file trước khi chạy; không tạo test rỗng cho lệnh hết lỗi.

Chạy toàn bộ nhóm nghiệp vụ đã được kiểm tra trên QA:

```powershell
flutter test test/auction_repository_test.dart test/auction_detail_test.dart test/wallet_api_test.dart test/auction_join_test.dart test/auction_bidding_test.dart test/notification_api_test.dart test/notification_shell_test.dart test/auction_report_test.dart test/profile_api_test.dart test/profile_screen_test.dart test/chat_api_test.dart test/chat_screen_test.dart test/address_api_test.dart test/address_screen_test.dart
```

Bản QA đạt 154 test với các file bàn giao cuối cùng. Khi code thay đổi, chạy lại để có bằng chứng cho commit mới. Test xuất ảnh QA không được bàn giao vào repo và không nằm trong lệnh trên.

`flutter test` không chỉ định file còn chạy test prototype cũ như screens_smoke_test/store_flow_test. Nhóm cần cập nhật các test cũ khi thay AppStore demo bằng RemoteAppStore/mock API. Không bỏ qua lỗi full suite rồi ghi “tất cả test repo đạt”. Không tắt FlutterError.onError hoặc nuốt exception chỉ để test xanh.

## Test thủ công theo module Hào

| Module | Tình huống chính | Kết quả cần đối chiếu |
|---|---|---|
| Auth | Đăng ký mới, email trùng, sai mật khẩu, restore, logout, ops | Đúng role; token không lẫn tài khoản; không lưu mật khẩu |
| Khám phá | Live/ended/joined, category, từ khóa, sort, tải thêm, rỗng | Khớp GET auctions cùng filter |
| Chi tiết | Phiên live/paused/ended, ảnh lỗi, thiếu dữ liệu | Đúng ID và trạng thái; không mở detail demo |
| Ví | Nạp/hủy, số không hợp lệ, lịch sử, timeout | Khớp wallet/transactions; không tự nạp lặp |
| Cọc | Thiếu tiền, hủy xác nhận, thành công, đã tham gia | GET detail joined/myDeposit và ví/held |
| Đặt giá | Hai bidder, bị vượt, đang dẫn, bước giá, reconnect, kết thúc | Giá/lịch sử/won do BE xác nhận |
| Notification | Badge, chọn 1, read-all, foreground, offline mở lại | Khớp unreadCount/isRead/data; không tự đọc hết khi mở tab |
| Report | Hủy, gửi, đã báo cáo, note quá dài, Admin kiểm tra | reported=true và cờ/bằng chứng đúng phía Admin |
| Profile | Sửa/hủy, lưu, avatar, sai mật khẩu hiện tại, login lại | GET me giữ dữ liệu đã lưu; không báo thành công giả |
| Chat | Gửi tiếp, mở lại, tải lịch sử, hội thoại mới, đổi tài khoản | GET chat history đúng session/tài khoản; không tự POST trùng |
| Địa chỉ | Empty, thêm, sửa, mặc định, xóa/hủy, quay lại Hồ sơ | GET addresses đúng, Hồ sơ cập nhật mặc định, ID mới được dùng |

Đối chiếu thường dùng GET trên Postman. Không POST nạp/cọc/đặt giá thêm chỉ để “kiểm tra” thao tác vừa làm trong app, vì sẽ tạo nghiệp vụ mới.

## Test xuyên role

### Seller → Appraiser → Bidder

Hiệu tạo/submit tin. Người nhận Appraiser quyết định bằng role đúng. Hào kiểm tra danh sách và GET chi tiết phiên. Không khẳng định seller nhận 201 là bidder phải thấy live ngay.

### Bidder thắng → đơn → thanh toán

Hai bidder thử trên dữ liệu đã thống nhất. Khi BE chốt phiên, ghi auctionId/orderId. Hào mở thông báo thắng; Hiệu kiểm tra route đơn, amountToPay, chọn/gắn địa chỉ và thanh toán. Test thiếu tiền, đã trả, quá hạn theo dữ liệu thử được nhóm chuẩn bị.

### Seller → Warehouse → Bidder nhận hàng

Đơn đã paid. Seller báo gửi kho; Warehouse nhận, kiểm định, đóng gói, gửi và giao theo BE. Hiệu kiểm tra tracking/confirm-delivery; Hào kiểm tra thông báo mở đúng đơn. Thử riêng nhánh mismatch, không tự bỏ trạng thái để đi nhanh.

### Report và tranh chấp

Hào report phiên → Khang đọc đúng cờ. Hiệu tạo tranh chấp đơn hợp lệ → Khang xử lý → kiểm tra lại đơn, giải ngân/hoàn tiền và thông báo liên quan. Report phiên và dispute đơn là hai luồng khác nhau.

## Ngoại lệ chung

- Tắt/bật BE, socket mất/kết nối lại, app background/foreground.
- Đăng xuất trong khi request chờ; đăng nhập tài khoản khác không nhận dữ liệu/socket của tài khoản trước.
- Bấm gửi nhiều lần; đóng màn khi đang ghi; phản hồi cũ tới muộn.
- Dữ liệu rỗng, ID không tồn tại/không thuộc quyền, role sai, account suspended.
- Kích thước điện thoại, bàn phím, cuộn form, lỗi ảnh và danh sách dài.

Không tự sửa DB dùng chung, rút ngắn phiên hoặc thay deadline mà chưa phối hợp BE/nhóm. Chuẩn bị dataset riêng nếu cần kiểm tra hết hạn.

## Mẫu ghi kết quả

| Ngày | Người | Nhánh/commit | Môi trường | Task/tình huống | Kết quả | ID/lỗi còn lại |
|---|---|---|---|---|---|---|
| Điền khi test | Hào/Hiệu/Khang | Commit thực tế | QA mock hoặc BE dev + Android | Ví dụ H07 thêm địa chỉ | Pass/Fail | ID không nhạy cảm, mô tả lỗi |

Không ghi token, email/mật khẩu thật hoặc dữ liệu cá nhân của khách hàng vào báo cáo test trong repo.
