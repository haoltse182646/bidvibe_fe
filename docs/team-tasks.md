# Phân công FE và thứ tự thực hiện

Cập nhật 16/10/2026. Hào là leader FE. Bản nền `ab15709` đã có phần đơn/seller của Hiệu và PR #9 Admin/ops của Khang. Bản bổ sung tích hợp Hào và thứ tự manual nằm trong [hao-integration.md](hao-integration.md); những trạng thái cũ “chờ/đề xuất” phía dưới là kế hoạch ban đầu, không thay cho bằng chứng ở [progress.md](progress.md).

## Phạm vi chính

| Người | Phạm vi đã có căn cứ từ các bàn giao | Phạm vi đề xuất cần nhóm chốt |
|---|---|---|
| Hào | Leader; xác thực dùng chung; bidder khám phá/chi tiết phiên, ví, cọc, giá realtime, thông báo, báo cáo phiên; Hồ sơ/chatbot; sổ địa chỉ dùng chung mới bổ sung | Giữ đầu mối review và tích hợp FE; cập nhật docs cùng PR |
| Hiệu | Module seller và luồng sau bán/đơn hàng, thanh toán, giao nhận phía người dùng, tranh chấp; dùng lại sổ địa chỉ của Hào | Chốt phạm vi seller với nhóm trước khi mở rộng sang AI gợi ý giá |
| Khang | Admin, Appraiser, Warehouse đã có code API trong bản nền PR #9; phối hợp Hào kiểm thử tác động đến bidder | Cùng nhóm ghi kết quả manual BE sau khi tích hợp |

Sổ địa chỉ đã chuyển thành module dùng chung do Hào triển khai. Hiệu phụ trách gắn địa chỉ vào đơn; không làm lại một sổ địa chỉ thứ hai. Nếu phân công thực tế khác, sửa bảng này trong cùng PR điều chỉnh phạm vi.

## Task của Hào

| ID | Công việc | Kết quả bàn giao / điều kiện xong | Trạng thái tài liệu hiện tại |
|---|---|---|---|
| H01 | Xác thực và cấu hình BE | Login/register/ops login, khôi phục phiên, cấu hình URL dùng chung | Có code local; các bước trước Hào đã báo kiểm thử thành công |
| H02 | Khám phá và chi tiết phiên | Lọc/tìm/phân trang, đúng auctionId, dữ liệu và trạng thái BE | Có code local và test QA |
| H03 | Ví, đặt cọc, đặt giá realtime | Không dùng số dư demo; chặn gửi lặp; đồng bộ sau reconnect | Có code local và test QA |
| H04 | Thông báo bidder | Danh sách, badge, read/read-all, nhận sự kiện toàn khung bidder | Đã nối đơn và chi tiết tranh chấp trong gói tích hợp; chờ manual/PR |
| H05 | Báo cáo phiên | Gửi report, xác nhận/đã báo cáo; đối chiếu được bên Admin | Phía bidder có code; ghép Admin chờ Khang |
| H06 | Hồ sơ và chatbot | Sửa hồ sơ, avatar, mật khẩu; chat BE và mở lại lịch sử | Có code và test QA; cần xác nhận manual bản cuối |
| H07 | Sổ địa chỉ dùng chung | CRUD/mặc định, Hồ sơ tải lại, chọn trả về ShippingAddress | Đã bàn giao code; Hào đang ghép, chưa xác nhận hết lỗi và manual |
| H08 | Nối màn của Hiệu/Khang | Thông báo → đơn/tranh chấp; phiên thắng → đơn; đồng bộ Ví/Hồ sơ | Có code và 16 test mới trong gói tích hợp; manual BE theo hao-integration.md |
| H09 | Review, docs và release | PR có kiểm thử; cập nhật tiến độ; develop ổn trước main | Công việc xuyên suốt, không tự coi đã merge |

## Task của Hiệu — thứ tự khuyến nghị

Đây là kế hoạch công việc, không phải báo cáo Hiệu đã hoàn thành.

| ID | Ưu tiên | Màn / công việc | API chính | Tiêu chí bàn giao |
|---|---|---|---|---|
| I01 | P0 | Danh sách đơn thắng, chi tiết đơn của bidder | GET /api/orders/mine; GET /api/orders/:id | Mở bằng orderId thật; thể hiện số tiền/cọc/phí/deadline từ BE |
| I02 | P0 | Chọn và gắn địa chỉ vào đơn | Dùng AddressBookScreen; POST /api/orders/:id/shipping-address | Dùng selected.id; cập nhật shippingAddress từ phản hồi; xử lý ALREADY_SHIPPED |
| I03 | P0 | Thanh toán đơn thắng | POST /api/orders/:id/pay | Xác nhận trước gửi; xử lý thiếu tiền, đã trả, quá hạn; không tự retry |
| I04 | P0 | Theo dõi, xác nhận nhận hàng | GET /api/orders/:id/tracking; POST /api/orders/:id/confirm-delivery | Đúng giai đoạn, xác nhận có điều kiện, đồng bộ lại đơn |
| I05 | P1 | Danh sách/tạo/sửa/ảnh/submit tin seller | Nhóm /api/listings; POST /api/uploads/images | Phản ánh draft, chờ duyệt, yêu cầu bổ sung, từ chối, được duyệt theo BE |
| I06 | P1 | Đơn đã bán và gửi hàng về kho | GET /api/orders/selling; POST /api/orders/:id/ship-to-warehouse | Chỉ thao tác đúng trạng thái đơn và quyền seller |
| I07 | P1 | Tạo và xem tranh chấp phía người dùng | POST /api/disputes; GET /api/disputes/mine | Nhận orderId/disputeId để mở đúng mục; không trùng với report phiên |
| I08 | P1 | Ghép thông báo và Hồ sơ | Hợp đồng với Hào trong handoff.md | Bấm win/address_reminder/giao hàng mở đúng đơn; quay về cập nhật dữ liệu |

Luồng sau bán cần có dữ liệu thắng phiên nhưng có thể xây bằng mock và hợp đồng BE trước; không cần chờ Hào làm xong toàn bộ UI để bắt đầu.

## Task của Khang — Admin và đề xuất ops

Trạng thái triển khai của Khang chưa được xác minh từ nhánh riêng. Các task ops dưới đây là đề xuất phân công, cần nhóm chốt.

| ID | Phạm vi | Màn / công việc | API chính | Phối hợp |
|---|---|---|---|---|
| K01 | Admin | Dashboard, báo cáo tuần | GET /api/admin/dashboard; GET /api/admin/report/weekly | Hào review route/role và trạng thái dữ liệu |
| K02 | Admin | Cờ nghi vấn/báo cáo phiên và hành động xử lý | GET /api/admin/flags; POST /api/admin/flags/:id/action | Hào gửi report; kiểm tra đúng auctionId và tác động lên bidder |
| K03 | Admin | Tài khoản người dùng và ops | GET/PATCH /api/admin/accounts; GET/POST/PATCH /api/admin/ops-accounts | Không hardcode quyền trong UI thay cho BE |
| K04 | Admin | Xử lý tranh chấp | GET /api/admin/disputes; POST /api/admin/disputes/:id/resolve | Hiệu tạo tranh chấp, kiểm tra kết quả hoàn tiền/giải ngân |
| K05 | Đề xuất appraiser | Hàng chờ, chi tiết và quyết định thẩm định | GET /api/appraisals/queue; GET /api/appraisals/:listingId; POST /api/appraisals/:listingId/decision | Hiệu tạo/submit tin → duyệt → Hào thấy phiên hợp lệ |
| K06 | Đề xuất warehouse | Danh sách, nhận, kiểm định, đóng gói, gửi, xác nhận giao | Nhóm /api/warehouse/orders | Hiệu gửi về kho và theo dõi; Hào kiểm tra thông báo |

Không suy luận mọi file UI đang tồn tại đã có API. Các màn audit/history trong prototype chỉ được giữ khi đã đối chiếu endpoint hoặc có thiết kế thay thế được nhóm duyệt.

## Mốc ghép code

| Mốc | Kết quả cần đạt | Người phối hợp |
|---|---|---|
| M1 | Hào hoàn tất ghép sổ địa chỉ và test local; thống nhất màn chi tiết đơn nhận orderId | Hào + Hiệu |
| M2 | Bidder thắng → chọn địa chỉ → trả tiền; thông báo mở được đúng đơn | Hào + Hiệu |
| M3 | Seller gửi kho → kho xử lý → bidder theo dõi/nhận hàng | Hiệu + người nhận task Warehouse |
| M4 | Report phiên và tranh chấp được xử lý xuyên role | Cả ba |
| M5 | develop chạy ổn, docs phản ánh đúng commit, PR lên main | Hào review cùng nhóm |

Chưa ấn định ngày hoàn thành vì chưa có lịch và trạng thái nhánh của Hiệu/Khang. Mỗi người bổ sung ETA thực tế sau khi nhận task.

## Quy tắc bàn giao

Task hoàn thành cần có code trên nhánh/PR, đường dẫn màn hình, tham số điều hướng, API đã gọi, cách test và lỗi còn lại. Tách các trạng thái: đang làm → có code → đã kiểm thử → PR → merge develop → merge main. Cập nhật [progress.md](progress.md) theo bằng chứng; không đánh dấu xong chỉ vì có file UI.
