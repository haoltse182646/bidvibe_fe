# Bàn giao giữa Hào, Hiệu và Khang

## Bổ sung của Hào sau merge Hiệu/Khang

Bản nền `ab15709` đã gồm phần Hiệu và PR #9 Khang. Gói bổ sung của Hào được kiểm thử trên bản sao, chưa tự ghi vào repo. Xem [hao-integration.md](hao-integration.md) trước các ghi nhận cũ bên dưới.

- `BidderShell` mặc định mở thông báo `disputeId` bằng `DisputeDetailScreen`, `orderId` bằng `OrderDetailScreen`. `onOpenTarget` vẫn là tùy chọn override; caller tự chịu trách nhiệm route nếu truyền callback này.
- `DisputeDetailScreen(api, disputeId, onSessionExpired, onOpenOrder, refreshSignal)` lấy từ GET `/api/disputes/mine`; không thêm endpoint chi tiết chưa có. Màn này phục vụ bidder, mở đơn liên quan bằng `dispute.orderId`.
- `AuctionDetailScreen` có nút “Xem đơn thắng” khi BE xác nhận won/ended; GET đơn của mình, đối chiếu auctionId, mở bằng order.id.
- `refreshSignal` là `Listenable?` tùy chọn truyền từ shell tới Ví/Hồ sơ/chi tiết đơn/tranh chấp. Sau một sự kiện hoặc đóng route, shell phát tín hiệu; các màn gom/đợi yêu cầu GET khi đang bận. Hồ sơ đang sửa không bị ghi đè.
- Route đơn vẫn do module Hiệu xử lý địa chỉ/thanh toán/theo dõi/xác nhận; Admin/Appraiser/Warehouse vẫn do module Khang gọi API đúng role. Hào không thêm thao tác Admin vào bidder.
- Gói có 16 test mới; manual nhiều role và PR thực hiện theo tài liệu tích hợp. Những câu “chưa có route dispute” trong nhật ký cũ bên dưới đã được thay thế bởi bản bổ sung này.

## Những gì phải kèm mỗi lần bàn giao

Ghi task ID, file/class màn, role, đầu vào, kết quả trả về khi pop, API đã gọi, lỗi cần xử lý, cách kiểm thử, PR/commit và phần còn thiếu. Dùng tên class thực tế sau khi code được ghép; không tự giả định màn của thành viên khác đã tồn tại.

## Hào → Hiệu: sổ địa chỉ

File dùng chung:

- `lib/features/addresses/address_repository.dart`: ShippingAddress, AddressRepository.
- `lib/screens/addresses/address_book_screen.dart`: AddressBookScreen.

Hào mở từ Hồ sơ ở chế độ quản lý. Hiệu mở ở chế độ chọn, dùng chung ApiClient/token hiện tại:

```dart
final selected = await Navigator.of(context).push<ShippingAddress>(
  MaterialPageRoute(
    builder: (_) => AddressBookScreen(
      repository: AddressRepository(api),
      selectionMode: true,
      selectedAddressId: currentAddressId,
      onSessionExpired: handleSessionExpired,
    ),
  ),
);
```

Đây là ví dụ ghép vào màn đơn: api là client dùng chung, currentAddressId là String? từ shippingAddress của đơn, handleSessionExpired nhận ApiException và xử lý hết phiên. Cần import hai file dùng chung, Flutter material và cơ chế auth của màn gọi.

- Pop/hủy: selected=null, không đổi đơn.
- Chọn: nhận ShippingAddress, dùng selected.id **hiện tại**. Sửa địa chỉ có thể tạo ID mới, không giữ bản ID cũ của màn đơn.
- Trước khi tiếp tục sau await, kiểm tra mounted, tài khoản/token và trạng thái đơn.
- Hiệu gọi POST /api/orders/:id/shipping-address với addressId, đọc chi tiết đơn trong phản hồi để cập nhật shippingAddress.
- Chỉ dùng địa chỉ trả về từ màn chọn chưa có nghĩa đã gắn thành công vào đơn. Nếu BE từ chối, giữ trạng thái đơn thực.
- Không xây thêm sổ địa chỉ riêng trong module đơn. Đặt mặc định không thay cho gắn địa chỉ đơn.

## Hiệu → Hào: điều hướng đơn và tranh chấp

Các điểm nối có sẵn:

| Điểm nối | Kiểu hiện tại | Cần bàn giao |
|---|---|---|
| BidderShell.onOpenTarget | Future<void> Function(NotificationTarget)? | Hàm mở đúng màn theo kind/id |
| AuthProfileScreen.onOpenOrder | Future<void> Function(String orderId)? | Mở chi tiết đơn thật |
| AuthProfileScreen.onOrders | VoidCallback? | Mở danh sách đơn đầy đủ |
| AuthProfileScreen.onAddresses | VoidCallback? | Có thể override; mặc định mới đã mở sổ địa chỉ thật |

NotificationTarget ưu tiên disputeId → orderId → listingId → auctionId. Data không có ID hợp lệ thì chỉ đọc thông báo; không lấy số từ title. auctionId đã có đường mở chi tiết phiên; order/dispute/listing còn cần Hiệu cung cấp màn thật. Hiệu cần thống nhất cách mở listing theo role/quyền, không mở màn chỉnh sửa seller cho bidder.

Lưu ý kỹ thuật: hiện BidderShell dựng AuthProfileScreen bên trong. Truyền onOpenTarget ở ngoài shell chỉ xử lý thông báo, chưa tự truyền onOpenOrder/onOrders cho Hồ sơ. Khi ghép, Hào phải nối callback vào đúng nơi dựng AuthProfileScreen hoặc bổ sung tham số chuyển tiếp cho shell trong PR tích hợp. Chưa có bản ghép cuối cho các màn Hiệu trong gói hiện tại.

Hiệu cần bàn giao:

| Đối tượng | Đầu vào tối thiểu | Yêu cầu sau đóng màn |
|---|---|---|
| Danh sách đơn | Tài khoản hiện tại | Có đường mở orderId thật |
| Chi tiết/thanh toán/theo dõi đơn | orderId | GET lại trạng thái đơn; màn nguồn tải lại dữ liệu liên quan |
| Tranh chấp | disputeId hoặc orderId theo màn | Không nhầm với report phiên; xử lý đối tượng không thuộc quyền |
| Tin đăng | listingId và role phù hợp | Cung cấp route thật hoặc cách xem phù hợp theo quyền |

## Hào ↔ Khang: báo cáo phiên và thao tác Admin

Hào gửi POST /api/auctions/:id/report. Khang kiểm tra cờ/bằng chứng bên Admin dựa trên auctionId. Ghi rõ hai ID: auctionId là phiên; flagId là cờ Admin. Không dùng thay nhau.

Hai người kiểm thử: bidder gửi báo cáo → Admin đọc đúng cờ → Admin thao tác theo contract BE → bidder nhận thay đổi/thông báo và tải lại trạng thái. Không kết luận report chưa lưu chỉ vì flagCreated=false; BE có thể bổ sung vào cờ đã có.

Nếu Admin khóa tài khoản bidder, kiểm tra app dừng socket, hết phiên và không giữ dữ liệu của tài khoản trước khi đăng nhập tài khoản khác.

## Hiệu → Hào: những gì đã nối (bàn giao)

- `BidderShell` truyền `onOrders` và `onOpenOrder` vào `AuthProfileScreen`; `BidderShell._open` mở `OrderDetailScreen` khi thông báo có `orderId` (nếu không truyền `onOpenTarget`). Đóng màn thì tải lại thông báo.
- `OrdersScreen(api, onSessionExpired)` và `OrderDetailScreen(api, orderId, onSessionExpired)` nhận `ApiClient` dùng chung; hết phiên gọi `onSessionExpired` thay vì tự đăng xuất.
- Chọn địa chỉ của đơn dùng `AddressBookScreen(selectionMode: true)`, gắn bằng `POST /api/orders/:id/shipping-address` rồi tải lại đơn; không giữ địa chỉ chỉ vì đã chọn.
- Thông báo kiểu `dispute` và `listing` chưa có route (vẫn bottom sheet). Hào quyết định có mở `MyDisputesScreen` hay màn người bán.
- `RemoteAppStore` đặt `simulatesMarket => false`: store cũ không còn chạy bot đặt giá, tự đóng phiên, tự giải ngân trên dữ liệu mẫu (toast "bị vượt giá" giả từng hiện ra trong phiên thật). Màn nào còn dựa vào dữ liệu mẫu tự chạy (Admin, thẩm định, kho) cần nối API thật hoặc tự cập nhật sau thao tác.
- Toast của store: thêm `StoreToastListener` trong `RootShell` để thông báo từ `AppStore.showMessage` hiện dưới dạng SnackBar. Màn nào có luồng thao tác dài nên dùng thông báo này thay vì tự dựng SnackBar.

## Hiệu ↔ Khang/người nhận ops

- Seller submit tin → Appraiser xem đúng listingId và quyết định → bidder thấy phiên đúng trạng thái.
- Seller báo gửi kho bằng orderId → Warehouse xử lý theo giai đoạn → buyer theo dõi.
- Kiểm định mismatch → tranh chấp nguồn kho → Admin xử lý; không cho FE tự bỏ qua kiểm định.
- Buyer/seller tạo tranh chấp → Admin xử lý → Hiệu tải lại đơn/tranh chấp, Hào kiểm tra ví/thông báo khi liên quan.

Ghi lại tài khoản theo role và ID dữ liệu thử qua kênh nhóm phù hợp. Trong repo chỉ ghi ID dữ liệu không nhạy cảm, ngày, môi trường và kết quả; không ghi token/mật khẩu.

## Bảng bàn giao cần cập nhật khi có PR

| Bàn giao | Bên gửi → nhận | Trạng thái mốc hiện tại | PR/bằng chứng |
|---|---|---|---|
| Sổ địa chỉ dùng chung | Hào → Hiệu | Có bộ code QA; local đang ghép sau lỗi import | Chờ PR |
| Màn chi tiết đơn và danh sách | Hiệu → Hào | Có code: `OrdersScreen`, `OrderDetailScreen`; đã nối vào `BidderShell` (Hồ sơ → Đơn hàng, thông báo `order`) | Nhánh `feature/orders-seller-disputes` |
| Màn tranh chấp | Hiệu → Hào | Có code: `CustomerDisputeScreen` (tạo), `MyDisputesScreen` (danh sách); thông báo `dispute` / `listing` chưa có route | Nhánh `feature/orders-seller-disputes` |
| Report ↔ cờ Admin | Hào ↔ Khang | Bidder có code; chờ kiểm thử xuyên role | Chờ PR/kết quả test |
| Appraiser/Warehouse | Nhóm chốt người → cả nhóm | Đang là phân công đề xuất | Chờ chốt phạm vi |
