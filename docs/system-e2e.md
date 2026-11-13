# BidVibe Web Mobile and Connected E2E

## Mục đích

Bộ chạy kiểm thử repo React `bidvibe-web`, ứng dụng Android Flutter `bidvibe_fe` và luồng phối hợp giữa hai nền tảng dùng cùng BE/database. Dashboard local hiển thị kết quả trong khi test đang chạy và cho xuất báo cáo theo phạm vi.

Repo React hiện có landing page và Admin. Các màn bidder, seller, appraiser và warehouse thuộc app Flutter. Bộ Web trong tài liệu này kiểm thử React; bộ Playwright Flutter Web trước đây được giữ riêng.

## Cấu trúc file

```text
bidvibe_fe/
  run-e2e-dashboard.cmd
  analysis_options.yaml
  integration_test/
    android_business_e2e_test.dart       (bổ sung tài khoản âm riêng tùy cấu hình)
    mobile_web_e2e_test.dart             (mới)
  e2e/
    playwright/runner/                  (dependency và credentials đã có)
    system/
      .gitignore
      dashboard.mjs
      dashboard.html
      report-store.mjs
      report-store.test.mjs
      fixtures.mjs
      web-suite.mjs
      mobile-run.mjs
      mobile-plan.json
      invoke-flutter.ps1
      runner.local.example.json
      runner.local.json                 (chỉ trên máy)
      private-run/                      (defines và log riêng)
      reports/<run-id>/
        REPORT-all.html
        REPORT-web.html
        REPORT-mobile.html
        REPORT-connected.html
        results.json
        events.ndjson
        source/
        evidence/
```

## Cấu hình lần đầu

Chép nội dung `files/` của gói bàn giao vào gốc FE. Chỉ thêm bộ chạy/test và cập nhật cấu hình analyzer để bỏ qua artifact tự sinh. Không chép các thư mục tham chiếu hoặc config riêng từ máy khác.

Tại gốc FE:

```cmd
copy e2e\system\runner.local.example.json e2e\system\runner.local.json
```

Mở `runner.local.json` bằng VS Code. Không gõ JSON vào terminal.

- `frontendRoot`: `../..` nếu bộ chạy nằm đúng trong `bidvibe_fe/e2e/system`.
- `webRoot`: thư mục React `bidvibe-web` đã clone từ GitHub, ví dụ `C:/Users/haolu/Documents/reactjs/bidvibe-web`.
- Mặc định bộ chạy mở React local tại `http://127.0.0.1:5186` từ source trong `webRoot`, gọi BE Render thật. Nếu cần kiểm tra bản React đã deploy, có thể thêm `webURL` trỏ đúng website React đó; khi ấy bộ chạy dùng URL này và không mở Vite. Link `bidvibe.netlify.app` trước đây là Flutter Web, cần phân biệt với website React. Commit source tham chiếu trên máy không tự chứng minh phiên bản đang deploy giống hệt source đó.
- `backendRoot`: thư mục BE có dependency và `.env` nối đúng database mà API Render dùng. Bộ chạy chỉ dùng service kiểm soát thời gian cho phiên E2E; không cần mở toàn bộ BE bằng `npm run dev`.
- `credentialsFile`: mặc định `../playwright/runner/credentials.local.json`. Dùng lại sáu tài khoản kiểm thử; không đưa mật khẩu vào config mẫu.
- `playwrightRoot`: mặc định `../playwright/runner`; dependency `@playwright/test` phải được cài ở đó.
- `flutterCommand`: đường dẫn Flutter trên máy.
- `deviceId` và `launchEmulatorId`: mặc định `emulator-5554` và `Pixel_4a`.
- `allowSharedDatabaseMutations`: đặt `true` trên database được phép tạo dữ liệu E2E.
- `headed`: `true` để xem Chrome tự thao tác; `false` nếu cần chạy trình duyệt ẩn.
- `prepareRestrictedBidder`: mặc định `true`. Chuẩn bị một bidder E2E riêng có hai đơn quá hạn để ca JOIN_BLOCKED có thể chạy lặp lại; không tạo vi phạm cho tài khoản mẫu.
- `dashboardPort`: mặc định 8890; `webPort`: mặc định 5186. Bộ điều khiển Android dùng cổng 8892.
- `openDashboard`: mặc định `true` để tự mở trang kết quả.

Nếu dependency chưa có, chạy `npm ci` riêng trong thư mục React Web và trong `bidvibe_fe/e2e/playwright/runner`. Cần Node.js phù hợp project, Chrome, Flutter và Android SDK. Không cần cài Appium để dùng bộ này.

File `analysis_options.yaml` bàn giao bổ sung hai đường dẫn loại trừ `e2e/system/private-run/**` và `e2e/system/reports/**`. Nếu nhóm đã sửa thêm cấu hình analyzer, chỉ thêm hai đường dẫn vào mục `exclude` đang có.

## Chạy bằng một lần bấm

Bấm đúp `run-e2e-dashboard.cmd` ở gốc FE. Mở `http://127.0.0.1:8890` nếu trình duyệt chưa tự mở.

Chọn một trong bốn chế độ rồi bấm **Bắt đầu kiểm thử**:

| Chế độ | Nội dung |
|---|---|
| React Web | Landing, xác thực Admin, đọc dữ liệu, tải báo cáo tuần, quản lý tài khoản thử, xử lý cờ và tranh chấp |
| Android mobile | 66 case nghiệp vụ Android; không tính auth/đăng ký riêng. Xem [Android business E2E](android-business-e2e.md) |
| Connected Web ↔ Android | Cùng listing/auction/order/dispute được tạo và kiểm tra qua hai giao diện |
| All suites | Chạy lần lượt ba bộ và tạo báo cáo tổng hợp trong cùng lượt chạy |

Dashboard chỉ nhận một lượt chạy tại một thời điểm. Không tự thao tác vào Chrome hoặc máy ảo mà test đang điều khiển. Nên mở máy ảo và chờ Android boot trước giờ trình bày; bộ chạy có thể tự khởi động máy ảo theo cấu hình.

Lần build Android đầu trong thư mục mới có thể lâu hơn. Các thao tác API/readiness được chờ theo trạng thái; thời gian tổng phụ thuộc mạng, Render, database và máy.

## Luồng kết nối

1. Buyer đăng ký trên Android.
2. Seller gửi tin đăng trên Android; Appraiser duyệt trên Android.
3. Buyer nạp ví, đặt cọc và đặt giá trên Android.
4. Buyer báo cáo phiên trên Android.
5. Admin mở đúng cờ trên React Web và tạm dừng phiên.
6. Android vẫn giữ phiên đang mở, nhận trạng thái tạm dừng qua Socket.IO và hiển thị tương ứng.
7. Admin đánh dấu an toàn trên React Web; Android nhận trạng thái tiếp tục.
8. Bộ điều khiển rút ngắn đúng phiên E2E và kết thúc theo logic BE; Android xác minh người thắng/đơn thắng.
9. Buyer tạo địa chỉ và thanh toán bằng ví trên Android.
10. Buyer mở tranh chấp trên Android.
11. Admin hoàn tiền đúng tranh chấp trên React Web; Android vẫn đăng nhập và nhận sự kiện hoàn tiền đúng disputeId, có thông báo và tiền về ví.

Các bước Web actor được ghi riêng cùng các bước xác minh Android trong phạm vi `connected`. Đối chiếu auctionId, orderId, disputeId để chứng minh việc nối hai nền tảng. Chạy hai bộ riêng rồi cộng số PASS không chứng minh luồng kết nối này.

Luồng kho và xác nhận nhận hàng vẫn được kiểm tra trong chế độ mobile. React hiện chưa có UI seller/appraiser/warehouse nên bộ Web không khai báo các màn chưa được triển khai.

## Báo cáo trực tiếp và xuất kết quả

Trong lúc chạy, dashboard hiển thị WAITING, RUNNING, PASS, FAIL, SKIP hoặc BLOCKED. Các kết quả đã hoàn thành xuất hiện trước khi cả lượt chạy kết thúc. FAIL và các bước phụ thuộc bị chặn được giữ nguyên, không đổi thành PASS.

Chọn tab **Web**, **Mobile**, **Kết nối Web ↔ Android** hoặc **Tổng hợp**, rồi chọn:

- **Xuất HTML**: bản dễ trình bày, kèm ảnh trong file xuất. Mở bằng trình duyệt; có thể dùng Ctrl+P để lưu PDF.
- **Xuất JSON**: dữ liệu có cấu trúc của phạm vi đã chọn.
- **Xuất JUnit**: XML cho công cụ báo cáo/CI.

Xuất trong lúc chạy tạo **live snapshot**, có thể còn ca đang chạy hoặc chưa chạy. Chỉ bản xuất sau khi kết thúc mới là kết quả cuối. Một phạm vi không được chạy được ghi `NOT_RUN`.

Các file `REPORT-*.html` tự lưu trong thư mục lượt chạy dùng ảnh liên kết tương đối với `evidence/`; hãy giữ cả thư mục nếu chuyển chúng sang máy khác. Bản HTML tải bằng nút xuất nhúng ảnh để có thể mở độc lập.

## Truy xuất bằng chứng

Mỗi lượt có runId, commit tham chiếu của ba project, thời điểm, mã ca, kết quả, thời gian thực thi và bằng chứng. Thư mục `source/` lưu đúng mã test của lượt chạy và SHA-256 trong JSON. Commit BE là bản tham chiếu đọc trên máy; health endpoint hiện không công bố commit Render đang chạy.

Đối chiếu theo thứ tự: mã ca → mã test trong `source/` → sự kiện/log → ảnh → dữ liệu cùng auctionId/orderId/disputeId.

Bộ test báo PASS dựa trên assertion, không suy ra từ ảnh. Ảnh checkpoint có thể chụp lúc UI đang cập nhật sau khi BE đã commit; cần đọc cùng dữ liệu đối chiếu.

## Dữ liệu và giới hạn

- Mỗi lượt tạo prefix và bidder mới cho các thao tác ghi. Chỉ xử lý phiên, cờ, đơn, tranh chấp hoặc tài khoản được tạo cho lượt đó.
- Các thao tác kết thúc phiên dùng BE service với guard prefix, seller, title, tuổi dữ liệu và đối chiếu API/database. Không reset/seed/wipe database, không chạy scheduler toàn cục.
- Dữ liệu trả về từ server và báo cáo kết quả được lọc các credential đã biết. `.gitignore` loại config riêng, raw defines, private-run và reports; cần rà lại bằng chứng trước khi chia sẻ công khai.
- Không phân phối APK test có credentials biên dịch trong dart-define.
- Ảnh trong test Android được truyền vào callback PhotoPicker; thao tác thư viện ảnh Android chưa được bao phủ. Nạp ví, QR và vận chuyển là mô phỏng của ứng dụng.
- Chế độ mobile trên dashboard chuẩn bị riêng một bidder E2E cho JOIN_BLOCKED: tạo hai phiên/đơn thuộc lượt chạy, đưa deadline của đúng hai đơn đó về quá khứ bằng BE service, chờ scheduler đang chạy trên Render xử lý và xác minh hạn chế thật trước khi chạy UI. Không gọi sweep toàn cục từ công cụ test. Bằng chứng thiết lập nằm trong ca A-BLOCKED; đây là API setup, không phải thao tác end-user UI. Các tài khoản mẫu vẫn được kiểm tra đăng nhập như trước.
- Nếu đặt `prepareRestrictedBidder=false` hoặc dùng bộ chạy Android cũ, ca JOIN_BLOCKED dùng tài khoản mẫu và có thể SKIP khi hạn chế đã hết. Báo cáo giữ đúng SKIP. Bộ chạy không biến điều kiện chưa được kiểm tra thành PASS.
- Nếu một thao tác ghi bị gián đoạn, dữ liệu có thể đã được lưu. Lượt mới dùng fixture mới; không tự thử lại thanh toán hoặc hoàn tiền cũ.

## Kiểm tra bộ báo cáo

Tại gốc FE:

```cmd
node --test e2e/system/report-store.test.mjs
```

Các kiểm tra này bảo đảm báo cáo tách đúng phạm vi, không tính ca thiếu/SKIP là PASS, giữ kết quả đã hoàn thành và ghi đúng lỗi runner. Đây là unit test của bộ báo cáo, không cộng vào số ca E2E.

## Tối ưu và kết quả xác nhận mới nhất

Xem [E2E performance and verification](e2e-performance.md) để đọc thay đổi, thời gian đo và các lượt Web/Android/Connected đã chạy.
