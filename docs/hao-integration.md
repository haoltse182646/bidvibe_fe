# Hào — tích hợp sau khi ghép Hiệu và Khang

Mốc: 16/10/2026. Bản nền: commit `ab15709` (đã gồm PR #9 Admin and ops của Khang và phần đơn/seller của Hiệu). Đây là phần bổ sung trên bản sao QA, chưa chép vào repo hoặc push/merge. Đọc tài liệu này trước các ghi nhận tiến độ cũ.

## Phần đã bổ sung

| Task | Kết quả |
|---|---|
| H04/H08 — thông báo | Có `disputeId` → mở `DisputeDetailScreen`; `orderId` → mở `OrderDetailScreen`; `auctionId` → mở chi tiết phiên. Giữ thứ tự dispute → order → listing → auction. Không đoán ID từ tiêu đề |
| H02/H08 — phiên thắng | “Xem đơn thắng” tìm đơn bằng `auctionId` trong `/api/orders/mine`, rồi mở bằng `order.id`. Nếu scheduler chưa tạo đơn, báo chờ và cho thử lại |
| H03/H06/H08 — đồng bộ | Ví/Hồ sơ tải lại sau khi đóng màn phiên/đơn/tranh chấp, vào tab Ví/Hồ sơ, app trở lại foreground, có thông báo socket mới hoặc kết nối lại |
| H06 — bảo toàn biểu mẫu | Chờ đóng/lưu/hủy biểu mẫu hồ sơ hoặc mật khẩu trước khi áp dụng cập nhật tự động; không ghi đè nội dung đang nhập |
| H08 — trạng thái đơn | Chi tiết đơn và tranh chấp nhận tín hiệu cập nhật; khóa thao tác khi đang tải hoặc dữ liệu tải lại bị lỗi; bỏ qua kết quả của token/môi trường cũ |
| H09 — kiểm thử | Có 16 bài kiểm thử tích hợp bổ sung; dùng API fixture, không ghi DB thật |

`DeferredRefresh` gom yêu cầu tải lại trong lúc màn đang bận. Các tín hiệu chỉ gọi GET; không tự gửi lại yêu cầu trả tiền, nạp ví, đặt giá hoặc tạo tranh chấp. Không thêm package hay thay đổi cấu hình URL.

## Màn và API

| Điểm vào | Màn đích / API thực dùng |
|---|---|
| Thông báo thắng/nhắc thanh toán/giao hàng có orderId | `OrderDetailScreen`: GET `/api/orders/:id`, GET `/api/orders/:id/tracking`; GET `/api/wallet` nếu còn chờ thanh toán |
| Thông báo tranh chấp/hoàn tiền có disputeId | `DisputeDetailScreen`: GET `/api/disputes/mine`, tìm đúng disputeId trong danh sách của tài khoản. BE chưa có GET `/api/disputes/:id` cho bidder |
| Chi tiết tranh chấp → Xem đơn liên quan | Mở bằng `dispute.orderId`; không dùng disputeId làm orderId |
| Đơn hàng của tôi → Tranh chấp → một mục | `MyDisputesScreen` → `DisputeDetailScreen` → đơn liên quan |
| Chi tiết phiên → Xem đơn thắng | GET `/api/orders/mine` rồi mở order.id có auctionId khớp. Không dùng listingId hoặc tự tạo đơn |
| Ví tự cập nhật | GET `/api/wallet`; GET `/api/wallet/transactions?limit=20&offset=0` |
| Hồ sơ tự cập nhật | GET `/api/me`; bidder thêm GET `/api/addresses`, GET `/api/orders/mine` |

Bidder không gọi API Admin/Appraiser/Warehouse. Quyết định hoàn tiền, người thắng, giải ngân và trạng thái giao hàng thuộc BE. `refund` không được suy từ `payoutStatus` của đơn: dùng `dispute.resolution` vì BE vẫn giữ `payoutStatus: disputed` sau hoàn tiền tranh chấp.

## Cách tích hợp file

1. Làm trên `feature/Hao` đã đồng bộ bản nền `ab15709` hoặc commit mới hơn chứa cùng code. Nếu nhóm đã sửa các file liên quan sau mốc này, so sánh trước khi chép để giữ thay đổi của nhóm.
2. Chép toàn bộ thư mục `lib/`, `test/`, `docs/` trong gói bàn giao vào đúng thư mục cùng tên của project. Các file trong gói là **nội dung đầy đủ**, gồm cả file sửa và file mới; không phải toàn bộ project.
3. Không xóa các file khác trong project. Không cần thay `pubspec.yaml`, `config/dev.json` hoặc `main.dart` cho phần bổ sung này.
4. Chạy:

```sh
flutter analyze
flutter test test/hao_integration_test.dart
flutter test
flutter run -d emulator-5554
```

Các bài `order_live_test.dart` có thể ghi dữ liệu BE khi bạn đã đặt biến môi trường BACKEND_URL/TEST_PASSWORD/TEST_BIDDER_EMAIL/TEST_BUYER_EMAIL. Đợt QA này không đặt các biến đó: hai bài live được bỏ qua.

## Test thủ công theo thứ tự

Dùng dữ liệu dev dành riêng cho kiểm thử. BE chạy trên máy, emulator dùng base URL đã cấu hình `http://10.0.2.2:5000`; Postman dùng URL localhost cùng cổng. Dùng đúng token theo role trong Authorization → Bearer Token; không ghi token vào repo. Ops đăng nhập qua POST `/api/auth/ops/login`, bidder/seller qua POST `/api/auth/login`.

### 1. Thắng phiên → mở đúng đơn → thanh toán

1. Dùng bidder đã thắng một phiên thật và BE đã xác nhận `won: true`. Nếu phiên chưa kết thúc thì chờ scheduler; không dùng Admin terminate để tạo người thắng vì terminate là hủy phiên và hoàn cọc.
2. Trên app mở chi tiết phiên → **Xem đơn thắng**. Đối chiếu Postman GET `/api/orders/mine` bằng cùng token bidder: mã đơn được mở phải là `order.id` của `auctionId` đang xem.
3. Nếu đơn chưa xuất hiện, app báo đang cập nhật. Thử lại sau vài giây; không tự tạo đơn từ FE.
4. Chọn địa chỉ → thanh toán trên app. Đối chiếu GET `/api/orders/:order_id` và GET `/api/wallet`, GET `/api/wallet/transactions`.
5. Quay về Hồ sơ rồi vào Ví: trạng thái đơn và số dư phải mới. Không phải đăng xuất hoặc khởi động lại app. QR/card trong BE hiện là mô phỏng; nếu cần kiểm tra tiền bị trừ ví, chọn phương thức Ví và chuẩn bị đủ số dư.
6. Bấm thông báo thắng/nhắc thanh toán: phải mở cùng mã đơn. Đơn tài khoản khác không được hiển thị như đơn của mình.

### 2. Giao hàng → thông báo → theo dõi → xác nhận

Thực hiện qua app của Hiệu/Khang; dùng Postman khi cần chuẩn bị hoặc đối chiếu dữ liệu:

| Thứ tự | Token | Request / body |
|---|---|---|
| Seller báo gửi về kho sau khi bidder đã trả | seller của đơn | POST `/api/orders/:order_id/ship-to-warehouse`, không body |
| Kho nhận | warehouse | POST `/api/warehouse/orders/:order_id/receive`, không body |
| Kiểm đạt | warehouse | POST `/api/warehouse/orders/:order_id/inspect`, `{"result":"match","notes":"Đúng mô tả"}` |
| Đóng gói | warehouse | POST `/api/warehouse/orders/:order_id/pack`, `{"notes":"Đã đóng gói"}` |
| Gửi đi | warehouse | POST `/api/warehouse/orders/:order_id/ship`, `{"carrier":"GHN Express","trackingCode":"TEST-HAO-001"}` |
| Xác nhận giao | warehouse | POST `/api/warehouse/orders/:order_id/deliver`, không body |

Mỗi bước kiểm tra bidder nhận thông báo; bấm vào mở đúng đơn và tiến trình mới. Để sẵn chi tiết đơn khi kho đổi trạng thái cũng phải cập nhật sau tín hiệu thông báo. Sau `delivered`, bidder mới bấm **Đã nhận hàng**, xác nhận và đối chiếu GET tracking thấy `payoutStatus: released`, `stage: completed`. Không dùng đơn này để thử tranh chấp nữa; chuẩn bị đơn khác chưa giải ngân cho bước 3.

### 3. Tranh chấp → Admin xử lý → cập nhật ví

1. Dùng một đơn đã trả, chưa giải ngân. Mở tranh chấp bằng app của Hiệu; đối chiếu GET `/api/disputes/mine`, lưu `dispute_id` và `order_id`. Với tranh chấp tự mở nguồn warehouse, có thể dùng bước inspect `{"result":"mismatch","notes":"Hàng khác mô tả"}` trên một đơn khác ở đúng bước kho.
2. Nếu bidder chính là người mở tranh chấp, BE có thể chỉ thông báo cho bên kia; bidder xem qua **Đơn hàng của tôi → Tranh chấp**.
3. Admin xem GET `/api/admin/disputes?status=open`; xử lý qua app Khang hoặc POST `/api/admin/disputes/:dispute_id/resolve` với `{"resolution":"refund","note":"Hoàn tiền kiểm thử"}`.
4. Bidder bấm thông báo có disputeId: mở **chi tiết tranh chấp**, hiển thị hoàn tiền và timeline; nút **Xem đơn liên quan** mở đúng orderId. Dù data có cả orderId/auctionId vẫn ưu tiên disputeId.
5. So sánh ví trước/sau và giao dịch `refund` bằng GET `/api/wallet`, GET `/api/wallet/transactions`. App hiển thị số dư BE; không tự cộng tiền dựa trên nội dung thông báo.
6. Dùng một tranh chấp khác để thử `{"resolution":"keep","note":"Giữ nguyên giao dịch"}`: app hiển thị giữ nguyên/giải ngân; không hiện hoàn tiền. Không gửi hai resolution lên cùng một tranh chấp đã xử lý.

### 4. Report → Admin → bidder

1. Bidder báo cáo một phiên live trên app. Đối chiếu Admin GET `/api/admin/flags`, tìm cờ có `auction.id` đúng. `flagId` khác `auctionId`; report có thể bổ sung vào cờ cũ.
2. Admin dùng POST `/api/admin/flags/:flag_id/action` với `{"action":"pause","reason":"Kiểm tra báo cáo"}`. Bidder thấy tạm dừng, không đặt cọc/giá khi dữ liệu được cập nhật.
3. Cùng cờ, Admin gửi `{"action":"verify","reason":"Tiếp tục xác minh"}` để phiên chạy lại. Thời gian do BE bù, FE tải lại.
4. Nếu cần kiểm tra hủy, dùng phiên dev phù hợp rồi gửi `{"action":"terminate","reason":"Hủy phiên kiểm thử"}`. Phiên bị hủy, không có đơn thắng mới, tiền cọc được BE hoàn. Kiểm tra Ví và thông báo.

### 5. Ngoại lệ và vòng đời

- Để Hồ sơ đang sửa tên, làm phát sinh thông báo ở role khác: nội dung nhập vẫn giữ. Hủy/lưu biểu mẫu rồi mới tải dữ liệu mới.
- Mất mạng → thao tác tải lại báo lỗi và có thử lại; không biến số dư thiếu dữ liệu thành 0 hoặc tự gửi lại thanh toán.
- Khi đang xem đơn, đưa app xuống nền; role khác đổi trạng thái; quay lại app: dữ liệu được tải mới kể cả đã bỏ lỡ socket.
- Ngắt rồi kết nối mạng/socket lại: tải số dư/hồ sơ và thông báo mới, không tăng tiền hoặc badge nhiều lần vì cùng sự kiện.
- Admin khóa một **tài khoản thử** qua PATCH `/api/admin/accounts/:account_id` với `{"status":"suspended"}`: bidder về đăng nhập theo lỗi ACCOUNT_SUSPENDED. Mở lại bằng `{"status":"active"}` rồi đăng nhập kiểm tra. Không khóa tài khoản đang cần giữ cho demo.
- Thông báo cũ có `data: null`: đọc được nội dung, không tự đoán đích. Không tìm thấy tranh chấp: thông báo rõ và cho thử lại.

## Kết quả và giới hạn

Baseline `ab15709`: 204 test đạt, 2 live test bỏ qua. Bản bổ sung: 220 test đạt (gồm 16 bài mới), 2 live test bỏ qua. `flutter analyze --no-pub`: No issues found. APK debug đã biên dịch thành công. Test dùng fixture, không có thao tác DB/Supabase thật trong đợt này.

Phần code nối của Hào đã có; việc còn lại là Hào chép file, chạy manual trên emulator/BE của nhóm, rồi ghi bằng chứng và mở PR vào develop. Không coi QA tự động là đã chạy toàn bộ role trên BE thật.

Thông báo realtime hiện phục vụ lúc app đang mở; chưa có push hệ điều hành khi app tắt. API nhắc thanh toán/giao hàng do BE phát sinh, FE hiển thị và điều hướng, không có API tự đặt lịch nhắc từ bidder. Các thông báo listing dành seller không được biến thành route sửa tin seller trong khung bidder.

Trước demo bằng bản release, kiểm tra quyền INTERNET trong Android manifest chính và cấu hình HTTPS của môi trường deploy; gói này chỉ bổ sung tích hợp nghiệp vụ và được kiểm tra bản debug.
