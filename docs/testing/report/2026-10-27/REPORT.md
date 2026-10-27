# Báo cáo kiểm thử BidVibe — 27/10/2026

## Kết luận

API xác thực: **6 PASS**. Kịch bản nghiệp vụ HTTP/Socket.IO: **21 PASS, 0 FAIL**. E2E đăng nhập trên Android: **6 PASS**. Luồng UI xuyên seller → appraiser → bidder: **FAIL** do lỗi FE-001. Luồng bidder chạy độc lập sau đó: **PASS**. Không gộp các nhóm trên thành một tỷ lệ E2E chung.

## Môi trường và phạm vi

| Thành phần | Giá trị |
| --- | --- |
| FE | Bản sao Git archive từ main commit 574f764; code ứng dụng giữ nguyên, thêm test riêng |
| BE đang gọi | https://bidvibe-be.onrender.com; database chung của nhóm |
| BE revision | Chưa xác minh commit đang deploy; BE local đọc tham khảo ở 15d3308 |
| Thiết bị | Pixel_4a / emulator-5554; Android 14, API 34 |
| Công cụ | Flutter 3.47.6, Dart 3.13.5; integration_test, Node.js fetch, Socket.IO client |
| Thời gian API | 2026-10-27T15:29:14.837Z → 2026-10-27T15:29:23.143Z (UTC; Việt Nam UTC+7) |
| Tài khoản | 6 tài khoản: 2 bidder và seller/appraiser/warehouse/admin; không ghi mật khẩu/token |
| Repo thật | Không push, commit, merge hoặc sửa source ứng dụng. Các thay đổi có sẵn giữ nguyên. |

## Cách kiểm thử

Scenario-Based Testing: mỗi kịch bản có điều kiện đầu vào, hành động và assertion. Các request nghiệp vụ dùng API thật. Luồng UI nhập form và nhấn nút trong app trên máy ảo; API GET chỉ dùng đối chiếu trạng thái. Kiểm tra realtime dùng Socket.IO client thực nhận auction:update sau đặt giá REST.

PASS của tình huống âm nghĩa là hệ thống từ chối đúng mã lỗi và không tạo tác dụng phụ ngoài mong đợi. FAIL ghi bước lỗi và bằng chứng; NOT RUN không được tính là PASS. Các checkpoint trong một journey không được tính thành nhiều testWidgets độc lập.

## 1. Xác thực API và E2E đăng nhập

| ID | Tài khoản theo role | API login + /me | UI đăng nhập/role/đăng xuất |
| --- | --- | --- | --- |
| AUTH-01 | Bidder A | PASS | PASS |
| AUTH-02 | Bidder B | PASS | PASS |
| AUTH-03 | Seller | PASS | PASS |
| AUTH-04 | Appraiser | PASS | PASS |
| AUTH-05 | Warehouse | PASS | PASS |
| AUTH-06 | Admin | PASS | PASS |

Bằng chứng: evidence/api-preflight-results.json và evidence/auth-ui.log (+6, All tests passed). UI kiểm tra đúng email/role trong store, đúng shell, đăng xuất xóa currentUser/token ở FE. Không kiểm tra thu hồi JWT phía BE và chưa chứng minh toàn bộ phân quyền của mọi endpoint.

## 2. Kịch bản nghiệp vụ qua API và Socket.IO

Fixture: listing **5537**, auction **5506**, tên **E2E_20261027T152915974Z_BusinessFlow**, giá khởi điểm 10.000đ, cọc 1.000đ, thời lượng 1 giờ.

| ID | Kịch bản | Kết quả | Bằng chứng / quan sát |
| --- | --- | --- | --- |
| BIZ-01 | Seller tạo tin nháp | PASS | {"listingId":"5537","status":"draft"} |
| NEG-01 | Từ chối gửi tin chưa có ảnh | PASS | {"httpStatus":400,"errorCode":"PHOTOS_REQUIRED"} |
| BIZ-02 | Thêm ảnh URL và gửi thẩm định | PASS | {"status":"pending_appraisal","photos":1} |
| NEG-02 | Seller không được tự duyệt | PASS | {"httpStatus":403,"errorCode":"FORBIDDEN"} |
| BIZ-03 | Appraiser xem và duyệt tin | PASS | {"auctionId":"5506","listingStatus":"live"} |
| BIZ-04 | Bidder tìm đúng phiên live và chi tiết | PASS | {"auctionId":"5506","isLive":true,"depositRequired":1000,"endsAt":"2026-10-27T16:29:16.884Z"} |
| NEG-03 | Từ chối đặt giá trước khi cọc | PASS | {"httpStatus":403,"errorCode":"DEPOSIT_REQUIRED"} |
| NEG-04 | Từ chối nạp 0đ; ví không đổi | PASS | {"httpStatus":400,"errorCode":"VALIDATION_ERROR"} |
| BIZ-TOPUP-BIDDER_A | Bidder A nạp giả lập và đối chiếu sổ ví | PASS | {"before":{"balance":0,"held":0,"available":0,"joinBlockedUntil":null},"after":{"balance":200000,"held":0,"available":200000,"joinBlockedUntil":null},"transactionId":"9513","amount":200000} |
| BIZ-JOIN-BIDDER_A | Bidder A cọc và kiểm tra tiền giữ | PASS | {"deposit":1000,"before":{"balance":200000,"held":0,"available":200000,"joinBlockedUntil":null},"after":{"balance":199000,"held":1000,"available":199000,"joinBlockedUntil":null},"joined":true} |
| BIZ-TOPUP-BIDDER_B | Bidder B nạp giả lập và đối chiếu sổ ví | PASS | {"before":{"balance":0,"held":0,"available":0,"joinBlockedUntil":null},"after":{"balance":200000,"held":0,"available":200000,"joinBlockedUntil":null},"transactionId":"9515","amount":200000} |
| BIZ-JOIN-BIDDER_B | Bidder B cọc và kiểm tra tiền giữ | PASS | {"deposit":1000,"before":{"balance":200000,"held":0,"available":200000,"joinBlockedUntil":null},"after":{"balance":199000,"held":1000,"available":199000,"joinBlockedUntil":null},"joined":true} |
| NEG-05 | Cọc trùng bị từ chối; không trừ tiền hai lần | PASS | {"httpStatus":409,"errorCode":"ALREADY_JOINED"} |
| SOCKET-01 | Xác thực Socket.IO và vào phòng phiên | PASS | {"connected":true,"auctionId":"5506"} |
| BIZ-BID-A | Bidder A đặt mức tối thiểu | PASS | {"currentPrice":60000,"bidCount":1,"leading":true} |
| NEG-06 | Người dẫn đầu không tự vượt giá | PASS | {"httpStatus":409,"errorCode":"ALREADY_LEADING"} |
| NEG-07 | Giá thấp hơn mức tối thiểu bị từ chối | PASS | {"httpStatus":400,"errorCode":"BID_TOO_LOW"} |
| BIZ-BID-B | Bidder B vượt A; trạng thái hai tài khoản khớp | PASS | {"currentPrice":110000,"bidCount":2,"aLeading":false,"bLeading":true} |
| SOCKET-02 | Nhận đúng hai sự kiện giá của phiên test | PASS | {"events":[{"auctionId":"5506","currentPrice":60000,"bidCount":1,"reason":"bid"},{"auctionId":"5506","currentPrice":110000,"bidCount":2,"reason":"bid"}]} |
| BIZ-NOTIFICATION | Thông báo bị vượt giá trỏ đúng phiên | PASS | {"notificationId":"12146","type":"outbid","auctionId":"5506"} |
| NEG-08 | Tin live không được duyệt lại | PASS | {"httpStatus":409,"errorCode":"INVALID_STATE"} |

Bằng chứng đầy đủ: evidence/business-api-results.json. Đây là kiểm thử quy trình qua API, không gọi là E2E giao diện.

## 3. Luồng qua giao diện

| Lượt chạy | Kết quả | Giải thích |
| --- | --- | --- |
| Auth UI | 6 PASS | 6 tài khoản đăng nhập, đúng role/shell và đăng xuất |
| Business UI — attempt 1 | FAIL trong test harness | Cuộn sai hướng để tìm picker; chưa gửi tin, chưa tạo fixture |
| Business UI — attempt 2 | FAIL trong test harness | Ô giá bị bàn phím che; chưa gửi tin, chưa tạo fixture |
| Business UI — attempt 3 | FAIL — lỗi sản phẩm FE-001 | Seller đã gửi tin 5538 có ảnh; Appraiser duyệt BE thành công, FE lỗi khi quay về queue |
| Bidder UI — attempt 1 | FAIL trong test harness | Nạp ví A 10.000đ đã thành công; test chờ nút cọc chưa được dựng vì danh sách đang ở trên cùng |
| Bidder UI — attempt 2 | PASS | Sửa điều kiện chờ, dùng ví đã có tiền; không nạp lại; kiểm tra cọc, đặt giá, quay lại và logout cho hai bidder |

Hai lỗi cuộn và lỗi chờ widget là lỗi của script test mới, không kết luận ứng dụng hỏng vì các lỗi đó. Lịch sử thất bại được giữ, không bị xóa khi có lượt chạy sau.

| Checkpoint đã quan sát | Kết quả | Dữ liệu | Log |
| --- | --- | --- | --- |
| UI-SELLER | PASS | {"listingId":"5538","status":"pending_appraisal","photoCount":1} | business-ui-attempt3.log |
| UI-TOPUP-BIDDER_A | PASS | {"amount":10000,"before":{"balance":199000,"held":1000,"available":199000,"joinBlockedUntil":null},"after":{"balance":209000,"held":1000,"available":209000,"joinBlockedUntil":null}} | bidder-ui-attempt1.log |
| UI-JOIN-BIDDER_A | PASS | {"auctionId":"5507","deposit":1000,"wallet":{"balance":208000,"held":2000,"available":208000,"joinBlockedUntil":null}} | bidder-ui-attempt2.log |
| UI-BID-BIDDER_A | PASS | {"auctionId":"5507","currentPrice":60000,"bidCount":1,"connected":true} | bidder-ui-attempt2.log |
| UI-BACK-BIDDER_A | PASS | {"homeVisible":true} | bidder-ui-attempt2.log |
| UI-JOIN-BIDDER_B | PASS | {"auctionId":"5507","deposit":1000,"wallet":{"balance":198000,"held":2000,"available":198000,"joinBlockedUntil":null}} | bidder-ui-attempt2.log |
| UI-BID-BIDDER_B | PASS | {"auctionId":"5507","currentPrice":110000,"bidCount":2,"connected":true} | bidder-ui-attempt2.log |
| UI-BACK-BIDDER_B | PASS | {"homeVisible":true} | bidder-ui-attempt2.log |

Fixture UI: listing **5538**, auction **5507**, tên **E2E_1793115542027_UI**, thời lượng 24 giờ.

Giới hạn chọn ảnh: test cấp byte ảnh PNG mẫu qua callback PhotoPicker có sẵn, không tự thao tác thư viện ảnh Android. Việc upload ảnh, tạo tin và gửi thẩm định đều chạy thật qua UI/BE. Vì vậy đây là luồng UI có thay thế đầu vào thư viện ảnh, không khẳng định đã test native picker.

Ảnh evidence/auction-5507-device.png ghi lại chi tiết phiên thực sự hiển thị trên Android; ảnh này không phải bằng chứng toàn bộ journey PASS.

## 4. Lỗi FE-001 — setState trả về Future sau duyệt tin

**Kết quả: FAIL. Mức ảnh hưởng: lỗi assertion trong bản debug khi quay lại hàng chờ sau duyệt; chưa kết luận bản release crash.**

Vị trí: lib/screens/appraiser/appraiser_ops_screen.dart:49, được gọi từ callback quay về danh sách ở dòng 108. `_refresh()` dùng `setState(() => _future = next)`. Phép gán trả về chính Future `next`, nên callback trả Future và Flutter phát assertion `setState() callback argument returned a Future.`

Các bước tái hiện: đăng nhập Appraiser → mở tin pending_appraisal do Seller vừa gửi → Duyệt và mở phiên → xác nhận Duyệt → quay về Hàng chờ. Kỳ vọng: queue tải lại, không lỗi framework. Thực tế: BE đã chuyển tin sang live và tạo auction 5507; FE phát assertion lúc refresh queue. Đối chiếu độc lập GET listing xác nhận live, nên không kết luận BE duyệt thất bại.

Bằng chứng: evidence/business-ui-attempt3.log và evidence/ui-fixture-state.json. Assertion `_pendingFrame == null` ở cuối cùng là lỗi tiếp theo sau thất bại, không coi là nguyên nhân ban đầu.

Hướng sửa đề xuất, chưa thực hiện: dùng callback setState dạng khối chỉ gán `_future`, không trả Future; giữ await/catch bên ngoài. Sau khi nhóm sửa, chạy lại luồng UI xuyên role với fixture mới. Không tắt FlutterError.onError, không nuốt assertion để làm test xanh.

## 5. Dữ liệu đã thay đổi và trạng thái còn lại

Không sửa trực tiếp database, không seed/reset dữ liệu chung. Hai tin/phiên E2E đã tạo được giữ lại để đối chiếu. Tiền nạp là giả lập; không thu tiền thật.

- Created draft listing 5537

- Approved listing 5537; auction 5506 opened

- BIDDER_A: simulated top-up +200000 VND

- BIDDER_A: held deposit 1000 VND for auction 5506

- BIDDER_B: simulated top-up +200000 VND

- BIDDER_B: held deposit 1000 VND for auction 5506

- Bidder A placed 60000 VND

- Bidder B placed 110000 VND

- UI Seller đã upload 1 ảnh mẫu, tạo/gửi listing 5538; Appraiser đã mở auction 5507 trước khi gặp lỗi FE.

- UI Bidder A đã nạp thêm 10.000đ trong bidder-ui-attempt1; lần chạy tiếp không nạp lặp. Các thao tác cọc/giá đã chạy được liệt kê ở bảng checkpoint và final-state.json nếu có.

Các phiên đang active có thể tự chốt khi hết thời lượng và tạo đơn thắng. Chưa tự rút ngắn phiên, hủy phiên, giải phóng cọc, thanh toán đơn hoặc xóa dữ liệu. Nhóm cần quản lý các fixture này sau buổi test; không coi đây là dữ liệu đã dọn sạch.

| Ví tại lần đọc cuối | Khả dụng (VND) | Cọc giữ (VND) | Tổng nạp giả lập trong đợt |
| --- | --- | --- | --- |
| BIDDER_A | 208000 | 2000 | 210000 |
| BIDDER_B | 198000 | 2000 | 200000 |

Trạng thái đọc lúc 2026-10-27T15:47:42.725Z. Cả hai phiên 5506 và 5507 đều active, mỗi phiên có 2 lượt giá, giá hiện tại 110.000đ, Bidder B dẫn đầu; mỗi bidder giữ cọc 1.000đ/phiên. Phiên 5506 dự kiến hết lúc 23:29 ngày 27/10/2026 và phiên 5507 lúc 22:39 ngày 28/10/2026, giờ Việt Nam (UTC+7), theo endsAt tại lần đọc.

## 6. Chưa kiểm thử trong đợt này

| Phạm vi | Kết quả | Lý do |
| --- | --- | --- |
| Native Android photo picker | NOT RUN | Đầu vào ảnh được chèn có kiểm soát |
| Hai app UI đồng thời cạnh tranh realtime | NOT RUN | Một máy ảo đổi hai bidder tuần tự; realtime transport được kiểm tra riêng bằng socket client |
| Thắng phiên, thanh toán, giao hàng, tranh chấp | NOT RUN | Ngoài chuỗi yêu cầu thực thi hiện tại; chưa ép đóng hoặc đổi thời gian các phiên |
| Chức năng Warehouse/Admin ngoài login | NOT RUN | Chỉ xác nhận đăng nhập/role, chưa tạo giao dịch kho hay xử lý quản trị |
| Bản release APK / web React / web Flutter | NOT RUN | Chạy Android debug integration_test |
| Tải, bảo mật toàn diện, mất mạng/reconnect | NOT RUN | Không thuộc các assertion đã chạy |

## 7. Báo cáo nền có sẵn

Người dùng cung cấp kết quả flutter analyze không issue và flutter test: 244 pass, 2 skipped. Đây là lần chạy của người dùng, không cộng thành test mới trong đợt E2E này; chưa chạy lại coverage. Hai live-order test bị skip yêu cầu DB Docker riêng, không bật lên với database chung.

## 8. Đọc và tái chạy

Mở REPORT.html để đọc/in Save as PDF từ trình duyệt. REPORT.md phù hợp chép vào docs; results.json và evidence chứa dữ liệu/log đối chiếu. tests chứa các script không có mật khẩu. Không đưa thư mục e2e-auth-private hay APK test vào gói chia sẻ.

Muốn tái chạy, cần tạo fixture mới và cấu hình local tài khoản ngoài Git. Script business_flow.mjs chặn chạy đè khi đã có business-api-results.json để tránh nạp/cọc lặp. Không chạy lại mode resume trên phiên đã tham gia; test có guard joined=false. Các đường dẫn trên máy trong script cần điều chỉnh nếu chạy máy khác. Không chạy nguyên lại các ca ghi dữ liệu khi chưa đọc trạng thái hiện tại.

Báo cáo tạo lúc 2026-10-27T15:49:15.964Z. Không chỉnh sửa code sản phẩm để đổi kết quả FAIL thành PASS.