# Android business E2E — bộ kiểm thử mở rộng

## Mục tiêu và phạm vi

Bộ Mobile trên dashboard kiểm tra 66 case nghiệp vụ bằng Flutter `integration_test` trên Android. Không có case đăng nhập, đăng xuất hoặc đăng ký riêng. Hai bidder mới được tạo bằng API trong `setUpAll`; đăng nhập đúng role là điều kiện để thực hiện nghiệp vụ, không phải kết quả business PASS.

Các vai trò: bidder, seller, appraiser, warehouse và admin. Hai bidder thao tác UI lần lượt trên một máy ảo; đối thủ realtime dùng API có xác thực. Đây không phải kiểm thử UI song song trên hai máy Android.

## Cách chạy

1. Chờ máy ảo Android khởi động hoàn tất; giữ nguyên `runner.local.json` và file credentials riêng trên máy.
2. Mở `run-e2e-dashboard.cmd` tại thư mục gốc project.
3. Chọn **Mobile** (không chọn Connected nếu chỉ muốn chạy Android), bắt đầu và chờ hoàn tất.
4. Kiểm tra kết quả từng case cùng **Cleanup**. Xuất HTML để trình bày; JSON/XML để lưu trữ và tích hợp.

Không cần chạy Web hoặc Connected trước. Lượt Mobile tự tạo điều kiện nghiệp vụ riêng. Dashboard chuẩn bị một bidder bị JOIN_BLOCKED bằng hai đơn test quá hạn khi `prepareRestrictedBidder` được bật. Không sử dụng tài khoản mẫu để cố tình tạo vi phạm.

## Ý nghĩa bằng chứng

Các ô nhập được điều khiển bằng `WidgetTester.enterText` qua `TestTextInput` đã đăng ký. Bàn phím Gboard của hệ điều hành không nằm trong phạm vi này. App vẫn chạy native trên máy ảo và gọi BE thật; HTTP không bị mock. Cách này ngăn dữ liệu nhập của bộ test bị bàn phím Android ghi đè bởi một cập nhật cũ.

- UI + API verification: thao tác trên giao diện Android, API đối chiếu trạng thái đã ghi nhận.
- API business assertion from authenticated Android session: kiểm tra chính xác quy tắc/ranh giới phân quyền bằng API từ session Android; không gọi đây là thao tác UI.
- API resubmission + Android appraisal UI: API bổ sung/nộp lại hồ sơ, chuyên gia duyệt trên Android.
- Android realtime observation + API actor: Android vẫn đăng nhập và nhận sự kiện Socket.IO từ hành động của tài khoản API khác.

Không tính chuẩn bị fixture và rút ngắn thời gian phiên thành case E2E UI. Nạp tiền, QR và vận chuyển là mô phỏng trong ứng dụng. Ảnh sản phẩm được tạo bằng byte rồi truyền qua callback PhotoPicker; không kiểm thử ứng dụng thư viện ảnh của Android.

## Dữ liệu và dọn dẹp

Mỗi lượt có prefix riêng. Giữ `cleanupAfterRun: true` và `keepFailedFixtures: false` để dọn dữ liệu thuộc lượt chạy, kể cả khi có case FAIL. Log, ảnh, kết quả và bản mã nguồn của lượt chạy được giữ lại. Không đưa `runner.local.json`, credentials, `.env`, `private-run/`, APK hoặc bản sao lưu DB lên GitHub.

Cleanup PASS là một kết quả riêng. Nếu bị tắt cưỡng bức giữa chừng, có thể cần cơ chế cleanup-pending. Case thiếu điều kiện phải SKIP/BLOCKED; không sửa kỳ vọng chỉ để báo PASS.

## Mã nguồn và báo cáo

- `integration_test/android_business_e2e_test.dart`: case nghiệp vụ và điều kiện kiểm tra.
- `e2e/system/mobile-plan.json`: danh sách ID/title/classification cho dashboard.
- `e2e/system/mobile-run.mjs`: build, chạy Android, chụp ảnh, chuyển checkpoint và ghi báo cáo.
- `e2e/system/mobile-contract.test.mjs`: đối chiếu danh sách case với mã nguồn, không cho tính auth/setup thành case nghiệp vụ.
- `e2e/system/reports/<run-id>/results.json`: kết quả tổng hợp và cleanup của lượt dashboard.
- `e2e/system/reports/<run-id>/REPORT-mobile.html`: báo cáo Android riêng.
- `e2e/system/private-run/<native-run-id>/`: nguồn test đã thực thi, log, checkpoint và ảnh gốc; chứa thông tin riêng, không commit.

Đối chiếu khi báo cáo: ID case → nguồn test của chính lượt chạy → log/checkpoint → ảnh và dữ liệu kiểm chứng. Số case không phải cam kết bao phủ mọi tính năng hay mọi lỗi của sản phẩm.

## Thứ tự chạy và tối ưu

Vẫn chỉ có một bộ chạy đủ 66 case. **16 bước luồng chính chạy trước**, từ seller tạo tin, appraiser duyệt, hai bidder đấu giá, thanh toán, gửi kho, giao hàng, xác nhận nhận hàng đến thông báo và lịch sử ví. Sau đó mới chạy **50 case bổ sung và ngoại lệ**.

Các kiểm tra cần trạng thái chưa trả tiền/chưa giao hàng/phiên còn mở dùng fixture riêng được chuẩn bị bằng API, có ghi rõ trong bằng chứng. Không thay đổi đơn đã hoàn tất của luồng chính để ép chạy ngoại lệ. Các fixture riêng vẫn thuộc phạm vi tự dọn của lượt chạy.

Session chỉ được dùng lại sau khi đối chiếu đúng email và role; đổi role vẫn đăng xuất/đăng nhập qua UI. Riêng nhóm địa chỉ dùng điều hướng/phiên mới và các nhịp chờ ổn định để tránh giữ vị trí cuộn hoặc màn đang tải. Giảm các khoảng chờ cố định nhưng giữ chờ theo điều kiện và thời hạn API. Ảnh được chụp ở 16 bước chính, các mốc quan trọng của nhánh mở rộng và mọi case FAIL; mọi case vẫn có checkpoint/log và kết quả riêng.

Mốc so sánh trước tối ưu: run `2026-11-10T20-25-57-169Z-eef61b`, đủ 66 PASS và Cleanup PASS, khoảng 9 phút 31 giây. Đây là kết quả phiên bản trước; kết quả của phiên bản mới phải đối chiếu báo cáo mới.

## Danh sách 66 case

Bảng dưới đây theo đúng thứ tự đăng ký thực thi.

| # | Mã case | Nội dung kiểm tra | Cách kiểm tra |
|---:|---|---|---|
| 1 | A-LIST-01 | Seller tạo tin, upload ảnh và gửi thẩm định; ảnh được đưa vào callback chọn ảnh, chưa test thư viện ảnh Android. | UI Android + đối chiếu API |
| 2 | A-APP-01 | Appraiser duyệt đúng hồ sơ và mở phiên đấu giá. | UI Android + đối chiếu API |
| 3 | A-BID-A | Bidder A nạp ví, đặt cọc và đặt giá. | UI Android + đối chiếu API |
| 4 | A-BID-B | Bidder B nạp ví, đặt cọc và vượt giá bidder A. | UI Android + đối chiếu API |
| 5 | A-RT-BID | Android nhận giá từ đối thủ API, sau đó đặt giá vượt lại qua UI. | Quan sát Android + tác nhân API |
| 6 | A-WIN-01 | Rút ngắn phiên test bằng công cụ hỗ trợ; kiểm tra người thắng, đơn thắng và hoàn cọc người thua. | UI Android + đối chiếu API |
| 7 | A-PAY-01 | Người thắng tạo/chọn địa chỉ, trả bằng ví; kiểm tra số tiền bị trừ. | UI Android + đối chiếu API |
| 8 | A-SHIP-01 | Seller báo gửi đúng đơn test đến kho. | UI Android + đối chiếu API |
| 9 | A-WH-1 | Kho xác nhận đã nhận hàng. | UI Android + đối chiếu API |
| 10 | A-WH-2 | Kho lưu kết quả kiểm định đạt. | UI Android + đối chiếu API |
| 11 | A-WH-3 | Kho xác nhận đóng gói. | UI Android + đối chiếu API |
| 12 | A-WH-4 | Kho nhập đơn vị/mã vận đơn và bàn giao vận chuyển. | UI Android + đối chiếu API |
| 13 | A-WH-5 | Kho xác nhận đã giao hàng. | UI Android + đối chiếu API |
| 14 | A-RECEIPT | Buyer xác nhận nhận hàng; kiểm tra trạng thái giải ngân. | UI Android + đối chiếu API |
| 15 | A-NOTIFY | Buyer tải thông báo giao hàng đã lưu và mở đúng đơn. | UI Android + đối chiếu API |
| 16 | A-WALLET-LEDGER | Ví hiển thị lịch sử giao dịch và số dư khả dụng nhất quán với BE. | UI Android + đối chiếu API |
| 17 | A-SELL-EMPTY | Seller không thể gửi tin khi thiếu tên, giá hoặc ảnh bắt buộc. | UI Android + đối chiếu API |
| 18 | A-WALLET-EMPTY | Từ chối nạp ví khi để trống số tiền. | UI Android + đối chiếu API |
| 19 | A-WALLET-ZERO | Từ chối nạp ví với số tiền bằng 0. | UI Android + đối chiếu API |
| 20 | A-WALLET-NEGATIVE | Từ chối nạp ví với số tiền âm. | UI Android + đối chiếu API |
| 21 | A-WALLET-DECIMAL | Từ chối nạp ví với số thập phân. | UI Android + đối chiếu API |
| 22 | A-WALLET-OVERMAX | Từ chối nạp ví vượt 100.000.000 đồng. | UI Android + đối chiếu API |
| 23 | A-APP-INFO | Appraiser yêu cầu bổ sung hồ sơ và ghi lý do. | UI Android + đối chiếu API |
| 24 | A-APP-RESUBMIT | Seller nộp lại qua API /resubmit; hồ sơ trở lại hàng chờ và được duyệt trên Android. | API nộp lại + UI thẩm định |
| 25 | A-APP-REJECT | Appraiser từ chối hồ sơ riêng và ghi lý do. | UI Android + đối chiếu API |
| 26 | A-JOIN-POOR | Buyer có số dư khả dụng nhỏ hơn tiền cọc bị chặn; tiền đang giữ không tăng (fixture giá cao riêng). | UI Android + đối chiếu API |
| 27 | A-BID-NODEPOSIT | Buyer chưa đặt cọc không thể bấm đặt giá. | UI Android + đối chiếu API |
| 28 | A-BID-LOW | Giá thấp hơn mức tối thiểu bị từ chối, không thêm lượt giá. | UI Android + đối chiếu API |
| 29 | A-BID-CANCEL | Hủy xác nhận đặt giá không thay đổi giá hoặc số lượt giá. | UI Android + đối chiếu API |
| 30 | A-BID-SELF | Bidder đang dẫn đầu không thể tự vượt giá mình. | UI Android + đối chiếu API |
| 31 | A-PAY-NOADDRESS | Android chặn thanh toán khi chưa chọn địa chỉ nhận hàng. | UI Android + đối chiếu API |
| 32 | A-SHIP-UNPAID | Seller không thể báo gửi kho cho đơn chưa thanh toán. | API từ session Android |
| 33 | A-ORDER-OWNERSHIP | Bidder khác không thể đọc hoặc thanh toán đơn của người thắng. | API từ session Android |
| 34 | A-PAY-DUPLICATE | Thanh toán lại đơn đã trả tiền bị từ chối, không trừ ví lần hai. | API từ session Android |
| 35 | A-RECEIPT-EARLY | Không thể xác nhận nhận hàng trước khi giao. | API từ session Android |
| 36 | A-SHIP-DUPLICATE | Báo gửi kho lần hai bị từ chối. | API từ session Android |
| 37 | A-WH-MISMATCH-EMPTY | Chọn hàng không khớp nhưng thiếu ghi chú thì không thể lưu kiểm định. | UI Android + đối chiếu API |
| 38 | A-WH-PACK-EARLY | Kho không thể đóng gói trước khi kiểm định đạt. | API từ session Android |
| 39 | A-WH-SHIP-EMPTY | Kho không thể gửi hàng khi thiếu đơn vị vận chuyển hoặc mã vận đơn. | UI Android + đối chiếu API |
| 40 | A-ADMIN-OVERVIEW | Admin mở tổng quan và tải dữ liệu BE. | UI Android + đối chiếu API |
| 41 | A-ADMIN-FLAGS | Admin mở danh sách cờ/báo cáo phiên. | UI Android + đối chiếu API |
| 42 | A-ADMIN-DISPUTES | Admin mở danh sách tranh chấp. | UI Android + đối chiếu API |
| 43 | A-ADMIN-REPORT | Admin mở báo cáo tuần. | UI Android + đối chiếu API |
| 44 | A-ADMIN-ACCOUNTS | Admin mở màn quản lý tài khoản. | UI Android + đối chiếu API |
| 45 | A-ADDR-EMPTY | Form địa chỉ từ chối khi thiếu thông tin bắt buộc. | UI Android + đối chiếu API |
| 46 | A-ADDR-CREATE | Buyer thêm địa chỉ thứ hai. | UI Android + đối chiếu API |
| 47 | A-ADDR-EDIT | Buyer sửa địa chỉ thứ hai; kiểm tra ô nhập, dữ liệu lưu và nội dung hiển thị. | UI Android + đối chiếu API |
| 48 | A-ADDR-DEFAULT | Đặt địa chỉ mặc định; kiểm tra chỉ có một địa chỉ mặc định. | UI Android + đối chiếu API |
| 49 | A-ADDR-OWNERSHIP | Bidder khác không thể sửa địa chỉ của buyer. | API từ session Android |
| 50 | A-ADDR-DELETE | Xóa địa chỉ thứ hai, giữ địa chỉ đang dùng cho đơn. | UI Android + đối chiếu API |
| 51 | A-REPORT | Bidder báo cáo đúng phiên test. | UI Android + đối chiếu API |
| 52 | A-MOD-pause | Admin tạm dừng phiên bị báo cáo. | UI Android + đối chiếu API |
| 53 | A-MOD-verify | Admin chuyển cờ sang yêu cầu xác minh. | UI Android + đối chiếu API |
| 54 | A-MOD-safe | Admin đánh dấu phiên an toàn. | UI Android + đối chiếu API |
| 55 | A-BLOCKED | Bidder bị hạn chế tham gia thấy đúng lý do JOIN_BLOCKED. | UI Android + đối chiếu API |
| 56 | A-DISPUTE | Buyer mở tranh chấp trên đơn test đã trả tiền. | UI Android + đối chiếu API |
| 57 | A-REFUND | Admin hoàn tiền; kiểm tra ví tăng đúng số tiền ký quỹ. | UI Android + đối chiếu API |
| 58 | A-REFUND-DUPLICATE | Xử lý hoàn tiền lần hai bị từ chối, ví không tăng thêm. | API từ session Android |
| 59 | A-KEEP-OPEN | Buyer mở tranh chấp riêng cho nhánh giữ nguyên giao dịch. | UI Android + đối chiếu API |
| 60 | A-KEEP-RESOLVE | Admin giữ giao dịch và giải ngân, buyer không nhận hoàn tiền. | UI Android + đối chiếu API |
| 61 | A-RT-REFUND | Buyer đang đăng nhập nhận sự kiện hoàn tiền realtime từ Admin API; kiểm tra ví tăng. | Quan sát Android + tác nhân API |
| 62 | A-NOTIFY-READALL | Đánh dấu tất cả thông báo đã đọc; số chưa đọc về 0. | UI Android + đối chiếu API |
| 63 | A-RBAC-BIDDER | Bidder bị từ chối truy cập API dashboard Admin. | API từ session Android |
| 64 | A-RBAC-SELLER | Seller bị từ chối truy cập API tài khoản Admin. | API từ session Android |
| 65 | A-RBAC-APPRAISER | Appraiser bị từ chối truy cập API đơn kho. | API từ session Android |
| 66 | A-RBAC-WAREHOUSE | Warehouse bị từ chối truy cập API hàng chờ thẩm định. | API từ session Android |

Cleanup dọn dữ liệu DB thuộc lượt chạy; ảnh đã upload trên object storage được giữ lại.

## Kết quả bản tối ưu đã xác nhận

- Run ID: `2026-11-11T00-47-56-254Z-1fecc8`.
- **66 PASS, 0 FAIL, 0 SKIP/BLOCKED**; Cleanup **PASS**; kiểm tra chỉ đọc trên DB: **PASS**.
- Luồng chính 16 bước hoàn tất sau khoảng **2 phút 42 giây**, sau đó mới đến 50 case còn lại; đã đối chiếu thứ tự checkpoint thực tế.
- Tổng thời gian: **7 phút 27 giây**, so với **9 phút 31 giây** của mốc trước tối ưu, giảm khoảng **21.8%** trong các lượt đo này. Thời gian những lần sau vẫn phụ thuộc mạng, Render và máy.
- **24 ảnh mốc chính**; mọi case vẫn có kết quả/checkpoint/log, mọi FAIL đều được yêu cầu chụp ảnh.
- Phân tích mã test: No issues found; kiểm tra nội bộ: 18 PASS.
- SHA-256 nguồn Android đã chạy: `6a792e725c71250986fb00f3e39a1901581bf3ea8a4fc950d4ea9d8f7eebbca5`; nguồn Android, runner và plan khớp các snapshot đã thực thi.

Kết quả này chỉ xác nhận bộ Android. Không suy ra Web và Connected đã được chạy lại trong lượt này.
