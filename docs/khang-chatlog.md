# Nhật ký phiên làm việc: tích hợp Admin và Ops

Cập nhật: 20/10/2026

## Phạm vi

Trong phiên này, checkout FE được nối các task K01–K06 theo hợp đồng API trong `docs/api.md`: Admin, Appraiser và Warehouse chuyển từ dữ liệu prototype sang gọi backend qua `ApiClient` và repository. Đây là ghi nhận code local; không xác nhận thay Khang rằng task đã được nhận, đưa lên nhánh riêng, tạo PR hoặc merge.

## Chức năng đã triển khai

### K01 — Dashboard và báo cáo tuần

- Dashboard gọi `GET /api/admin/dashboard`; hiển thị phiên đang chạy/kết thúc sớm, hàng chờ thẩm định, đơn theo giai đoạn, cờ, tranh chấp, tài khoản và tiền ký quỹ.
- Báo cáo tuần gọi `GET /api/admin/report/weekly`; hiển thị kỳ báo cáo, đấu giá, GMV/phí, thanh toán, tài khoản mới, thẩm định, tranh chấp, nạp ví và danh mục nổi bật.
- Đã bỏ số liệu cố định và phần tóm tắt AI mô phỏng khỏi shell Admin.

### K02 — Cờ phiên

- Tải danh sách qua `GET /api/admin/flags`, lọc theo mức nghiêm trọng và mở chi tiết phiên, giải thích, bằng chứng, giá hiện tại và số lượt giá từ BE.
- Hỗ trợ `pause`, `verify`, `safe`, `terminate` qua `POST /api/admin/flags/:id/action`.
- Chấm dứt phiên yêu cầu nhập lý do; thao tác ghi chờ phản hồi BE và hiển thị lỗi nghiệp vụ.

### K03 — Tài khoản

- Quản lý bidder/seller bằng `GET /api/admin/accounts` với lọc role/status và tìm tên/email; đổi trạng thái qua `PATCH /api/admin/accounts/:id`.
- Quản lý ops bằng `GET /api/admin/ops-accounts`; tạo tài khoản qua POST; sửa role/tên/mật khẩu hoặc trạng thái qua PATCH.
- Không hardcode quyết định quyền trong UI; BE kiểm tra các trường hợp như tự khóa Admin.

### K04 — Tranh chấp

- Tải danh sách theo trạng thái từ `GET /api/admin/disputes`; xem nội dung, timeline, số ký quỹ và kết quả xử lý.
- Xác nhận trước khi xử lý; gửi `refund` hoặc `keep` đúng hợp đồng tới `POST /api/admin/disputes/:id/resolve`, kèm ghi chú tùy chọn.

### K05 — Appraiser

- Một màn hàng chờ với hai trạng thái BE hỗ trợ: `pending_appraisal` và `needs_info`.
- Mở chi tiết qua `GET /api/appraisals/:listingId`, hiển thị mô tả, ảnh, giá, người bán và lịch sử quyết định.
- Gửi `approve`, `reject` hoặc `more_info` qua endpoint decision. Từ chối/yêu cầu bổ sung bắt buộc có lý do; duyệt có bước xác nhận và hiển thị `auctionId` BE trả về.
- Không còn điều hướng tới lịch sử thẩm định toàn cục prototype vì BE không cung cấp endpoint đó.

### K06 — Warehouse

- Bảng kho gọi `GET /api/warehouse/orders`, lọc theo stage BE và mở chi tiết đơn, người bán/người nhận, địa chỉ, thông tin kho, tracking và events.
- Thao tác đúng thứ tự backend: `receive` → `inspect` → `pack` → `ship` → `deliver`.
- Kiểm định chọn `match` hoặc `mismatch`; mismatch cần ghi chú và để BE mở tranh chấp. Đóng gói nhận ghi chú tùy chọn. Gửi hàng bắt buộc hãng vận chuyển và mã tracking.
- Bỏ khỏi shell kho các thao tác prototype không có API như quét mã, ảnh nhận hàng, grade và vị trí kệ.

## Thay đổi kỹ thuật và tài liệu

- Thêm `lib/features/ops/ops_repository.dart` để gom các route Admin/Appraiser/Warehouse, kiểm tra ID/enum và cấu trúc danh sách, chuẩn hóa query/body, và chuyển lỗi hết phiên cho `RemoteAppStore` xử lý đăng xuất.
- Thêm các màn API-backed: `lib/screens/admin/admin_ops_overview.dart`, `admin_ops_cases.dart`, `admin_ops_accounts.dart`, `lib/screens/appraiser/appraiser_ops_screen.dart`, `lib/screens/warehouse/warehouse_ops_screen.dart`; cập nhật các shell tương ứng.
- Bổ sung `test/ops_repository_test.dart` kiểm tra route, query, body, token, quyết định nghiệp vụ và các bước kho.
- Cập nhật fixture/assertion trong `test/screens_smoke_test.dart` để các shell ops kiểm thử bằng response API tường minh, thay cho điều kiện cũ cấm request.
- Cập nhật `docs/api-integration.md` và `docs/progress.md`; ghi rõ trạng thái code local không đồng nghĩa với kiểm thử BE thật hay đã merge.

## Kiểm tra trong phiên

- `flutter analyze`: không issue.
- `flutter test`: 204 passed, 0 failed sau khi cập nhật smoke fixture.
- Hot restart trên Chrome thành công bằng Flutter CLI. Phiên Chrome sau đó đã kết thúc; URL preview cũ không còn được đảm bảo đang chạy.
- Android emulator không được Flutter nhận diện trong lần thử; kiểm tra runtime thực hiện trên Chrome.

## Việc còn cần xác nhận

- Chưa chạy thủ công các luồng bằng tài khoản ops và backend dev thật; test repository/smoke dùng HTTP fixture.
- Cần phối hợp kiểm thử xuyên role: report bidder → Admin, seller submit → Appraiser → bidder thấy phiên, seller gửi kho → warehouse → bidder theo dõi/nhận hàng, và dispute → Admin → đối chiếu refund/payout.
- Chưa xác minh Khang đã nhận task, branch/commit/PR, merge develop hay merge main.
- Các prototype audit Admin/lịch sử Appraiser vẫn có thể còn file trong source nhưng không được route từ shell ops; chưa có endpoint tương ứng trong hợp đồng API được cung cấp.

## Bổ sung phiên 20/10/2026 — ảnh bằng chứng tranh chấp Admin

### Nguyên nhân

- Điều hướng Admin hiện tại dùng `AdminOpsDisputesScreen` trong `lib/screens/admin/admin_ops_cases.dart`, không dùng màn prototype `lib/screens/admin/admin_disputes.dart`.
- Danh sách tranh chấp API trả dữ liệu chi tiết gồm `photos`, nhưng `AdminOpsDisputeDetailScreen` trước đó chỉ hiển thị báo cáo và timeline, chưa dựng phần ảnh bằng chứng.

### Thay đổi và chức năng

- Bổ sung gallery ảnh bằng chứng trong chi tiết tranh chấp Admin; mỗi ảnh có nhãn theo người gửi (người mua, người bán hoặc kho).
- URL ảnh được xác thực bằng `ProfileRepository.validUrl` trước khi dựng widget để bỏ qua dữ liệu URL không hợp lệ.
- Ảnh hiển thị dạng thumbnail; chạm ảnh mở hộp thoại phóng to có thể tương tác. Khi ảnh không tải được, giao diện hiển thị biểu tượng/lời báo lỗi thay vì làm hỏng màn hình.
- Thêm `test/admin_dispute_photos_test.dart` kiểm tra gallery hiển thị ảnh hợp lệ, nhãn người gửi và bỏ qua URL không hợp lệ.

### Kiểm tra trong phiên

- `flutter test test\admin_dispute_photos_test.dart`: đạt, 1 test.
- `flutter analyze --no-pub lib\screens\admin\admin_ops_cases.dart test\admin_dispute_photos_test.dart`: không issue.
- `git diff --check`: không lỗi whitespace.
- Không xác nhận được hot reload: Flutter CLI không chạy được target Windows do thiếu Visual Studio toolchain; bản Chrome đã khởi động nhưng không có app connection vào Dart Tooling Daemon để gửi lệnh reload.
