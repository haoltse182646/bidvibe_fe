# Chatbot — cập nhật ngày 13/11/2026

## BE và môi trường

- BE local đã fast-forward từ `15d3308` lên `6cb86c9` trên `main`. Thay đổi `package-lock.json` có sẵn của máy được giữ nguyên; không chạy seed/reset/migration trên DB dùng chung trong tác vụ này.
- API của app vẫn là `https://bidvibe-be.onrender.com`. Đã kiểm tra hành vi mới trên API deploy; health không trả commit SHA nên không khẳng định SHA của Render chỉ từ kết quả test.
- Chatbot dùng chuẩn hóa tiếng Việt, chấm điểm từ khóa, kiến thức nghiệp vụ, ngữ cảnh trong phiên và truy vấn dữ liệu của chính người đăng nhập. Không gọi Gemini hay mô hình AI ngoài.

## Hợp đồng API giữ nguyên

| Mục đích | API | Cách sử dụng FE |
|---|---|---|
| Gửi câu hỏi đầu tiên | POST `/api/chat/messages` | Bearer token của bidder/seller; body `{ "content": "..." }` |
| Hỏi tiếp | POST `/api/chat/messages` | Body `{ "content": "Còn gì nữa?", "sessionId": "..." }`; giữ sessionId đã nhận |
| Khôi phục/tải lại | GET `/api/chat/sessions/:id/messages` | Chỉ lấy hội thoại thuộc tài khoản hiện tại |

POST trả HTTP 201, `{ success, data: { sessionId, messages: [userMessage, botMessage] } }`. Mỗi message có id, sender, content, createdAt. Câu trả lời có thể chứa nhiều dòng. Giới hạn content 2000 ký tự. Không có endpoint liệt kê/xóa phiên chat trong router hiện tại.

`ChatRepository` và `ChatController` hiện tại đã đáp ứng hợp đồng này: giữ đúng session, lưu theo tài khoản + API URL, không tạo phiên trước khi gửi, không tự gửi lại khi chưa rõ kết quả, xử lý lịch sử/quyền và tránh phản hồi muộn đi vào tài khoản khác. Không thêm API hoặc câu trả lời giả ở FE.

## Thay đổi FE

| File | Vai trò |
|---|---|
| `lib/features/chat/chat_prompts.dart` | 12 chủ đề khớp BE; 4 câu hỏi cá nhân chỉ gợi ý cho bidder; câu nối tiếp khi đã có tin nhắn |
| `lib/screens/customer/customer_chatbot.dart` | Gợi ý nhanh, bảng Tất cả chủ đề, lời chào theo role, ghi chú thời điểm của dữ liệu cá nhân |
| `test/chat_upgrade_test.dart` | Không tự hỏi dữ liệu cá nhân; câu nối tiếp giữ session; seller không có prompt ví/cọc riêng; màn hình nhỏ |

Các câu hỏi cá nhân của bidder:

- **Số dư ví:** “Số dư ví của tôi là bao nhiêu?”
- **Cọc đang giữ:** “Tiền cọc của tôi đang được giữ bao nhiêu?”
- **Phiên của tôi:** “Tôi đang dẫn đầu phiên nào?”
- **Đơn cần trả tiền:** “Đơn hàng của tôi cần thanh toán là những đơn nào?”

Các câu trả lời là dữ liệu tại thời điểm hỏi, không tự cập nhật realtime trong bong bóng chat. Hỏi lại hoặc mở màn nghiệp vụ tương ứng để xem dữ liệu mới. Mở chatbot không tự gửi các câu hỏi cá nhân.

## Xác nhận

- `flutter analyze`: No issues found.
- `flutter test test/chat_api_test.dart test/chat_screen_test.dart test/chat_upgrade_test.dart --reporter expanded`: **31 PASS** (unit/widget, HTTP được mock).
- Đối chiếu 12 prompt chủ đề FE với bộ hiểu câu hỏi mới của BE: **12/12 khớp đúng chủ đề**.
- `node scripts/test_ai_unit.js` ở BE: **13 PASS** (kiến thức chatbot và thống kê gợi ý giá; không tạo fixture DB).

| Kiểm tra API thật trên Render | Kết quả |
|---|---|
| Câu không dấu `coc co mat ko` nhận câu trả lời về đặt cọc | PASS |
| `Còn gì nữa?` trong cùng session nhận thông tin bổ sung về cọc | PASS |
| Hai bidder có số dư khác nhau nhận đúng số dư riêng, đối chiếu GET wallet | PASS |
| Hỏi tiền cọc của mình khi chưa có cọc | PASS |
| Hỏi phiên đang dẫn đầu khi chưa có lượt giá | PASS |
| Hỏi đơn cần thanh toán khi chưa có đơn | PASS |
| Tải lịch sử nhận đúng 12 tin của session kiểm thử | PASS |
| Bidder khác đọc lịch sử session đó bị từ chối 404 NOT_FOUND | PASS |

Dùng hai bidder mới, chỉ nạp ví mô phỏng cho một bidder. Cleanup PASS; kiểm tra chỉ đọc xác nhận còn 0 account, 0 chat session và 0 wallet transaction của lượt đó. Không thay đổi hội thoại của tài khoản nhóm. Các nhánh “đang có cọc/đơn/phiên dẫn đầu” chưa được dựng dữ liệu thật trong lượt kiểm tra này. Đây chưa phải một lượt E2E chatbot UI trên thiết bị Android.

## Kiểm tra thủ công trên app

1. Tại gốc FE chạy `flutter run -d emulator-5554` (hoặc hot restart nếu app đang chạy đúng cấu hình). Không cần chạy BE local khi vẫn dùng Render.
2. Đăng nhập bidder → Hồ sơ → Trợ lý hỗ trợ BidVibe.
3. Chọn **Số dư ví**, đối chiếu số dư trên tab Ví.
4. Hỏi `coc co mat ko`, rồi chọn **Còn gì nữa?** trong cùng hội thoại. Bot phải bổ sung quy tắc cọc, không bắt đầu session mới.
5. Mở **Tất cả chủ đề** và thử người thắng phiên, gia hạn phút chót, tạm dừng/hủy phiên.
6. Thoát rồi mở lại chatbot: lịch sử vẫn giữ. Bấm **Hội thoại mới** để kiểm tra phiên mới chỉ được tạo sau câu hỏi đầu tiên.
7. Thử tài khoản seller: ưu tiên đăng tin bán hàng, không hiển thị các nút dữ liệu ví/cọc cá nhân của bidder.

Gợi ý giá là module riêng (`ai_price_suggestion.js`), không phải API chatbot. Thay đổi gửi title để ưu tiên sản phẩm tương tự chưa được ghép vào màn seller trong tác vụ chatbot này.
