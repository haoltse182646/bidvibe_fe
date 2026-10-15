# Nhánh, review và cập nhật docs

## Quy ước nhóm

- `main`: bản ổn định dùng demo/release sau kiểm thử.
- `develop`: ghép tính năng trước khi đưa lên main.
- Nhánh cá nhân/tính năng: tách từ develop mới nhất. Ví dụ đề xuất `feature/hieu-orders`, `feature/khang-admin`; đây là tên gợi ý, không xác nhận đã tồn tại.
- Nhánh Hào thực tế tại lần kiểm tra là `feature/Hao`. Giữ đúng tên/case khi push hoặc mở PR.

Tài liệu này đề xuất quy trình nhóm, không khẳng định branch protection đã được bật trên GitHub. Repo owner cũng nên đi qua review để tránh đưa lỗi trực tiếp vào main.

## Bắt đầu việc mới

Kiểm tra và lưu công việc đang làm trước khi chuyển nhánh. Không chạy switch/merge trên working tree có thay đổi chồng lấn mà chưa hiểu chúng thuộc task nào.

```powershell
git status
git fetch origin
git switch develop
git pull --ff-only origin develop
git switch -c feature/ten-tinh-nang
```

Thay tên nhánh bằng task thực tế, không dùng nguyên tên ví dụ cho mọi người. Nếu nhánh đã tồn tại, dùng switch, không tạo lại. Nếu local develop chưa có, tạo tracking từ origin/develop. Nếu pull --ff-only thất bại, xem lịch sử và thống nhất cách đồng bộ, không force push để che khác biệt.

## Cập nhật khi develop có thay đổi

Trên nhánh cá nhân, sau khi đã lưu công việc:

```powershell
git fetch origin
git merge origin/develop
```

Nếu conflict: đọc cả hai thay đổi, giữ được nghiệp vụ của các bên, xóa marker, chạy analyzer/test, rồi stage đúng file và commit merge. Current là nhánh đang đứng, Incoming là nhánh đang merge vào; không bấm Accept Current cho toàn bộ chỉ vì đó là code mình.

## Commit và PR

1. Xem git diff và git status.
2. Stage các file thuộc task; kiểm tra không có token/config bí mật.
3. Commit có mô tả bằng `git commit -m "..."`.
4. Push nhánh cá nhân, mở PR vào develop.
5. Hào review; người làm xử lý conflict/lỗi trên nhánh cá nhân, cập nhật test/docs.
6. Merge PR sau khi đạt điều kiện nhóm; smoke test develop sau ghép.

Hào không cần switch sang mọi nhánh để sửa trực tiếp. Ưu tiên nhận PR, góp ý và yêu cầu tác giả cập nhật; nếu Hào trực tiếp sửa nhánh của người khác thì thống nhất trước để tránh ghi đè công việc.

PR cần nêu vấn đề và hành vi mới, màn hình/API đã đổi, ảnh nếu đổi layout, kiểm thử đã chạy, phần cần nối với thành viên khác và docs được cập nhật. Không ghi “đã xong toàn bộ” nếu còn route tạm hoặc chỉ dùng mock.

## Đưa bộ docs này vào repo

Chép README.md vào gốc repo và thư mục docs/ vào cùng cấp với lib/. Giữ các README lồng trong assets/platform nếu không liên quan. Nếu repo đã có README/docs mới từ thành viên khác, ghép nội dung thay vì ghi đè mất thông tin.

```powershell
git diff -- README.md docs
git status
git add README.md docs
git commit -m "docs: document FE modules, tasks and integration workflow"
```

Lệnh trên chỉ stage docs. **Code Hào còn modified/untracked phải được kiểm tra, commit và push qua PR phù hợp nữa**; chỉ đẩy docs không khiến thành viên clone được code. Chưa xác minh nhánh remote chứa các file mới nên Hào phải cập nhật progress.md bằng commit/PR thực tế.

## Từ develop lên main

Sau khi các PR tính năng đã ghép và kiểm thử xuyên role đạt, mở PR develop → main. Đọc diff tổng, chạy smoke test trên bản tích hợp và cập nhật tiến độ. Không dùng force push hoặc thay toàn bộ main để bỏ qua conflict.

Thành viên bắt đầu task tiếp theo cần lấy develop mới nhất rồi tạo nhánh tính năng. Không tiếp tục một nhánh cũ mà không đồng bộ trạng thái tích hợp.

## Trách nhiệm docs

| Thay đổi | Người cập nhật | File cần xem |
|---|---|---|
| Màn hình/luồng mới | Người làm module | screens-and-flows, api-integration, progress |
| API/route/callback thay đổi | Người làm + bên nhận bàn giao | api-integration, handoff |
| Phân công/phạm vi đổi | Hào cùng người nhận task | team-tasks, progress |
| Cấu hình/thư viện/cách chạy đổi | Người sửa phần dùng chung | setup, architecture, README |
| Kiểm thử/merge hoàn tất | Người thực hiện/leader | testing, progress |

Cập nhật docs trong cùng PR với code khi có thể. Hào kiểm tra thông tin có khớp mã và phạm vi thực tế trước khi merge.
