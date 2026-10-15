# BidVibe FE

Ứng dụng Flutter cho nền tảng đấu giá BidVibe. Tài liệu này giúp thành viên mới chạy app, xác định phần Hào đã tích hợp API và tiếp tục công việc của Hiệu, Khang.

## Bắt đầu

1. Clone repository và chuyển sang nhánh nhóm dùng để tích hợp.
2. Đọc [Cài đặt và chạy app](docs/setup.md).
3. Xem [Tiến độ thực tế](docs/progress.md) trước khi cho rằng màn hình đang dùng dữ liệu thật.
4. Xem [Phân công](docs/team-tasks.md), nhận đúng đầu việc và tạo nhánh cá nhân từ `develop`.
5. Khi nối màn hình giữa các module, làm theo [Bàn giao và tích hợp](docs/handoff.md).

```powershell
git clone https://github.com/haoltse182646/bidvibe_fe.git
cd bidvibe_fe
git fetch origin
git switch develop
flutter pub get
flutter devices
flutter run -d emulator-5554
```

Nếu chưa có nhánh `develop` ở máy: dùng `git switch --track origin/develop`. ID máy ảo phải khớp kết quả `flutter devices`. Trước khi chạy app cần chuẩn bị `config/dev.json` và khởi động BE theo hướng dẫn cài đặt.

## Tài liệu nhóm

| Tài liệu | Dùng để làm gì |
|---|---|
| [setup.md](docs/setup.md) | Flutter, cấu hình URL BE, Android Emulator, lỗi kết nối thường gặp |
| [architecture.md](docs/architecture.md) | Cấu trúc code, state, API client, repository và socket |
| [screens-and-flows.md](docs/screens-and-flows.md) | Màn hình, điểm vào và luồng nghiệp vụ theo role |
| [api-integration.md](docs/api-integration.md) | API đã dùng, API chờ tích hợp và quy tắc gọi |
| [team-tasks.md](docs/team-tasks.md) | Phân công Hào–Hiệu–Khang, thứ tự làm và tiêu chí bàn giao |
| [progress.md](docs/progress.md) | Những gì đã làm, kiểm thử và trạng thái ghép code |
| [handoff.md](docs/handoff.md) | Hợp đồng điều hướng, dùng chung địa chỉ, thông báo và đơn hàng |
| [testing.md](docs/testing.md) | Test tự động, kiểm thử thủ công và phối hợp nhiều role |
| [git-workflow.md](docs/git-workflow.md) | Nhánh cá nhân, PR, review và merge |

## Trạng thái tài liệu

Cập nhật ngày **16/10/2026**, dựa trên các bộ code đã bàn giao, bản QA và kiểm tra chỉ đọc checkout của Hào. Tại thời điểm kiểm tra, nhánh local là `feature/Hao` và còn thay đổi chưa commit; chưa xác minh code đã được push hoặc merge vào `develop`/`main` trên GitHub. Khi đưa bộ docs này lên repo, Hào phải cập nhật bảng tiến độ theo PR/commit thực tế.

Có màn hình trong source chưa có nghĩa đã tích hợp API. Các màn demo cũ vẫn có thể tồn tại. Phần bidder cốt lõi đã được chuyển sang API theo [tiến độ](docs/progress.md); các màn seller, ops và sau bán cần người phụ trách xác nhận riêng.

Không đưa token, mật khẩu tài khoản thử nghiệm hoặc khóa Supabase vào docs. Lấy hợp đồng API gốc từ `docs/api.md`, collection/environment Postman và `docs/socket.md` của repo BE; tài liệu FE chỉ ghi cách các màn sử dụng chúng.
