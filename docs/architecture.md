# Cấu trúc và quy ước code

## Các lớp chính

```text
lib/
  main.dart                         Khởi động, cấu hình, provider, điều hướng theo role
  core/
    api_client.dart                 URL, Bearer token, HTTP, upload, ApiException
    remote_app_store.dart           Đăng nhập, khôi phục phiên, currentUser
  features/
    auctions/                       Repository, controller realtime, socket sự kiện phiên
    wallet/                         Repository ví
    notifications/                  Repository, controller, sự kiện thông báo
    profile/                        Hồ sơ, đổi mật khẩu, avatar
    chat/                           Repository, controller, lưu session chat
    addresses/                      Model ShippingAddress và repository địa chỉ
  screens/
    auth/                           Login, register, profile
    bidder/                         Khám phá, phiên, ví, thông báo, báo cáo
    addresses/                      Sổ địa chỉ và form thêm/sửa dùng chung
    customer/                       Chatbot; tranh chấp cũ cần xác nhận tích hợp
    seller/                         Module seller
    appraiser/                      Module thẩm định
    warehouse/                      Module kho
    admin/                          Module quản trị
  widgets/                          Thành phần giao diện chung
  theme.dart                        Màu, kiểu chữ và theme toàn app
  models.dart                       Model dùng chung hiện có
  store.dart                        Store cũ, còn chứa logic/dữ liệu demo
```

Màn hình → repository/controller → ApiClient → BE. Flutter không gọi trực tiếp bảng Supabase để đặt giá, trừ ví, tạo đơn hoặc thay trạng thái nghiệp vụ.

## Phiên đăng nhập

App cung cấp `RemoteAppStore` dưới kiểu `AppStore` qua provider để tương thích shell hiện có. `remote.api` giữ token hiện tại; dùng lại client này khi mở màn con. Token được lưu bằng secure storage, không lưu mật khẩu.

`RemoteAppStore` còn kế thừa store demo. Không mặc định một phương thức kế thừa đã gọi BE. Với từng module, xem repository và bảng API để xác nhận nguồn dữ liệu. Không dùng số dư, đơn hoặc thao tác demo cho phiên thật.

Các màn đã tích hợp xử lý `UNAUTHORIZED`/`ACCOUNT_SUSPENDED` theo luồng đăng xuất. Chưa có bằng chứng interceptor auth toàn app bao phủ mọi màn của thành viên khác; khi làm module mới cần nối xử lý này và hủy listener/socket đúng lúc.

## API và bất đồng bộ

- Gọi `ApiClient.request` với method rõ ràng khi cần POST không body, PATCH hoặc DELETE. Client bản địa chỉ hỗ trợ GET/POST/PATCH/DELETE; PUT chưa được bổ sung.
- Dùng ApiException.code để xử lý nghiệp vụ, message để hiển thị. Không so sánh nguyên câu lỗi tiếng Việt để điều khiển luồng.
- Không tự retry thao tác ghi tiền, cọc, giá hoặc chat khi chưa rõ kết quả. Tải lại trạng thái/lịch sử để kiểm tra.
- Khóa nút khi đang gửi. Sau await kiểm tra mounted và tài khoản/token còn phù hợp trước khi cập nhật UI hoặc điều hướng.
- Timer/subscription/controller/socket tạo ở đâu phải được hủy đúng nơi sở hữu. Client dùng chung không được đóng bởi màn con.

## Realtime

Chi tiết phiên có socket theo vòng đời màn, vào phòng `auction:{id}`. Khung bidder có socket thông báo theo vòng đời đăng nhập; hai phần có vai trò khác nhau. Dùng đúng sự kiện từ BE: auction:update, auction:ended, notification:new, account:disconnected.

Socket nhận thay đổi, REST lấy trạng thái xác nhận và dữ liệu riêng người dùng. Đặt giá luôn gọi POST /api/bids. Sau reconnect hoặc app về foreground, đồng bộ lại từ BE.

## Giao diện

Dùng `AppColors` và theme hiện có: nền kem, thẻ trắng bo góc, xanh navy. Module mới giữ kiểu nút, trạng thái lỗi/rỗng/loading tương thích với app. Đặt Material đúng chỗ cho InkWell/ListTile/công tắc. Kiểm tra vùng cuộn và bàn phím trên điện thoại.

Không đổi theme hoặc model chung chỉ để phục vụ một màn nếu chưa đánh giá các module khác. Ghi thay đổi giao diện dùng chung trong PR và nhờ Hào review.
