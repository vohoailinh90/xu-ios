# 09 — Quyền riêng tư & App Privacy

> Tài liệu kỹ thuật để chuẩn bị nộp App Store, **không phải tư vấn pháp lý**. Mọi chỗ nói về luật hay quy định
> của Apple đều **cần kiểm tra văn bản mới nhất** trước khi nộp (và khi luật Việt Nam/Nhật thay đổi).
> Cập nhật 2026-10-04.

## Nguyên tắc (README, luật 6 của CLAUDE.md)

Xu **không thu thập dữ liệu**: không máy chủ, không tài khoản, không quảng cáo, không SDK bên thứ ba, không công cụ
phân tích. Muốn gửi bất cứ thứ gì ra khỏi máy (phân tích, báo lỗi, gửi câu nhập sai, đồng bộ iCloud…) thì phải
ghi quyết định vào tài liệu này trước, rồi sửa cả ba chỗ: privacy manifest, câu trả lời App Privacy và chính sách.

## Kiểm kê dữ liệu (trên máy)

| Dữ liệu | Nơi lưu | Ai đọc | Ra khỏi máy? |
|---|---|---|---|
| Giao dịch: số tiền, loại tiền, danh mục, ghi chú, ngày, nguồn ghi, **câu gốc người dùng gõ** (`rawInput`) | SwiftData trong App Group | App, widget, App Intents | Không (trừ khi người dùng tự xuất CSV) |
| Khoản Apple Pay chưa được tự ghi vì bản Free hết lượt tháng đó (số tiền, loại tiền, người bán, lúc xảy ra; mỗi khoản một khoá `pendingPayment.<id>`, không giới hạn số khoản; xoá khi người dùng bỏ khỏi danh sách (sau khi tự ghi tay, hoặc khi không cần); kèm mã ngẫu nhiên `pendingPaymentsRevision` để màn đang mở biết đọc lại, không chứa dữ liệu người dùng; docs/02) | UserDefaults của App Group | App, App Intents | Không |
| Khoản quen, từ khoá học được, thói quen, đánh dấu thói quen, chốt ngày | SwiftData trong App Group | App, widget, App Intents | Không |
| Ngôn ngữ, nơi chi tiêu, nhắc buổi tối (bật/giờ, ngày đã nhắc), thời gian ghi (`EntryTimingLog`, 200 lần gần nhất), bản sao `isPro`, bộ đếm lượt dùng miễn phí trong tháng (`applePayQuota`: số khoản Apple Pay đã tự ghi; `receiptQuota`: số ảnh biên lai đã đọc, chỉ bản Debug; docs/02), lúc bắt đầu chờ duyệt mua Xu Pro (`proPendingSince`), lời mời Pro đã hiện/đã tắt (`proInviteDay`, `proInviteDismissed`), đã hỏi đánh giá App Store chưa (`reviewRequested`), khoá Face ID bật/tắt (`faceIDLock`, tắt sẵn) | UserDefaults của App Group | App, widget | Không |
| Ngân sách tháng, "số nhỏ là nghìn" | UserDefaults riêng của app | App | Không |
| Thông báo nhắc chốt ngày, và thông báo báo một khoản Apple Pay chưa được tự ghi vì hết lượt miễn phí (không nêu số tiền hay cửa hàng; chỉ gửi khi người dùng đã cho phép thông báo) | Thông báo cục bộ của iOS | iOS | Không (không dùng push từ máy chủ) |
| Tệp CSV tạm khi xuất (`xu-giao-dich.csv`) | Thư mục tạm của app | App, bảng chia sẻ của iOS | Chỉ khi người dùng chọn nơi gửi; xoá khi đóng bảng chia sẻ, và bảng chia sẻ tự đóng khi khoá Face ID |

Các đường dữ liệu đi qua hệ thống của Apple (Xu không nhận gì thêm):

- **Mua/khôi phục Xu Pro (StoreKit 2):** Apple xử lý thanh toán. Xu chỉ đọc quyền đã mua (`Transaction.currentEntitlements`)
  và giá hiển thị (`Product.displayPrice`). Xu không nhận thông tin thẻ hay tài khoản Apple.
- **Phím tắt / tự động hoá Apple Pay:** người dùng tự cài. iOS chuyển cho Xu câu nhập, hoặc số tiền (kèm mã loại tiền) + tên cửa hàng (`LogPaymentIntent`), ngay trên máy.
  Gọi bằng giọng nói qua Siri thì việc nhận dạng giọng nói là của Apple — cần kiểm tra cách diễn đạt nếu App Review hỏi.
- **Khoá Face ID (LocalAuthentication):** iOS xử lý khuôn mặt hoặc mật mã ngay trên máy; Xu chỉ nhận kết quả đúng/sai,
  không nhận dữ liệu sinh trắc học và không lưu gì thêm ngoài công tắc bật/tắt. Không thu thập dữ liệu nên không đổi
  câu trả lời App Privacy — cần kiểm tra văn bản mới nhất.
- **Xuất CSV:** người dùng tự chọn nơi gửi tệp qua bảng chia sẻ. Đây là hành động của người dùng, không phải Xu thu thập.
- **Sao lưu iPhone (iCloud Backup / máy tính):** dữ liệu Xu có thể nằm trong bản sao lưu như mọi app. Do Apple và
  người dùng quản lý, Xu không đọc được.

## Câu trả lời App Privacy (App Store Connect) — bản nháp

Cần kiểm tra lại định nghĩa "thu thập" (collect) trong trang App Privacy Details của Apple ngay trước khi điền.
Theo cách hiểu hiện tại, dữ liệu chỉ xử lý trên máy và không được gửi cho nhà phát triển hay bên thứ ba thì không tính là thu thập.

- **Do you or your third-party partners collect data from this app?** → **No, we do not collect data from this app**
  ("Data Not Collected").
- **Tracking:** không. Không dùng IDFA, không cần App Tracking Transparency.
- **Privacy Policy URL:** bắt buộc với mọi app. Cần đăng `docs/privacy-policy.md` ở một địa chỉ công khai
  (ví dụ GitHub Pages hoặc trang riêng) — **chưa có, cần quyết định chỗ đăng**. Đăng xong thì thêm nút mở link trong
  Cài đặt › Quyền riêng tư (hiện màn này đã có bản tóm tắt đọc offline).

Khi nào phải sửa câu trả lời: thêm đồng bộ iCloud/CloudKit (v1.1), thêm báo lỗi hay phân tích, thêm "gửi câu nhập sai",
thêm OCR chạy ngoài máy (hiện chỉ dự tính Vision trên máy). Mỗi mục đều phải ghi quyết định vào đây trước.

## Privacy manifest (`App/Privacy/PrivacyInfo.xcprivacy`)

Một tệp, đóng vào cả app lẫn widget (`project.yml`, `buildPhase: resources`). CI kiểm tra tệp có trong
`Xu.app` và `XuWidgets.appex` và đọc được (`plutil -lint`).

| Khoá | Giá trị | Lý do |
|---|---|---|
| `NSPrivacyTracking` | `false` | Không theo dõi |
| `NSPrivacyTrackingDomains` | rỗng | Không gọi domain nào |
| `NSPrivacyCollectedDataTypes` | rỗng | Không thu thập |
| `NSPrivacyAccessedAPITypes` | UserDefaults: `CA92.1`, `1C8F.1` | Cài đặt riêng của app (`UserDefaults.standard`) và App Group dùng chung app ↔ widget |

Các API cần khai lý do khác (dấu thời gian tệp, thời gian khởi động, dung lượng ổ, bàn phím đang bật): Xu hiện không
gọi trực tiếp. Thêm code dùng chúng thì phải khai thêm. Danh sách API và mã lý do theo tài liệu
"Describing use of required reason API" của Apple — cần kiểm tra bản mới nhất trước khi nộp.

## Chính sách quyền riêng tư

- Bản đầy đủ (vi/en/ja) để đăng công khai: `docs/privacy-policy.md`.
- Bản tóm tắt trong app: Cài đặt › Quyền riêng tư (`PrivacyView`, chuỗi `privacy*` trong `XuCore/Localization.swift`),
  đọc được không cần mạng. Sửa nội dung thì sửa cả hai nơi và đổi ngày cập nhật.
- Hướng dẫn của Apple yêu cầu có link chính sách cả trong metadata App Store Connect lẫn trong app (Guideline 5.1.1) —
  cần kiểm tra bản mới nhất; bản tóm tắt offline có đủ thay link hay không cũng cần kiểm tra.

## Cần kiểm tra trước khi nộp

- [ ] Định nghĩa "Data Not Collected" và các loại dữ liệu trong App Privacy Details (Apple) — văn bản mới nhất.
- [ ] Mã lý do API trong privacy manifest — văn bản mới nhất.
- [ ] Chỗ đăng chính sách (URL công khai) và email liên hệ — điền vào `docs/privacy-policy.md`.
- [ ] Việt Nam: quy định về bảo vệ dữ liệu cá nhân (Nghị định 13/2023/NĐ-CP và văn bản mới hơn nếu có) — cần kiểm tra
  văn bản mới nhất; Xu không thu thập nên nghĩa vụ có thể ít, nhưng không tự kết luận.
- [ ] Nhật: Luật Bảo vệ thông tin cá nhân (個人情報の保護に関する法律) — cần kiểm tra văn bản mới nhất.
- [ ] Thử tay trên máy thật: hộp xin dùng Face ID (`NSFaceIDUsageDescription`, `App/Xu/InfoPlist.xcstrings`) hiện đúng ngôn ngữ máy.
- [ ] Thử tay trên máy thật: Cài đặt › Quyền riêng tư hiện đủ 3 thứ tiếng; Xcode › Generate Privacy Report từ bản Archive.
