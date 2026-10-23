# Cài đặt và chạy app

## Môi trường

- Flutter SDK có Dart đi kèm; Flutter/Dart extension cho VS Code.
- Android SDK và một máy ảo Android đã được tạo. Có thể launch từ VS Code, không cần mở Android Studio mỗi lần chạy.
- BE BidVibe được cấu hình DB/Supabase và khởi động thành công. Thiết lập BE theo README của BE; không đưa thông tin kết nối DB vào Flutter.

Để báo lỗi môi trường, gửi kết quả `flutter --version` và `flutter doctor -v`. Bản QA đã kiểm tra bằng Flutter 3.47.6 stable; đây là mốc kiểm tra, chưa phải phiên bản tối thiểu được cả nhóm chốt. Lấy ràng buộc package hiện tại từ `pubspec.yaml` và `pubspec.lock` trên nhánh đang dùng.

## Chuẩn bị FE

Chạy ở thư mục chứa `pubspec.yaml`:

```powershell
flutter doctor -v
flutter pub get
flutter devices
```

Không xóa dependency hoặc thay toàn bộ `pubspec.yaml` bằng bản cũ khi ghép module mới. App hiện sử dụng provider, http, flutter_secure_storage, socket_io_client, intl, google_fonts và image_picker.

## Cấu hình BE

Tạo hoặc kiểm tra file `config/dev.json` ở gốc project:

```json
{
  "API_BASE_URL": "http://10.0.2.2:5000"
}
```

Trong `pubspec.yaml` cần có asset:

```yaml
flutter:
  assets:
    - config/dev.json
```

Chỉ ghép mục này vào cấu hình hiện có, không tạo hai mục `flutter:`. URL chỉ là địa chỉ gốc, **không thêm `/api`**. Nếu BE chạy cổng khác, thay bằng cổng BE thực tế.

| Nơi chạy client | URL thường dùng khi BE nằm trên máy phát triển |
|---|---|
| Android Emulator chuẩn | `http://10.0.2.2:5000` |
| Postman trên máy chạy BE | `http://localhost:5000` |
| Điện thoại Android thật | IP LAN của máy chạy BE, cùng mạng |
| BE được deploy | Địa chỉ HTTPS của BE |

Main hiện tại trên máy Hào đã gọi `WidgetsFlutterBinding.ensureInitialized()` và `await ApiClient.loadConfig()` trước khi chạy app. Nhờ đó lệnh chạy ngắn đọc asset cấu hình. Nếu clone một nhánh cũ, kiểm tra hai lệnh này trong `lib/main.dart` và asset trước khi áp dụng hướng dẫn.

Socket dùng cùng địa chỉ gốc, không thêm `/api`. Đổi URL cần dừng và chạy lại app. Không chuyển token của môi trường cũ sang môi trường mới; đăng xuất và đăng nhập lại.

Để chạy Android E2E mà không thay đổi URL đang có trong `config/dev.json`, truyền `--dart-define=BIDVIBE_API_BASE_URL=http://10.0.2.2:5000`. Chỉ dùng URL này khi backend local đã được xác minh đang nối tới database thử nghiệm riêng; hướng dẫn và biến cho test account nằm trong [testing.md](testing.md#android-e2e-với-backend-cục-bộ).

## Khởi động

Terminal BE, tại thư mục backend:

```powershell
npm run dev
```

Terminal FE, tại thư mục Flutter:

```powershell
flutter run -d emulator-5554
```

Thay ID thiết bị bằng ID từ `flutter devices`. F5 chạy debug là hành vi bình thường; cấu hình VS Code phải dùng đúng entry point `lib/main.dart`. Cấu hình asset hiện tại không yêu cầu `--dart-define-from-file` nếu main đã gọi loadConfig như trên.

## Đăng nhập và dữ liệu thử

- Bidder/seller dùng đăng nhập người dùng. Ops dùng chế độ đăng nhập nhân viên/quản trị.
- Không tự đăng ký role admin/appraiser/warehouse từ màn đăng ký công khai.
- Xin tài khoản thử theo role từ người phụ trách BE qua kênh nhóm phù hợp; không commit mật khẩu vào repo.
- Khám phá có thể rỗng nếu chưa có phiên live. Seller tạo tin thành công chưa đồng nghĩa bidder sẽ thấy phiên; cần hoàn thành quy trình submit/thẩm định và kiểm tra trạng thái phiên từ BE.
- App và Postman cần cùng BE, cùng tài khoản và cùng auctionId/orderId khi đối chiếu.

## Khi không chạy được

| Hiện tượng | Kiểm tra |
|---|---|
| Không kết nối BE | BE đang chạy? Cổng đúng? Máy ảo dùng 10.0.2.2? Quyền INTERNET và cấu hình HTTP debug đã có? |
| Không đọc được dev.json | File tồn tại, JSON hợp lệ, asset được khai báo và đã pub get |
| Không tìm thấy package | `flutter pub get`, kiểm tra dependencies trên nhánh hiện tại |
| Undefined class / URI | Đúng tên thư mục, file, import; lưu tất cả rồi chạy analyzer |
| Chỉ lỗi gạch đỏ trong editor | Xem `flutter analyze`; có thể restart Dart Analysis Server |
| Thêm plugin nhưng hot reload không nhận | Dừng app rồi chạy lại đầy đủ |

Không dùng `flutter clean` như bước mặc định cho mọi lỗi. Đọc lỗi cụ thể trước. Không ghi đè file cấu hình hoặc code của thành viên khác để giải quyết lỗi môi trường.
