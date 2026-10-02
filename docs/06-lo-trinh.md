# 06 — Lộ trình

Mục tiêu: **TestFlight sau 6 tuần** (một người, làm bán thời gian ~15–20 giờ/tuần). `scripts/create-issues.sh` tạo sẵn các issue dưới đây trên GitHub.

> `[x]` = đã có code, test XuCore xanh và app build được trên CI (iOS Simulator). **Chưa chạy thử trên máy thật** —
> mục nào cũng cần thử tay trước TestFlight. Cập nhật 2026-10-02.

## M0 — Nền móng (tuần 1)
- [ ] #setup Tạo repo, chạy `xcodegen`, build app rỗng lên máy thật
- [ ] #setup Cấu hình App Group, bundle ID, signing cho app + widget
- [x] #setup Bật CI GitHub Actions chạy `swift test` cho XuCore
- [ ] #research Đọc 100 review 1–3 sao của Money Lover, MISA, Spendee; ghi lại 20 câu người dùng hay phàn nàn
- [ ] #research Thu thập 200 câu nhập thật (nhờ bạn bè gõ thử) → biến thành test case cho parser

## M1 — Ghi chép lõi (tuần 2–3)
- [x] #parser Hoàn thiện parser số tiền + ngày, đạt 100% test hiện có
- [ ] #parser Bổ sung test từ 200 câu thật thu thập ở M0
- [x] #core Mở rộng từ khóa danh mục mặc định, kiểm tra trùng nghĩa khi bỏ dấu
- [x] #app QuickEntryBar: tự focus, xem trước, Enter lưu, giữ focus sau khi lưu
- [x] #app Thẻ xem trước: sửa danh mục bằng 1 chạm (lưới emoji)
- [x] #app Học từ khóa khi người dùng sửa danh mục (LearnedKeyword)
- [x] #app Toast "Đã ghi · Hoàn tác"
- [x] #app Danh sách giao dịch theo ngày, sửa/xóa
- [x] #app Xuất CSV qua ShareLink

## M2 — Kênh nhập nhanh (tuần 4)
- [x] #widget Widget màn hình chính với nút khoản quen tương tác (LogChipIntent)
- [x] #widget Widget màn hình khóa: "hôm nay đã tiêu", chạm mở app
- [x] #app Quản lý khoản quen: tự đề xuất từ khoản lặp lại, ghim/bỏ ghim, sắp xếp (tối đa 8; giới hạn Free 2 nút widget làm cùng paywall ở M4)
- [x] #intent App Shortcut "Ghi chi tiêu" + hướng dẫn gán vào Action Button
- [x] #intent Intent nhận số tiền + tên cửa hàng cho automation Apple Pay; màn hình hướng dẫn cài đặt (Cài đặt › Nhập nhanh hơn; tên mục trong app Phím tắt cần kiểm tra trên máy thật)

## M3 — Thói quen & còn được tiêu (tuần 5)
- [x] #core HabitEngine: tự đánh giá thói quen mẫu theo giao dịch + chốt ngày
- [x] #app Thẻ "Hôm nay còn được tiêu" trên Home
- [x] #app Màn hình thói quen: vòng sức mạnh, chuỗi mềm, đánh dấu thủ công, ngày nghỉ
- [x] #app Thông báo "Chốt ngày" với nút hành động
- [x] #app Tổng kết tuần (Chủ nhật)

## M4 — Hoàn thiện & TestFlight (tuần 6)
- [x] #app Onboarding 3 màn
- [x] #app Paywall + StoreKit 2 (Xu Pro, mua một lần), khôi phục giao dịch; giới hạn Free trong `docs/02`: 2 thói quen
  (thói quen cũ không bị tắt), 2 nút widget. Cần làm trước TestFlight: tạo sản phẩm non-consumable `com.example.xu.pro`
  (đổi theo bundle ID) trong App Store Connect, chọn giá theo `docs/07` — cần kiểm tra.
  Chưa khoá: Apple Pay automation (`docs/02` xếp vào Pro, nhưng đó cũng là một đường ghi — luật "không khoá việc ghi"; cần quyết).
  Lời mời Pro một lần sau 7 ngày liền (`docs/07`): thẻ trên Home vào ngày sau chuỗi 7 ngày, ở lại hết ngày đó, chạm mới mở paywall.
- [x] #app Chính sách quyền riêng tư, App Privacy trên App Store Connect (`docs/09`): màn Cài đặt › Quyền riêng tư (offline,
  vi/en/ja), privacy manifest cho app + widget, bản chính sách `docs/privacy-policy.md`, câu trả lời App Privacy
  "Data Not Collected". Còn làm trước khi nộp: đăng chính sách ở URL công khai, điền tên + email liên hệ, điền App Privacy
  trên App Store Connect — cần kiểm tra văn bản mới nhất của Apple và luật Việt Nam/Nhật.
- [ ] #research Spike: OCR ảnh chuyển khoản bằng Vision — kiểm tra hỗ trợ tiếng Việt, độ chính xác với 5 ngân hàng phổ biến
- [ ] #release Đo thời gian ghi trung vị (log cục bộ), sửa chỗ chậm — đã có phần đo (`EntryTimingLog`, hiện ở Cài đặt › Nhập nhanh hơn);
  còn sửa chỗ chậm khi có số liệu thật từ TestFlight
- [ ] #release TestFlight cho 20–50 người dùng thử, form phản hồi

## v1.1 (sau ra mắt)
- Đồng bộ iCloud · OCR chuyển khoản · Tách nhiều khoản · Số bằng chữ (giọng nói) · Face ID · Danh mục tùy chỉnh · Biểu đồ tháng · Control Center control
- Đã làm sớm (2026-10-02): tách nhiều khoản trong một câu (E8, `docs/04`) — nút gợi ý trên thẻ xem trước, Enter vẫn lưu một khoản.
  Biểu đồ tháng (O4): màn "Theo tháng" (nút 📊 trên Home), chi theo danh mục bằng tiền của nơi chi tiêu, tiền khác chỉ
  vào tổng; bản Free xem tháng này, Xu Pro xem lại các tháng trước (`docs/02`), chạm "tháng trước" mới mở paywall.
  Control Center control (W4, iOS 18): nút "Ghi chi tiêu" cho Trung tâm điều khiển / màn hình khoá / Nút Tác vụ, chạm là mở
  Xu với con trỏ trong ô ghi (`QuickEntryControl`, `OpenQuickEntryIntent`); gợi ý trong Cài đặt › Nhập nhanh hơn.
  Cần thử trên máy thật iOS 18: thêm nút, chạm khi app đang đóng và khi app đang mở một màn khác.
  Số bằng chữ (E9, `docs/04`): "ba mươi lăm nghìn", "một triệu hai" từ đọc chính tả — chỉ khi có đơn vị và chữ có dấu.

## v1.2
- Đa tiền tệ cho người Việt ở nước ngoài · Mục tiêu gửi tiền về nhà · Apple Watch · Thử thách + Live Activity
- Đã làm sớm (2026-10-01, `docs/08`): tiền yên + thị trường Nhật, câu nhập tiếng Nhật/Anh, chọn ngôn ngữ giao diện Việt/Anh/Nhật.
  Còn lại cho Nhật: đọc ảnh hoá đơn Nhật (chấm độ chính xác trước bằng `prototypes/cham-bien-lai.html`).
  Siri tiếng Nhật (`App/Xu/AppShortcuts.xcstrings`) và nội dung App Store tiếng Nhật (`docs/10`) đã có; cần người Nhật
  đọc lại câu chữ và thử Siri trên máy thật.

## Quy trình làm việc đề xuất

- Nhánh `main` luôn build được. Mỗi issue một nhánh `feature/<số-issue>-<mô-tả>`.
- PR nhỏ, có ảnh chụp màn hình nếu đổi UI, có test nếu đổi XuCore.
- Cuối mỗi milestone: ghi lại thời gian ghi trung vị và 3 điều học được vào `docs/nhat-ky.md`.
