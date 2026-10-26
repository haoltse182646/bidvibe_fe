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
flutter test test/address_repository_test.dart test/my_disputes_screen_test.dart
```

The address repository tests cover validation and CRUD request contracts. The disputes-screen tests cover loading, empty, error/retry, session expiry, and rendered status labels.

Chạy toàn bộ nhóm nghiệp vụ đã được kiểm tra trên QA:

```powershell
flutter test test/auction_repository_test.dart test/auction_detail_test.dart test/wallet_api_test.dart test/auction_join_test.dart test/auction_bidding_test.dart test/notification_api_test.dart test/notification_shell_test.dart test/auction_report_test.dart test/profile_api_test.dart test/profile_screen_test.dart test/chat_api_test.dart test/chat_screen_test.dart test/address_repository_test.dart test/my_disputes_screen_test.dart
```

Bản QA trước đây đạt 154 test với các file bàn giao lúc đó. Hai đường dẫn địa chỉ trong lệnh cũ đã được thay bằng tên file test hiện có. Khi code thay đổi, chạy lại để có bằng chứng cho commit mới. Test xuất ảnh QA không được bàn giao vào repo và không nằm trong lệnh trên.

`flutter test` không chỉ định file còn chạy test prototype cũ như screens_smoke_test/store_flow_test. Nhóm cần cập nhật các test cũ khi thay AppStore demo bằng RemoteAppStore/mock API. Không bỏ qua lỗi full suite rồi ghi “tất cả test repo đạt”. Không tắt FlutterError.onError hoặc nuốt exception chỉ để test xanh.

## Kết quả chạy gần nhất — 2026-10-26

Môi trường: nhánh `testing_branch`, commit `fd1d169`; Flutter 3.47.4 / Dart 3.13.3; Android Emulator `emulator-5554` (Android 16 / API 36).

| Lệnh / kiểm tra | Kết quả | Ghi chú |
|---|---|---|
| `flutter analyze` | **PASS** | Không phát hiện issue. |
| `flutter test --coverage` | **PASS** | 244 test pass, 2 test bị skip; không có unit/widget test fail. Hai test live-order trong `test/order_live_test.dart` cần các biến môi trường backend riêng, chưa được cung cấp nên không gửi request. |
| Android `auction_e2e_test.dart` (fixture cập nhật) | **FAIL** | APK build/cài đặt thành công; test tìm thấy card khớp tiêu đề và ID. Khi mở card, Flutter cảnh báo vị trí tap không hit được nút, có thể do card ngoài vùng nhìn thấy/bị che; bước xác nhận chi tiết timeout. Test chưa quay lại hoặc đăng xuất; không đặt cọc/đặt giá. |

Phân tích đầy đủ và nguyên nhân nghi vấn được ghi tại [e2e_test_result.md](./e2e_test_result.md); kết quả suite và giới hạn coverage tại [unit_test_report.md](./unit_test_report.md). LCOV đo coverage theo dòng, không chứng minh mọi function đều có test. E2E đã xác nhận fixture mới được tìm thấy, nhưng journey chưa hoàn tất.

Các tình huống kiểm thử thủ công theo module và xuyên role bên dưới **chưa được thực hiện** trong lần chạy này. Chúng cần các role, dữ liệu/đơn hàng đã chuẩn bị và thao tác đối chiếu backend; kết quả của analyzer, widget/API tests hoặc E2E không thay thế được bước QA thủ công đó.

## Android E2E với backend cục bộ

`integration_test/auction_e2e_test.dart` kiểm tra đăng nhập bidder, tìm đúng phiên live theo tiêu đề và ID, mở chi tiết, quay lại và đăng xuất. Sau đăng nhập, test chỉ đọc dữ liệu; không đặt cọc, đặt giá hoặc thay đổi dữ liệu nghiệp vụ. Test chỉ chấp nhận API URL emulator `http://10.0.2.2:<port>` và từ chối host khác trước khi mở app.

Chỉ chạy trên Android Emulator trỏ tới backend dùng **database thử nghiệm riêng, đã xác minh là disposable**. Không dùng `.env` trỏ Supabase dùng chung, staging có dữ liệu khách hàng, hoặc production. Backend cần được migrate và có một tài khoản bidder E2E chuyên dụng cùng một phiên đấu giá live đã chuẩn bị trước. Không dùng tài khoản hoặc phiên demo/chung của nhóm.

Chạy test bằng cách truyền trực tiếp năm compile-time define. Thay email, mật khẩu và fixture placeholders bằng thông tin của tài khoản bidder và phiên live dành riêng cho kiểm thử:

```powershell
flutter test integration_test/auction_e2e_test.dart -d emulator-5554 `
  --dart-define='BIDVIBE_E2E_EMAIL=replace-with-dedicated-test-email' `
  --dart-define='BIDVIBE_E2E_PASSWORD=replace-with-dedicated-test-password' `
  --dart-define='BIDVIBE_E2E_AUCTION_TITLE=replace-with-exact-live-auction-title' `
  --dart-define='BIDVIBE_E2E_AUCTION_ID=replace-with-exact-live-auction-id' `
  --dart-define=BIDVIBE_API_BASE_URL=http://10.0.2.2:5000
```

Do `--dart-define` xuất hiện trong command line và Flutter nhúng các giá trị vào test build, chỉ dùng tài khoản thử nghiệm riêng, có thể xoay vòng mật khẩu; không lưu lệnh đã điền thông tin vào tài liệu, script hoặc shell history dùng chung. Không dùng tài khoản production hoặc tài khoản dùng chung. `BIDVIBE_API_BASE_URL` ghi đè `config/dev.json` cho build này. Android debug manifest cho phép HTTP; không thêm ngoại lệ HTTP vào bản release. Nếu thiếu define, test bị skip và không gửi request. Nếu URL không trỏ tới `10.0.2.2`, test fail trước khi mở app hoặc gửi request.

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
