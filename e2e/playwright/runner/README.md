# BidVibe — Playwright E2E

Bộ test thao tác trên **Flutter Web của bidvibe_fe** bằng Chrome, gọi BE thật. Đây không phải project bidvibe_web riêng. Playwright chạy kịch bản; ChatGPT hỗ trợ viết, thực thi và phân tích kết quả. Khi đã cài đặt xong, chạy lại không cần mở ChatGPT.

## Đọc theo thứ tự

1. README này: cách chạy, phạm vi và dữ liệu cần chuẩn bị.
2. REPORT.md trong gói báo cáo: kết quả PASS/FAIL, lỗi và giới hạn.
3. tests/: mã kịch bản theo thứ tự 01–16.
4. Bằng chứng: JSON kết quả, JSON checkpoint, ảnh lỗi; báo cáo Playwright gốc chỉ giữ riêng trên máy.

## Đưa vào project ở đâu?

Đặt thư mục bộ chạy tại `bidvibe_fe/e2e/playwright/`. Đặt báo cáo tại `bidvibe_fe/docs/testing/report/2026-10-31-playwright/`. Đây là hướng dẫn để Hào tự sao chép; bộ bàn giao chưa được chép vào source thật, chưa commit/push.

Giữ package.json, package-lock.json, playwright.config.ts, tests/, support/, scripts/, assets/, README và hai file cấu hình example. Không commit node_modules/, reports/, private-run/ hoặc các file *.local.json chứa cấu hình/tài khoản. Các file example để trống thông tin đăng nhập được phép commit.

## Cài đặt một lần

Yêu cầu Node.js, npm, Google Chrome, Flutter và một bản BE local có dependencies + .env trỏ đúng DB mà API đang dùng. BE local chỉ cần cho bộ điều khiển thời gian phiên kiểm thử; không chạy thêm toàn bộ server/scheduler.

Tại thư mục gốc FE, kiểm tra config/dev.json trỏ đúng API rồi build:

```cmd
flutter pub get
flutter build web --debug --no-web-resources-cdn
```

Dùng debug để bắt lỗi assertion của Flutter. Đây là bản web build phục vụ kiểm thử tại máy, không cần deploy Netlify lần nữa. Khi sửa code FE, phải build lại để Playwright kiểm tra bản mới.

Tại `e2e\playwright`:

```cmd
npm ci
copy runner.local.example.json runner.local.json
copy credentials.local.example.json credentials.local.json
```

Điền sáu tài khoản vào credentials.local.json trên máy. Điền runner.local.json:

- BIDVIBE_CREDENTIALS_FILE: đường dẫn credentials.local.json.
- BIDVIBE_WEB_BUILD_DIR: `../../build/web` nếu đặt đúng cấu trúc trên.
- BIDVIBE_BE_ROOT: đường dẫn tuyệt đối đến bidvibe_be. Dependencies BE phải được cài sẵn. Không chép .env BE vào FE.
- BIDVIBE_API_URL: API đích; phải khớp URL được build trong FE và DB của .env BE.
- BIDVIBE_ALLOW_SHARED_MUTATIONS: để `false` khi chỉ chạy đăng nhập; đổi thành chuỗi `"true"` khi chủ động chạy nghiệp vụ trên DB được cho phép.

Các đường dẫn cấu hình được tính từ thư mục bộ chạy. Bản bộ chạy nằm ngoài project được cung cấp trong workspace đã có runner.local.json riêng trỏ đến bản build cô lập; file đó không nằm trong ZIP chia sẻ.

## Chạy trước lớp

Chạy đăng nhập sáu tài khoản, nhìn thấy trình duyệt tự thao tác:

```cmd
npm run test:auth -- --headed
```

Lệnh này gồm kiểm tra accessibility + 6 bài đăng nhập/đúng role/đăng xuất, không tạo phiên hay nạp ví. Bộ này đã được chạy lại sau khi hoàn thiện lệnh và PASS 7/7.

Liệt kê đủ 30 ca, không thực hiện nghiệp vụ:

```cmd
npm run test:list
```

Chạy **toàn bộ** theo thứ tự (gồm cả đăng nhập):

```cmd
npm run test:business -- --headed
```

Bộ chạy tự tạo mã lần chạy, thư mục dữ liệu riêng và prefix phiên riêng. Không cần gõ `set` mỗi lần. Tất cả chạy tuần tự với một worker, không retry tự động. Mỗi lần chạy nghiệp vụ tạo dữ liệu và giao dịch ví kiểm thử mới trên DB đích. Chỉ chạy một bộ cùng lúc; cổng 8886 và 8891 phải rảnh.

**Bản source hiện tại có lỗi UI thật nên không kỳ vọng tất cả PASS.** Chạy lại không tự sửa lỗi. Chỉ cập nhật kết quả PASS khi đã sửa code, build lại và thực thi thành công. Sau sửa lỗi nên chạy lại cả hành trình bằng dữ liệu mới; không chạy lại riêng thao tác thanh toán/hoàn tiền đã thành công chỉ vì assertion giao diện FAIL.

Nếu chỉ muốn xem trước khởi động bộ thời gian và danh sách bài, không tạo dữ liệu:

```cmd
npm run test:business -- --list
```

Lệnh đầy đủ sau khi tổ chức lại bộ chạy đã được kiểm tra discovery và khởi động/dừng clock; bộ nghiệp vụ có ghi dữ liệu được thực thi trong các lượt theo giai đoạn mô tả trong REPORT, chưa chạy lại toàn bộ từ đầu sau thay đổi cách đóng gói.

## Kịch bản nghiệp vụ

1. Đăng ký bidder mới bằng UI; seller tải ảnh thật qua file chooser, tạo/gửi listing.
2. Appraiser duyệt bằng UI. Test kiểm tra cả BE lẫn việc quay về hàng chờ không lỗi.
3. Hai browser context độc lập đăng nhập bidder A và bidder mới, nạp ví qua UI, đặt cọc, cạnh tranh đặt giá và kiểm tra cập nhật realtime.
4. Clock rút ngắn **chỉ phiên mới của lượt chạy** còn 8 giây rồi gọi service kết thúc đã hết hạn. Đây là chuẩn bị dữ liệu, không phải UI thao tác thời gian.
5. Kiểm tra người thắng/đơn thắng, hoàn cọc người thua; tạo/chọn địa chỉ, thanh toán ví qua UI.
6. Seller gửi kho; warehouse nhận → kiểm định khớp → đóng gói → gửi vận chuyển → giao. Buyer xác nhận nhận hàng, kiểm tra giải ngân.
7. Đọc các màn Admin. Tạo thêm một fixture riêng qua API để thử báo cáo, pause/verify/safe qua UI.
8. Nếu tài khoản bidder B cung cấp vẫn đang bị hạn chế JOIN_BLOCKED: kiểm tra lý do từ chối hiển thị đúng. Nếu hết hạn, ca này SKIP, không tính PASS và không tự tạo vi phạm để khóa tài khoản.
9. API chuẩn bị đơn đã thanh toán QR mô phỏng để test tranh chấp. Buyer mở tranh chấp bằng UI; Admin hoàn tiền bằng UI, buyer vẫn đăng nhập nhận notification:new và ví tăng.
10. Đăng nhập lại, đọc thông báo giao hàng đã lưu và mở đúng đơn.

Hai bài SETUP-* được ghi riêng là **API setup**, không tính là E2E giao diện. QR là mô phỏng của hệ thống, không kiểm thử chuyển tiền ngân hàng thật. Giao hàng là chuyển trạng thái thử nghiệm, không gửi kiện hàng thật.

## Dữ liệu và an toàn khi chạy lại

Đợt kiểm thử dùng chung Supabase với nhóm. Không reset DB, không seed toàn bộ, không đổi thời gian phiên của người khác. Clock chỉ nhận phiên có prefix lượt chạy, tuổi dưới 6 giờ, đúng seller/title và đối chiếu cùng record qua API. Một DB connection, bind localhost, khóa riêng; dừng cùng bộ chạy.

Bidder B ban đầu đang bị hạn chế tham gia từ các đơn cũ; ca đấu giá tích cực dùng một bidder mới đăng ký tự động. Không bỏ qua hay gỡ hạn chế tài khoản cũ. Thông tin bidder mới nằm trong private-run/<run>/fresh-bidder.local.json; không đưa lên Git.

Khi test FAIL sau HTTP thành công, giao dịch có thể đã được lưu. Đọc state + API + báo cáo trước khi chạy lại. Không coi thông báo lỗi UI là bằng chứng giao dịch chưa xảy ra. Không xóa dữ liệu thử nghiệm đang dùng làm bằng chứng.

## Báo cáo được sinh ở đâu?

Mỗi lần thực thi có thư mục `reports/<run-id>/`:

- html/index.html: báo cáo Playwright, click từng bài xem lỗi và ảnh.
- results.json: kết quả máy đọc; đây mới là JSON, không dán terminal log vào file này.
- junit.xml: kết quả để tích hợp CI.
- artifacts/: ảnh thất bại, error context, attachment, trace cho bài được bật.

Mở bằng đúng đường dẫn thư mục HTML được in sau chạy:

```cmd
npm run report -- reports/<run-id>/html
```

Thay `<run-id>` bằng tên thư mục thật. Trong báo cáo tổng hợp: **mã ca → file test → lần chạy/kết quả → checkpoint JSON/ảnh**. Ví dụ PW-WH-01 → tests/08-warehouse.spec.ts → lượt fulfilment → warehouse-transition JSON cho thấy HTTP thành công và ảnh cho thấy thông báo sai.

Raw report/trace có thể chứa dữ liệu đăng nhập hoặc token trong mạng, kể cả trace bắt đầu sau login. Chỉ mở tại máy, không đưa cả reports lên Git/Drive công khai. Gói báo cáo tổng hợp chia sẻ đã chọn bằng chứng riêng và bỏ credential/trace.

## Phạm vi chưa chứng minh

Không phải kiểm thử tất cả chức năng hay tất cả thiết bị. Chưa bao phủ tải cao, bảo mật, ngân hàng thật, gửi hàng thật, Safari/Firefox, Android native, mất mạng/reconnect và tất cả nhánh tranh chấp. Kết quả là cho snapshot FE đã ghi trong REPORT, không tự áp dụng cho commit mới hoặc bản release đã deploy.

Thông báo realtime yêu cầu đang đăng nhập và kết nối; thông báo đã lưu đọc được sau lần đăng nhập tiếp theo. Đợt này đã chứng minh realtime hoàn tiền khi buyer còn đăng nhập và lịch sử thông báo giao hàng + điều hướng; không kết luận mọi sự kiện vận chuyển đã được kiểm thử realtime.
