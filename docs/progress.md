# Tiến độ và phạm vi đã triển khai

## Cập nhật tích hợp Hào — bản nền ab15709

Đọc [hao-integration.md](hao-integration.md) để xem trạng thái mới và thứ tự kiểm thử. Các mục từ “Mốc ghi nhận” bên dưới là nhật ký của các lần bàn giao trước, có thể mô tả phần còn chờ đã được tích hợp sau đó.

- Đã kiểm tra checkout sạch: local `develop` và `origin/main` ở `ab15709`, gồm merge PR #9 của Khang. `origin/develop` tại lần đọc còn ở `34e471d`; không suy rằng remote develop đã đồng bộ main.
- Phần Hiệu và Khang đã có trong bản nền; Hào không cần xây lại màn đơn, seller, Admin, Appraiser, Warehouse.
- Bản sao QA đã nối thông báo tranh chấp → chi tiết thật, phiên thắng → đơn thật, đồng bộ Ví/Hồ sơ và chi tiết đơn/tranh chấp; giữ bố cục Hồ sơ và bản nháp đang nhập.
- Kiểm thử tự động: bản nền 204 đạt; bản bổ sung 220 đạt, 2 test BE thật bỏ qua. Chưa kiểm thử thủ công phần bổ sung trên BE/Supabase của nhóm.
- H04/H08: phần code nối đã có trong gói bàn giao; chờ Hào chép file, manual và PR. H05: report/Admin có đủ phía FE, còn kiểm thử nhiều role với BE thật. H09: review và chuẩn bị phát hành tiếp tục sau manual.
- Bản bổ sung chưa được chép vào repo thật, commit, push hoặc merge bởi công cụ. Trạng thái Git nêu trên chỉ là lần đọc để chọn bản nền.

## Nhật ký trước đợt tích hợp

Mốc ghi nhận: **16/10/2026**. Đây là ảnh chụp tiến độ, không tự đồng bộ theo GitHub.

## Bằng chứng và cách đọc

- Đã kiểm tra chỉ đọc checkout của Hào: nhánh `feature/Hao`, nhiều file modified/untracked. Chưa xác minh commit/PR/push hoặc merge remote cho các tính năng dưới đây.
- Các bộ code được kiểm thử trên bản QA tách riêng, không phải toàn bộ checkout mới nhất của Hào trên máy ảo.
- Hào đã báo kiểm thử thành công nhiều bước bidder trước đó, gồm notification/report và luồng đã làm. Chưa dùng lời xác nhận đó để suy ra Hồ sơ/chatbot/địa chỉ bản mới nhất đều đã kiểm thử với BE thật.
- Code địa chỉ đã xuất hiện trong checkout local, nhưng Hào vừa gặp lỗi nhận diện AddressBookScreen và chưa xác nhận bản sửa. Hai file test địa chỉ chưa có trong danh sách test của checkout tại mốc kiểm tra.
- Trạng thái nhánh Hiệu/Khang chưa được kiểm tra; các hàng của họ là chờ xác nhận, không phải kết luận chưa làm.

## Phần của Hào

| Module | Chức năng đã có code | Kiểm thử có căn cứ | Việc tiếp theo |
|---|---|---|---|
| Xác thực | Login/register/ops login, GET me, khôi phục/đăng xuất local | Hào báo thành công các bước xác thực | Chạy lại trên develop sau ghép |
| Khám phá | Danh mục, tìm kiếm, lọc/sắp xếp, phân trang | Test QA và Hào đã thực hiện các bước bidder | Kiểm tra dữ liệu live khi demo |
| Chi tiết phiên | Ảnh, giá, cọc, trạng thái, lịch sử | Test QA và các bước thủ công trước | Kiểm tra route từ notification |
| Ví | Số dư, tiền giữ, lịch sử, nạp mô phỏng qua BE | Test QA và Hào báo test ví thành công | Không giới thiệu là cổng nạp tiền thật |
| Cọc/đặt giá/realtime | Xác nhận gửi, đồng bộ socket, mất mạng/reconnect | Test QA và kiểm thử thủ công các bước trước | Ghép kết quả thắng với đơn hàng |
| Thông báo | List, badge, read/read-all, socket và snackbar | Test QA; Hào báo test notification/report thành công | Nối order/dispute/listing sang màn thật của Hiệu |
| Báo cáo phiên | Report và xử lý đã báo cáo | Test QA; Hào báo kiểm thử report | Đối chiếu Admin với Khang |
| Hồ sơ | GET/PATCH me, đổi mật khẩu, upload avatar, tóm tắt đơn/địa chỉ | Có code local và test QA | Hào xác nhận manual bản giữ layout cũ |
| Chatbot | POST tin nhắn, lịch sử, session riêng tài khoản | Có code local và test QA | Hào xác nhận BE thật, đối chiếu sessionId |
| Sổ địa chỉ | CRUD, mặc định, selectionMode, refresh Hồ sơ | 22 test mới đạt trên QA | Chép đủ file/test, analyzer và manual bản local sau lỗi import |
| Tích hợp sau bán | Callback đã chuẩn bị | Chưa có bằng chứng ghép màn thật | Nhận màn và hợp đồng từ Hiệu |

## Phần của Hiệu (nhánh `feature/orders-seller-disputes`)

Kiểm thử thủ công chạy trên bản web (Playwright) với backend nối **DB Docker cục bộ** (bản sao một lần của Supabase), không dùng Supabase. Ngày 16/10/2026.

| Task | Module | Màn / class | Kiểm thử có căn cứ | Việc tiếp theo |
|---|---|---|---|---|
| I01 | Danh sách đơn thắng | `OrdersScreen` | Chạy thật trên web; nhãn Chờ thanh toán / Hoàn tất / Đang tranh chấp / Quá hạn | Danh sách BE không trả `stage`, nhãn suy từ trạng thái thanh toán và giải ngân |
| I02 | Gắn địa chỉ vào đơn | `OrderDetailScreen` + `AddressBookScreen` (selectionMode) | Chạy thật: chặn thanh toán khi thiếu địa chỉ, chọn địa chỉ rồi BE ghi `shipping_address_id` | Xử lý `ALREADY_SHIPPED` đã có thông báo, chưa thử bằng dữ liệu thật |
| I03 | Thanh toán đơn thắng | `OrderDetailScreen` | Chạy thật: QR/ví, hộp xác nhận, không tự thử lại, khoá nút khi hết hạn | Cổng QR/card là mô phỏng của BE |
| I04 | Theo dõi và xác nhận nhận hàng | `OrderDetailScreen` | Chạy thật qua cả chuỗi người bán → kho (gọi API) → xác nhận → `released` | Bước kho vận chưa thử qua giao diện |
| I05 | Tin đăng của người bán | `SellerCreateScreen`, `SellerEditScreen`, `SellerListScreen` (dữ liệu thật qua `RemoteAppStore`) | Chạy thật: tạo tin kèm ảnh mẫu, bổ sung theo yêu cầu thẩm định, chống tạo trùng và tin nháp mồ côi | Ảnh vẫn là URL mẫu (chưa tải ảnh thật); gợi ý giá dùng `/api/ai/suggest-price` |
| I06 | Báo gửi hàng về kho | `SellerShippingScreen` | Chạy thật: đơn chuyển `in_transit_to_warehouse` | — |
| I07 | Tranh chấp phía người dùng | `CustomerDisputeScreen`, `MyDisputesScreen` | Chạy thật cả người mua và người bán; đơn chuyển `disputed`; gửi lỗi thì ở lại và giữ nội dung | Kiểm thử phía Admin xử lý tranh chấp chờ Khang |
| I08 | Ghép thông báo | `BidderShell` | Thông báo kiểu `order` mở `OrderDetailScreen`; hồ sơ mở `OrdersScreen` | Thông báo `dispute` / `listing` vẫn là bottom sheet, chưa có route |

Thay đổi dùng chung (cần Hào review): `lib/main.dart` (thêm `StoreToastListener` vì toast của store trước đó không có chỗ hiển thị), `lib/store.dart` (thêm `showMessage`, `suggestStartingPrice`; `updateListing`, `createListing`, `raiseDispute`, `sellerSubmitMoreInfo` trả `FutureOr` để chờ được; thêm `simulatesMarket`, bản chạy với backend thật tắt vòng mô phỏng bot/tự đóng phiên của store cũ, vẫn giữ nhịp cập nhật mỗi giây cho đồng hồ đếm ngược), `lib/models.dart` (`SellerListing.editable`, `UserAccount.shop` không còn `final`, `PriceSuggestion`), `lib/core/remote_app_store.dart` (nạp dữ liệu người bán, ghi tin, tranh chấp), `android/app/src/debug/AndroidManifest.xml` (cho phép HTTP chỉ ở bản debug).

Kiểm thử tự động của phần này: `test/order_flow_test.dart`, `test/seller_flow_test.dart`, `test/remote_store_seller_test.dart`, `test/order_live_test.dart` (chỉ chạy khi đặt `BACKEND_URL`, ghi vào DB Docker). Toàn bộ `flutter test`: 196 đạt, 2 bỏ qua (test với backend thật khi thiếu `BACKEND_URL`); `flutter analyze` không có lỗi.

Các file prototype cũ của Admin/Appraiser/Warehouse vẫn còn trong source nhưng không còn được route từ shell; shell hiện dùng các màn API-backed ghi ở mục K01–K06 bên dưới.

## Phần của Khang (Admin và ops) 

Có code API-backed trong checkout local qua `OpsRepository` và các màn Admin, Appraiser, Warehouse. `flutter analyze` không có issue; `flutter test` đạt 204 test. Test ops dùng HTTP fixture, chưa phải kiểm thử thủ công với BE thật.

| Task | Code local | Trạng thái đã kiểm tra | Còn lại |
|---|---|---|---|
| K01 | Dashboard và báo cáo tuần dùng hai endpoint Admin | Fixture API và smoke shell | Chạy thủ công với role Admin/BE thật |
| K02 | Danh sách cờ, xem chi tiết, pause/verify/safe/terminate | Payload và fixture API; lý do terminate bắt buộc | Kiểm tra auctionId/tác động bidder trên BE dev |
| K03 | Danh sách tài khoản bidder/seller và ops; tạo/sửa/khoá | Filter, request body và smoke shell | Kiểm tra quyền/self-lockout trên BE thật |
| K04 | Danh sách, timeline và xử lý tranh chấp `refund`/`keep` | Payload resolution và smoke shell | Đối chiếu hoàn tiền/giải ngân, đơn và thông báo |
| K05 | Queue `pending_appraisal`/`needs_info`, detail ảnh/lịch sử, decision | Payload quyết định và smoke màn | Ghép với seller submit và bidder thấy phiên thật |
| K06 | Kho nhận, kiểm định, đóng gói, gửi tracking, xác nhận giao | Đủ năm route trong test contract; smoke board/detail | Test xuyên seller → kho → bidder trên BE thật |

Chưa xác nhận Khang đã nhận task, branch riêng, PR hay merge. Không có endpoint audit Admin hoặc lịch sử thẩm định toàn cục trong hợp đồng hiện có; các trang prototype đó không còn được điều hướng từ shell ops. Ảnh nhận kho, quét mã, grade/kệ là hành vi prototype và không được giả lập trong luồng mới vì chưa có API.

Chưa kiểm tra: người bán mở tranh chấp trên bản điện thoại thật; Admin xử lý tranh chấp rồi giao diện người mua cập nhật; bản release Android (manifest chính chưa khai báo quyền `INTERNET`, cần bổ sung trước khi build release).

## Giới hạn hiện tại

- Tóm tắt đơn ở Hồ sơ có dữ liệu thật nhưng không thay cho module đơn/thanh toán đầy đủ.
- Thông báo orderId/disputeId/listingId còn có đường hiển thị bottom sheet nội dung/mã; chưa đồng nghĩa bấm sẽ vào màn nghiệp vụ thật.
- Thông báo realtime khi app đang mở; chưa có push notification hệ điều hành khi app đã tắt.
- OTP/2FA bị vô hiệu hóa và ghi chưa khả dụng; chưa có API quản lý thiết bị. Không có danh sách thiết bị thật.
- Chatbot BE đang dùng câu trả lời theo logic từ khóa; không có bằng chứng kết nối mô hình AI hội thoại hoặc tra cứu số dư cá nhân.
- Nạp ví và phương thức thanh toán QR/card trong BE là mô phỏng theo docs; không coi là tích hợp thanh toán thương mại.
- Seller vẫn theo trạng thái bàn giao của Hiệu ở trên. Shell Admin/Appraiser/Warehouse đã gọi API trong checkout local, nhưng chưa có xác nhận manual BE, PR, merge develop hoặc merge main.

## Kiểm thử QA đã chạy

| Nhóm | Số test | Ghi nhận |
|---|---|---|
| Đấu giá, ví, cọc, đặt giá, notification, report | 66 | Đạt trên QA |
| Hồ sơ và chatbot | 66 | Đạt trên QA |
| Địa chỉ | 22 | Đạt trên QA |
| Tổng nghiệp vụ ở mốc cuối | 154 | Đạt trên QA với các file bàn giao mới nhất |

Một kiểm tra xuất ảnh địa chỉ cũng đạt, nâng tổng lượt chạy có ảnh QA lên 155. Test xuất ảnh phụ thuộc môi trường QA và không phải file cần chép vào repo. Analyzer cho các file địa chỉ và file dùng chung bị sửa không có lỗi. Không suy ra toàn bộ `flutter test` của mọi test prototype đều đạt.

## Việc phải xác nhận trước khi thành viên clone để làm tiếp

| Hạng mục | Trạng thái ngày 16/10/2026 | Bằng chứng cần bổ sung |
|---|---|---|
| Hào hết lỗi import AddressBookScreen | Chờ xác nhận | Kết quả flutter analyze local |
| Hai test địa chỉ đã chép | Chưa thấy tại lần kiểm tra | Test mới và lệnh chạy đạt |
| Profile/chat/address trên BE thật | Chờ xác nhận bản cuối | Các bước manual, môi trường, ngày test |
| Code Hào được commit/push | Chưa xác minh | Commit hoặc PR |
| Đã merge develop | Chưa xác minh | PR merge commit |
| Đã merge main | Chưa xác minh | PR merge commit và smoke test |
| Module Hiệu | Có code và kiểm thử trên nhánh `feature/orders-seller-disputes` | Link PR và kết quả merge |
| Module Khang | Chưa đọc nhánh riêng | Cập nhật PR và trạng thái |

## Nhật ký cập nhật tiếp theo

Mỗi thay đổi đáng kể thêm một hàng, giữ thông tin không nhạy cảm:

| Ngày | Task | Người | Thay đổi | Kiểm thử | PR/commit | Merge |
|---|---|---|---|---|---|---|
| 16/10/2026 | DOC | Hào | Chuẩn bị bộ docs FE và phân công để đưa vào repo | Đối chiếu source/bàn giao | Chưa commit tại mốc soạn | Chưa xác minh |
| 16/10/2026 | I01–I08 | Hiệu | Đơn hàng, thanh toán, theo dõi, tin đăng và gửi kho của người bán, tranh chấp, toast của store, khung chờ | `flutter test` 196 đạt; chạy thật trên web với DB Docker | Nhánh `feature/orders-seller-disputes` | Chưa tạo PR |
| 16/10/2026 | K01–K06 | FE checkout | Nối Admin, Appraiser, Warehouse qua `OpsRepository`; cập nhật API map và smoke fixtures | `flutter test` 204 đạt; `flutter analyze` không issue; chưa manual BE | Chưa xác minh commit/PR | Chưa xác minh |
