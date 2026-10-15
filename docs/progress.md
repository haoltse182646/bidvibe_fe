# Tiến độ và phạm vi đã triển khai

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

## Giới hạn hiện tại

- Tóm tắt đơn ở Hồ sơ có dữ liệu thật nhưng không thay cho module đơn/thanh toán đầy đủ.
- Thông báo orderId/disputeId/listingId còn có đường hiển thị bottom sheet nội dung/mã; chưa đồng nghĩa bấm sẽ vào màn nghiệp vụ thật.
- Thông báo realtime khi app đang mở; chưa có push notification hệ điều hành khi app đã tắt.
- OTP/2FA bị vô hiệu hóa và ghi chưa khả dụng; chưa có API quản lý thiết bị. Không có danh sách thiết bị thật.
- Chatbot BE đang dùng câu trả lời theo logic từ khóa; không có bằng chứng kết nối mô hình AI hội thoại hoặc tra cứu số dư cá nhân.
- Nạp ví và phương thức thanh toán QR/card trong BE là mô phỏng theo docs; không coi là tích hợp thanh toán thương mại.
- Các màn seller/appraiser/warehouse/admin tồn tại trong source nhưng trạng thái API thực tế cần Hiệu/Khang xác nhận.

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
| Module Hiệu/Khang | Chưa đọc nhánh riêng | Mỗi người cập nhật PR và trạng thái |

## Nhật ký cập nhật tiếp theo

Mỗi thay đổi đáng kể thêm một hàng, giữ thông tin không nhạy cảm:

| Ngày | Task | Người | Thay đổi | Kiểm thử | PR/commit | Merge |
|---|---|---|---|---|---|---|
| 16/10/2026 | DOC | Hào | Chuẩn bị bộ docs FE và phân công để đưa vào repo | Đối chiếu source/bàn giao | Chưa commit tại mốc soạn | Chưa xác minh |
