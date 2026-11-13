# E2E performance and verification — 13/11/2026

## Cách chạy lại

Mở `C:/Users/haolu/Documents/flutter/bidvibe_fe`, bấm `run-e2e-dashboard.cmd`, chọn Web / Android / Connected / Tất cả rồi bấm chạy. Đợi hoàn tất và Cleanup PASS trước khi xuất HTML, JSON hoặc JUnit. Máy ảo có thể được runner mở theo cấu hình; không tự chạy flutter run song song hoặc thao tác vào app trong lúc test.

Dùng Tất cả khi cần một lượt và báo cáo tổng hợp chung. Kết quả xác nhận dưới đây đến từ **ba lượt độc lập**, có báo cáo riêng; riêng Connected đã trực tiếp nối Web và Android trong cùng lượt.

## Thay đổi

- Connected dùng lại session chỉ sau khi xác minh đúng email và role; đổi role vẫn đăng nhập qua UI.
- Đợi nút hiện/được bật và dữ liệu đúng đơn kho tải xong thay vì chỉ thấy tiêu đề route. Giảm các khoảng nghỉ cố định dư thừa.
- Android API actors phụ dùng lại token đã xác minh đúng role/email trong lượt chạy. UI login vẫn được thực hiện khi đổi role và BE vẫn kiểm tra quyền từng request.
- Lỗi khôi phục phiên trong bước chuẩn bị có đường phục hồi UI Về đăng nhập và được ghi sessionSetupRecovery; không tự chạy lại thao tác tiền/đơn. X-R05 kiểm tra giữ phiên không cho phép phục hồi này.
- Web dùng hàng đã tải đúng ID + tiêu đề; chỉ refresh/phân trang khi cần, vẫn từ chối nhầm fixture.
- Flutter TestTextInput tránh sự kiện bàn phím cũ ghi đè nội dung; không bao phủ Gboard/IME. API và Socket.IO vẫn chạy thật.
- Native giữ ảnh mốc quan trọng + mọi FAIL; mọi case vẫn có assertion, checkpoint và log. Android tiếp tục chạy luồng chính 16 bước trước các case còn lại.

## Kết quả đã xác nhận

| Bộ | PASS | FAIL / SKIP / BLOCKED | Thời gian toàn lượt | Run ID |
|---|---:|---|---|---|
| web | 29 | 0 / 0 / 0 | 0m 49s | 2026-11-13T10-24-06-923Z-ccd257 |
| mobile | 66 | 0 / 0 / 0 | 8m 11s | 2026-11-13T10-13-01-436Z-f57faf |
| connected | 47 | 0 / 0 / 0 | 8m 02s | 2026-11-13T10-04-25-885Z-8a64d5 |

Connected giảm khoảng **14.1%** so với mốc lịch sử 9m 21s. Đây là các lần đo khác ngày, không phải benchmark trong cùng điều kiện. Không cam kết thời gian cố định hoặc mọi lần đều nhanh hơn.
Android ở lượt mới chưa nhanh hơn mốc 7m 27s ngày 11/11; Web cũng chưa có phép đo đối chứng cùng điều kiện. Các thay đổi đã giảm đăng nhập/tải lại dư thừa và sửa đồng bộ, nhưng không được diễn giải thành cả ba bản đều nhanh hơn. Số đo trong bảng là thực tế, bao gồm chuẩn bị, build, scheduler và cleanup.

Cleanup và kiểm tra DB chỉ đọc đều PASS. Xem cleanup-result.json, cleanup-verified.json và OPTIMIZATION-RESULT.json của từng lượt. Phân tích mã: No issues found. Kiểm tra nội bộ: 20 PASS.

Hai lượt chẩn đoán trước có lỗi và đã dừng được giữ nguyên trong reports: 2026-11-13T09-43-20-389Z-710cdb (restore timeout); 2026-11-13T09-55-41-488Z-890769 (chờ dữ liệu kho và API login phụ timeout). Các FAIL/SKIP/BLOCKED không bị đổi thành PASS. Dữ liệu hai lượt đó đã được dọn và kiểm tra lại.

## Bằng chứng

Tổng quan dễ mở: `e2e/system/reports/validation-2026-11-13/index.html`. Mỗi lượt có REPORT-{suite}-verified.html nhúng ảnh, mã test source/ + SHA-256, events.ndjson, log, báo cáo JSON và audit cleanup. Reports/private-run bị gitignore; chia sẻ file HTML verified nếu cần trình bày trên máy khác. Không đưa config/credentials local, .env, private-run, backup hoặc APK test vào Git.

Cleanup chỉ xóa dữ liệu DB thuộc lượt test, sau khi lưu bằng chứng/backup riêng. Object ảnh upload được giữ trên storage. QR/nạp ví/vận chuyển là mô phỏng của ứng dụng; ảnh đi qua callback PhotoPicker, không kiểm thử native gallery.

Muốn giảm tải đồ họa khi không cần nhìn cửa sổ Web, có thể đặt headed=false trong cấu hình local. Giữ captureScreenshots=true để có ảnh mốc. Không chạy flutter clean trước mọi lượt; chỉ dùng khi xử lý lỗi build/cache. Không tăng retry hoặc bỏ assertion để đạt PASS.
