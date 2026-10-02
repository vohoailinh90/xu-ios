# 03 — Kiến trúc

## Tổng quan

```
┌──────────────────────────── Xu.app ─────────────────────────────┐
│  SwiftUI Views (Home, QuickEntryBar, History, Habits, Settings) │
│              │                                                  │
│              ▼                                                  │
│  App/Shared: Ledger (lưu), SharedStore (SwiftData, App Group),  │
│              AppSettings (ngôn ngữ, nơi chi tiêu — App Group),  │
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
     │  - Tiền tệ, nơi  │
     │    chi tiêu      │
     │  - Bảng chuỗi    │
     │    vi / en / ja  │
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
| Tiền | `Int64` theo đơn vị nhỏ nhất + mã tiền tệ | VND không có số lẻ; không dùng `Double` cho tiền. Đã có VND và JPY (2026-10-01, `docs/08`); không quy đổi tỷ giá. |
| Ngôn ngữ giao diện | Bảng chuỗi `L10n` trong `XuCore` (vi/en/ja), chọn trong app | Đổi ngay không cần mở lại app; widget/Phím tắt đọc cùng lựa chọn qua App Group; test được bằng `swift test`. Xem `docs/08`. |
| Mua hàng | StoreKit 2, non-consumable "Xu Pro" | Mua một lần, không cần server. `ProStore` (app) nghe giao dịch, lưu bản sao `isPro` vào App Group cho widget; giới hạn Free ở `ProPlan` (XuCore). Giá lấy từ App Store, không ghi cứng. |
| Phân tích | TelemetryDeck hoặc tự đếm cục bộ | Ưu tiên công cụ tôn trọng quyền riêng tư; không gửi nội dung giao dịch. |

## Mô hình dữ liệu (SwiftData)

```
TransactionRecord
  id: UUID
  amount: Int64            // luôn dương; chiều thu/chi nằm ở isIncome
  currencyCode: String     // "VND" | "JPY" — loại tiền lúc ghi, không đổi khi đổi nơi chi tiêu
  isIncome: Bool
  categoryID: String       // khớp CategoryCatalog trong XuCore, vd "drinks"
  note: String             // phần chữ còn lại, giữ nguyên dấu: "cà phê"
  occurredAt: Date
  createdAt: Date
  sourceRaw: String        // quickText | voice | widgetChip | shortcut | applePay | screenshot | manual
  rawInput: String         // câu gốc người dùng gõ — chỉ lưu trên máy, dùng để cải thiện parser

QuickChip                  // khoản quen trên widget, tối đa 8; widget hiện theo sortOrder (vừa 4, nhỏ 2)
  id, title, emoji, amount, currencyCode, categoryID, sortOrder
  // thêm/sửa/bỏ ghim/sắp xếp qua QuickChipStore; gợi ý từ ChipSuggester (XuCore): cùng ghi chú + số tiền
  // + loại tiền, ít nhất 3 ngày khác nhau trong 30 ngày. Người dùng đã tự sửa thì không seed lại mặc định.

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
- **Apple Pay automation**: app Phím tắt có tự động hóa "Giao dịch" chạy khi thanh toán bằng thẻ trong Wallet. Người dùng phải tự tạo automation (app cung cấp hướng dẫn `ApplePayGuideView` và intent `LogPaymentIntent` nhận số tiền kèm loại tiền của giao dịch và tên cửa hàng; tiền chưa hỗ trợ thì không ghi và báo người dùng ghi tay). Luồng này cần thử trên máy thật. Chỉ áp dụng cho thẻ đã thêm vào Apple Pay.
- **OCR tiếng Việt**: cần kiểm chứng `VNRecognizeTextRequest.supportedRecognitionLanguages()` trên iOS 17/18 có `vi-VT` hay không trước khi cam kết tính năng. Nếu chưa có, chỉ cần đọc số tiền và ngày (chữ số và ký tự Latin) là đủ dùng — đây là spike trong M4.
- **Apple Foundation Models** chỉ có trên thiết bị hỗ trợ Apple Intelligence và phụ thuộc ngôn ngữ được hỗ trợ; luôn phải có đường lui bằng parser luật.

## Quy ước code

- Logic không cần UI → đặt trong `XuCore`, có test.
- View không gọi thẳng `modelContext.insert` cho giao dịch; luôn đi qua `Ledger` để mọi kênh nhập (app, widget, intent) xử lý giống nhau.
- Chuỗi hiển thị lấy từ bảng `L10n` trong `XuCore` (`AppLanguage.t(.key)`), đủ 3 thứ tiếng; tiếng Việt là ngôn ngữ phát triển chính.
  Không viết chữ cứng trong View. String Catalog (`App/Shared/Localizable.xcstrings`) chỉ cho chuỗi hệ thống tự đọc theo ngôn ngữ máy
  (tiêu đề App Intents). Lý do: `docs/08`.
- Cài đặt mà widget/Phím tắt cũng cần (ngôn ngữ, nơi chi tiêu) nằm trong `AppSettings` (UserDefaults của App Group), không ở `UserDefaults.standard`.
- Tiền luôn đi kèm loại tiền: `MoneyFormatter.full/compact(amount, currency:, language:)`; tổng chi cộng riêng từng loại tiền.
- Sửa giao dịch và chốt ngày cũng đi qua `Ledger` (`update`, `setDayClosed`), như khi ghi mới.
- Thông báo chỉ đặt lịch cục bộ (`ReminderScheduler`, không máy chủ); nút trên thông báo xử lý ở `AppDelegate`.
  Mỗi ngày một thông báo riêng, đặt trước 14 ngày và nạp thêm mỗi lần mở app; ngày cần chốt nằm trong `userInfo`,
  nên bấm sau nửa đêm hay ở múi giờ khác vẫn chốt đúng ngày. Ngày đã nhắc rồi (đã đặt mà không còn trong danh sách chờ của iOS) thì đổi giờ nhắc cũng không nhắc lại.
- Ngày/tháng/năm luôn theo lịch Gregorian giữ múi giờ (`Calendar.gregorianSameTimeZone`): `DayKey`, câu nhập, cuối tháng
  của ngân sách, tuần — kể cả khi máy đặt lịch Nhật (năm Reiwa) hay lịch Hồi giáo.
- Mỗi PR thay đổi parser phải thêm test case tương ứng.
