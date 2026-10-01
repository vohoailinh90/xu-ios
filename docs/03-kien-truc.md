# 03 — Kiến trúc

## Tổng quan

```
┌──────────────────────────── Xu.app ─────────────────────────────┐
│  SwiftUI Views (Home, QuickEntryBar, History, Habits, Settings) │
│              │                                                  │
│              ▼                                                  │
│  App/Shared: Ledger (lưu), SharedStore (SwiftData, App Group),  │
│              App Intents (LogExpense, LogChip)                  │
└──────────────┬──────────────────────────────┬───────────────────┘
               │                              │
               ▼                              ▼
     ┌──────────────────┐          ┌──────────────────────┐
     │  XuCore (SPM)    │          │  XuWidgets extension │
     │  - Parser        │◄─────────│  dùng lại App/Shared │
     │  - Danh mục      │          │  + XuCore            │
     │  - Thói quen     │          └──────────────────────┘
     │  - Còn được tiêu │
     │  - Định dạng tiền│
     └──────────────────┘
     Thuần Swift + Foundation, không SwiftUI/SwiftData,
     test bằng `swift test` và chạy CI trên GitHub Actions.
```

## Quyết định kỹ thuật

| Chủ đề | Lựa chọn | Lý do |
|---|---|---|
| iOS tối thiểu | 17.0 | SwiftData, widget tương tác (Button với AppIntent), `sensoryFeedback`. Tỷ lệ iPhone trên iOS 17+ đã rất cao. |
| UI | SwiftUI | Nhanh, phù hợp widget. |
| Lưu trữ | SwiftData trong App Group | App, widget và intent cùng đọc/ghi một kho dữ liệu. |
| Đồng bộ | CloudKit (v1.1) | Miễn phí, riêng tư. **Ngay từ đầu** mọi thuộc tính @Model phải có giá trị mặc định, không dùng `@Attribute(.unique)`, quan hệ phải optional — đó là yêu cầu của CloudKit, tránh phải migrate đau đớn sau này. |
| Logic nghiệp vụ | Swift Package `XuCore` | Tách khỏi UI để test nhanh, dùng lại cho widget, Watch, và có thể cả app macOS sau này. |
| Parser | Luật (regex) là chính, AI là phụ | Luật: tức thì, offline, chạy trên mọi iPhone, dự đoán được, test được. AI trên máy (Apple Foundation Models) chỉ dùng làm phương án dự phòng cho câu khó, và chỉ trên máy hỗ trợ Apple Intelligence. |
| Tiền | `Int64` theo đơn vị nhỏ nhất + mã tiền tệ | VND không có số lẻ; không dùng `Double` cho tiền. Chuẩn bị sẵn cho đa tiền tệ (v1.2). |
| Mua hàng | StoreKit 2, non-consumable "Xu Pro" | Mua một lần, không cần server. |
| Phân tích | TelemetryDeck hoặc tự đếm cục bộ | Ưu tiên công cụ tôn trọng quyền riêng tư; không gửi nội dung giao dịch. |

## Mô hình dữ liệu (SwiftData)

```
TransactionRecord
  id: UUID
  amount: Int64            // luôn dương; chiều thu/chi nằm ở isIncome
  currencyCode: String     // "VND"
  isIncome: Bool
  categoryID: String       // khớp CategoryCatalog trong XuCore, vd "drinks"
  note: String             // phần chữ còn lại, giữ nguyên dấu: "cà phê"
  occurredAt: Date
  createdAt: Date
  sourceRaw: String        // quickText | voice | widgetChip | shortcut | applePay | screenshot | manual
  rawInput: String         // câu gốc người dùng gõ — chỉ lưu trên máy, dùng để cải thiện parser

QuickChip                  // khoản quen trên widget
  id, title, emoji, amount, categoryID, sortOrder

LearnedKeyword             // từ khóa học được khi người dùng sửa danh mục
  phrase: String           // đã bỏ dấu, chữ thường
  categoryID: String
  updatedAt: Date

MoneyHabit
  id, templateRaw, title, emoji, createdAt, isArchived
  checkIns: [HabitCheckIn]?   (cascade)

HabitCheckIn
  year, month, day, isRest, habit?

DayClosure                 // "chốt ngày"
  year, month, day, closedAt
```

Danh mục mặc định không lưu trong database mà định nghĩa trong code (`CategoryCatalog`), giúp dịch thuật và cập nhật từ khóa dễ dàng. Danh mục tùy chỉnh (Pro) sẽ là một model riêng ở v1.1.

## Luồng ghi một khoản chi

```
Người dùng gõ ──► QuickEntryParser.parse(text) ──► QuickEntryResult (xem trước, cập nhật mỗi lần gõ)
                                                        │ Enter
                                                        ▼
                                             Ledger.save(result) ──► SwiftData
                                                        │
                                   WidgetCenter.reloadAllTimelines() + rung nhẹ + toast Hoàn tác
```

Parser chạy trên mỗi lần gõ phím nên phải nhanh: mục tiêu < 1 ms mỗi lần. Regex được biên dịch một lần (static).

## Giới hạn của nền tảng iOS cần biết trước

- **Không đọc được thông báo biến động số dư** của app ngân hàng (khác Android). Đừng hứa "tự động ghi từ ngân hàng".
- **Siri và tiếng Việt.** Siri hỗ trợ tiếng Việt từ iOS 18.4, nên câu lệnh App Shortcut cần được bản địa hóa tiếng Việt (file `AppShortcuts.xcstrings`) và kiểm tra trên máy thật. "Siri AI" thế hệ mới (iOS 27) lúc ra mắt chỉ có tiếng Anh. Câu lệnh Siri nên ngắn và cố định ("Ghi chi tiêu với Xu"), còn nội dung khoản chi nói ở bước hỏi tiếp. Trong app, giọng nói dùng đọc chính tả của bàn phím hoặc framework Speech.
- **Widget màn hình khóa không tương tác được** như widget màn hình chính: chạm vào chỉ mở app. Vì vậy app phải mở thẳng vào ô nhập với bàn phím sẵn sàng.
- **Apple Pay automation**: app Phím tắt có tự động hóa "Giao dịch" chạy khi thanh toán bằng thẻ trong Wallet. Người dùng phải tự tạo automation (app cung cấp hướng dẫn và intent nhận số tiền, tên cửa hàng). Chỉ áp dụng cho thẻ đã thêm vào Apple Pay.
- **OCR tiếng Việt**: cần kiểm chứng `VNRecognizeTextRequest.supportedRecognitionLanguages()` trên iOS 17/18 có `vi-VT` hay không trước khi cam kết tính năng. Nếu chưa có, chỉ cần đọc số tiền và ngày (chữ số và ký tự Latin) là đủ dùng — đây là spike trong M4.
- **Apple Foundation Models** chỉ có trên thiết bị hỗ trợ Apple Intelligence và phụ thuộc ngôn ngữ được hỗ trợ; luôn phải có đường lui bằng parser luật.

## Quy ước code

- Logic không cần UI → đặt trong `XuCore`, có test.
- View không gọi thẳng `modelContext.insert` cho giao dịch; luôn đi qua `Ledger` để mọi kênh nhập (app, widget, intent) xử lý giống nhau.
- Chuỗi hiển thị dùng String Catalog (`Localizable.xcstrings`), tiếng Việt là ngôn ngữ phát triển chính, tiếng Anh là bản dịch.
- Mỗi PR thay đổi parser phải thêm test case tương ứng.
