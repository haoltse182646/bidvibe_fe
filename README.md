# BidVibe — Prototype (Flutter)

Prototype app đấu giá đồ cũ & đồ sưu tầm theo thời gian thực. Chạy hoàn toàn bằng **dữ liệu giả** trong bộ nhớ (`lib/store.dart`), chưa kết nối backend; tắt app là dữ liệu về lại ban đầu.

## Chạy

Yêu cầu Flutter stable **≥ 3.38** (cả nhóm dùng chung một bản để `pubspec.lock` không bị đổi qua lại).

```bash
flutter pub get
flutter run      # máy ảo Android / LDPlayer / Chrome
flutter test     # test luồng chính + smoke test các màn
```

Mở app → **chọn vai trò** (Người mua, Người bán, Thẩm định, Kho vận, Admin). Muốn đổi vai trò: bấm **Đăng xuất** trên thanh DEMO rồi chọn lại.

## Main flow

```mermaid
flowchart TD
  S1["Người bán: tạo phiếu ký gửi<br/>(AI gợi ý giá khởi điểm)"] --> A1{"Thẩm định"}
  A1 -- "Yêu cầu bổ sung" --> S2["Người bán bổ sung"] --> A1
  A1 -- "Từ chối" --> X1(["Kết thúc"])
  A1 -- "Duyệt" --> B1["Phiên công khai"]
  B1 --> B2["Người mua: đặt cọc 10% giá khởi điểm"]
  B2 --> B3["Người mua: đặt giá<br/>(bị vượt giá → thông báo, đặt lại)"]
  B3 --> SYS{"Hệ thống: hết giờ, chọn người thắng"}
  SYS -- "Thua" --> R1(["Tự hoàn cọc"])
  SYS -- "Thắng" --> B4["Người mua: thanh toán phần còn lại trong 24 giờ<br/>(tiền giữ ở ký quỹ)"]
  B4 -- "Quá hạn" --> X2(["Mất cọc, huỷ giao dịch"])
  B4 --> S3["Người bán: gửi hàng tới kho"]
  S3 --> W1["Kho: nhận → kiểm → đóng gói → giao"]
  W1 -- "Không khớp mô tả" --> AD["Báo Admin"]
  W1 --> B5["Người mua: xác nhận đã nhận hàng"]
  B5 --> E(["Giải ngân cho người bán<br/>(tự động sau 72 giờ nếu không xác nhận)"])
```

| # | Vai trò | Việc | Màn hình | Hàm trong `AppStore` |
|---|---|---|---|---|
| 1 | Người bán | Tạo phiếu, dùng AI gợi ý giá | Tab **Tạo mới** · `seller/seller_create.dart` | `createListing` |
| 2 | Thẩm định | Duyệt / yêu cầu bổ sung / từ chối | **Hàng chờ** → `appraiser/appraiser_detail.dart` | `approveAppraisal`, `requestMoreInfo`, `rejectAppraisal` |
| 3 | Người mua | Đặt cọc, đặt giá | **Khám phá** → `bidder/bidder_detail.dart` | `joinAuction`, `placeBid` |
| 4 | Hệ thống | Hết giờ: chọn người thắng, hoàn cọc người thua | — (tick mỗi giây) | `_closeAuction` |
| 5 | Người mua | Thanh toán phần còn lại | `bidder/bidder_payment.dart` | `payForAuction` |
| 6 | Người bán | Gửi hàng tới kho | Tab **Gửi kho** · `seller/seller_shipping.dart` | `sellerMarkShipped` |
| 7 | Kho vận | Nhận, kiểm, đóng gói, giao | `warehouse/warehouse_board.dart` → `warehouse_detail.dart` | `whConfirmReceive`, `whConfirmInspect`, `whMarkPacked`, `whMarkShipped`, `whMarkDelivered` |
| 8 | Người mua | Xác nhận đã nhận → giải ngân | `bidder/bidder_done.dart` | `confirmDelivery` |

Chuỗi trên được kiểm tra trong `test/store_flow_test.dart` (nhóm **Luồng chính**), gồm cả test đi trọn một món hàng mới từ lúc tạo tới lúc giải ngân.

**Luồng phụ (Admin):** phiên bị gắn cờ kèm AI giải thích → tạm dừng / chấm dứt khẩn cấp (tab **Cờ**); tranh chấp → phán quyết hoàn tiền / giải ngân (tab **Tranh chấp**); báo cáo tài chính kèm AI tóm tắt (tab **Báo cáo**). Người mua/bán có chatbot hỗ trợ và mở tranh chấp (`customer/`).

### Demo nhanh, không phải chờ

Trong màn chi tiết phiên/đơn có khung **DEMO**:

- **Còn 10 giây** — rút thời gian phiên còn 10 giây và dừng bot, để người demo chắc thắng.
- **Mô phỏng bị vượt giá** — ép một lượt đặt giá đối thủ.
- **Mô phỏng quá hạn 24 giờ** — thử nhánh quá hạn thanh toán.
- **Mô phỏng quá 72 giờ** — thử tự động giải ngân.

## Dữ liệu giả

- Nằm trong `lib/store.dart` (`AppStore`), model ở `lib/models.dart`.
- Có sẵn: mỗi vai trò ≥ 3 tài khoản (mật khẩu `123456`), 10 phiên đấu giá (`a1`–`a10`) ở đủ trạng thái, hàng chờ thẩm định, đơn kho ở mọi trạng thái, phiên bị gắn cờ, tranh chấp.
- "Thời gian thực" giả lập bằng vòng tick mỗi giây: bot tự đặt giá, tự đóng phiên, hoàn cọc, xử lý quá hạn, tự giải ngân.
- AI (gợi ý giá, giải thích cờ, báo cáo, chatbot) trả nội dung soạn sẵn.
