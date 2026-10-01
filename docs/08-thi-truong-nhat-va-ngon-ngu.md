# 08 — Thị trường Nhật và ngôn ngữ giao diện

## Quyết định (2026-10-01)

- Chủ dự án quyết định **làm sớm** hai việc: dùng được ở Nhật (tiền yên, câu nhập tiếng Nhật) và **chọn ngôn ngữ giao diện**
  trong app: Tiếng Việt · English · 日本語.
- Lý do: chủ dự án đang ở Nhật, hoá đơn gom được để thử đều là hoá đơn Nhật. Chân dung C "Người Việt ở nước ngoài"
  trong `docs/01` vốn để ở v1.2; phần Nhật được kéo lên trước.
- Quyết định này đưa ra trong tuần validate (2026-09-26 → 2026-10-03), mà kế hoạch ở App-idea-lab ghi "không code thêm tính năng".
  Các ngưỡng validate vẫn chấm như kế hoạch. Việc cần làm: ghi quyết định này vào nhật ký ý tưởng ở App-idea-lab.
- **Việt Nam trước vẫn giữ nguyên:** tiếng Việt là ngôn ngữ phát triển chính; parser tiếng Việt không đổi hành vi (mọi test cũ giữ nguyên);
  máy không đặt vùng Nhật thì mặc định là thị trường Việt Nam.

## Đã làm

| Phần | Chi tiết | Code |
|---|---|---|
| Nơi chi tiêu | Việt Nam / Nhật Bản, chọn trong Cài đặt (lần đầu đoán theo vùng của máy). Quyết định tiền cho số trần, thứ tự ngày/tháng, từ lóng "man"/"sen" | `XuCore/.../Market.swift` |
| Tiền | VND và JPY, đều không có số lẻ nên vẫn lưu `Int64`. Mỗi giao dịch và khoản quen lưu `currencyCode` | `Market.swift`, `App/Shared/Persistence/Models.swift` |
| Câu nhập | 円, ¥, yên, số kiểu Nhật (1万2千), chữ số toàn khổ, ngày tiếng Nhật và tiếng Anh. Đặc tả ở `docs/04` | `QuickEntryParser.swift` |
| Danh mục | Tên 3 thứ tiếng; thêm từ khoá tiếng Nhật (コンビニ, 電車, 家賃, 仕送り…) và tiếng Anh | `CategoryCatalog.swift` |
| Ngôn ngữ | Chọn trong Cài đặt, đổi ngay. Toàn bộ chữ trong app, widget, lời thoại Phím tắt, CSV | `Localization.swift`, `App/Shared/Settings/AppSettings.swift` |
| Định dạng tiền | 1.250.000đ · 1,250,000₫ · ¥1,250 · 1,250円 (theo tiền và ngôn ngữ) | `MoneyFormatter.swift` |
| Khoản quen mặc định | Theo nơi chi tiêu (🏪 コンビニ 500, 🚃 電車 200…). Đổi ngôn ngữ/nơi thì tự đổi theo, nếu người dùng chưa sửa | `App/Shared/Persistence/ChipSeeds.swift` |
| Trang chấm hoá đơn | Chế độ hoá đơn cửa hàng ở Nhật (レシート) trong `prototypes/cham-bien-lai.html` | — |

## Quy tắc

- **Không quy đổi tỷ giá.** Tỷ giá cần mạng, trái nguyên tắc offline. Mỗi loại tiền cộng riêng: "Hôm nay đã tiêu", "còn được tiêu"
  và widget chỉ tính tiền của nơi chi tiêu; khoản bằng tiền khác (ví dụ "gửi về nhà 5tr" khi đang ở Nhật) hiện ở dòng "Tiền khác".
- **Ngân sách tiêu vặt:** mỗi nơi chi tiêu một con số (đổi nơi không biến 3.000.000đ thành 3.000.000 yên).
- **Đổi nơi chi tiêu không sửa giao dịch cũ.** Giao dịch giữ đúng loại tiền lúc ghi.
- **Ngôn ngữ giao diện và ngôn ngữ câu nhập độc lập.** Giao diện tiếng Nhật vẫn gõ được "cơm 980 yên"; parser luôn hiểu cả ba thứ tiếng.

## Vì sao giao diện không dùng String Catalog

`docs/03` ban đầu định dùng String Catalog. Đổi sang bảng chuỗi trong `XuCore` (`L10n`) vì:

- Người dùng chọn ngôn ngữ **trong app** và đổi ngay, không cần mở lại app; widget và Phím tắt (chạy ở tiến trình khác) cũng theo lựa chọn này qua App Group.
- Bảng chuỗi nằm trong `XuCore` nên test được bằng `swift test`: thiếu một thứ tiếng là lỗi biên dịch, test kiểm tra chỗ trống `{0}` khớp giữa các bản dịch.
- Không cần Xcode để thêm chuỗi.

String Catalog chỉ còn dùng cho chuỗi **hệ thống tự đọc theo ngôn ngữ của máy**: tiêu đề và mô tả App Intents trong app Phím tắt
(`App/Shared/Localizable.xcstrings`).

## Chưa làm / cần kiểm tra

- **Đọc ảnh hoá đơn Nhật trong app** (Vision OCR): chưa làm. Trước hết chấm độ chính xác bằng trang `prototypes/cham-bien-lai.html`
  (chế độ hoá đơn Nhật). Ý tưởng và chấm điểm tính năng này làm ở App-idea-lab (luật 8), chưa có file tính năng.
- Số viết bằng chữ Hán (千五百円), năm theo niên hiệu (令和) — parser chưa hiểu.
- Siri tiếng Nhật: câu lệnh "Xuで支出を記録" đã có trong code, nhưng câu lệnh theo từng ngôn ngữ cần `AppShortcuts.xcstrings`
  và thử trên máy thật đặt Siri tiếng Nhật.
- Bản dịch tiếng Anh/Nhật do AI viết — cần người bản ngữ đọc lại trước TestFlight.
- App Store: mô tả, từ khoá, ảnh chụp tiếng Nhật/Anh; giá Xu Pro ở Nhật theo bảng giá App Store — **cần kiểm tra**.
  Danh sách ngôn ngữ hiện trên App Store lấy từ bản địa hoá trong gói app — kiểm tra sau lần tải lên đầu tiên là có đủ 3 ngôn ngữ.
- Pháp lý ở Nhật: luật bảo vệ thông tin cá nhân (個人情報保護法), nghĩa vụ hiển thị khi bán hàng trực tuyến (特定商取引法)
  khi bán Xu Pro, quy định mới về nền tảng app trên điện thoại — **cần kiểm tra văn bản mới nhất**, đây không phải tư vấn pháp lý.
  Mọi tính năng số vẫn bán qua IAP (StoreKit 2), không lách IAP.
- Dữ liệu vẫn chỉ nằm trên máy (luật 6): không thêm máy chủ, không gửi gì ra ngoài.
