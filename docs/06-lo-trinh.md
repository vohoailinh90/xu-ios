# 06 — Lộ trình

Mục tiêu: **TestFlight sau 6 tuần** (một người, làm bán thời gian ~15–20 giờ/tuần). `scripts/create-issues.sh` tạo sẵn các issue dưới đây trên GitHub.

## M0 — Nền móng (tuần 1)
- [ ] #setup Tạo repo, chạy `xcodegen`, build app rỗng lên máy thật
- [ ] #setup Cấu hình App Group, bundle ID, signing cho app + widget
- [ ] #setup Bật CI GitHub Actions chạy `swift test` cho XuCore
- [ ] #research Đọc 100 review 1–3 sao của Money Lover, MISA, Spendee; ghi lại 20 câu người dùng hay phàn nàn
- [ ] #research Thu thập 200 câu nhập thật (nhờ bạn bè gõ thử) → biến thành test case cho parser

## M1 — Ghi chép lõi (tuần 2–3)
- [ ] #parser Hoàn thiện parser số tiền + ngày, đạt 100% test hiện có
- [ ] #parser Bổ sung test từ 200 câu thật thu thập ở M0
- [ ] #core Mở rộng từ khóa danh mục mặc định, kiểm tra trùng nghĩa khi bỏ dấu
- [ ] #app QuickEntryBar: tự focus, xem trước, Enter lưu, giữ focus sau khi lưu
- [ ] #app Thẻ xem trước: sửa danh mục bằng 1 chạm (lưới emoji)
- [ ] #app Học từ khóa khi người dùng sửa danh mục (LearnedKeyword)
- [ ] #app Toast "Đã ghi · Hoàn tác"
- [ ] #app Danh sách giao dịch theo ngày, sửa/xóa
- [ ] #app Xuất CSV qua ShareLink

## M2 — Kênh nhập nhanh (tuần 4)
- [ ] #widget Widget màn hình chính với nút khoản quen tương tác (LogChipIntent)
- [ ] #widget Widget màn hình khóa: "hôm nay đã tiêu", chạm mở app
- [ ] #app Quản lý khoản quen: tự đề xuất từ khoản lặp lại, ghim/bỏ ghim, sắp xếp
- [ ] #intent App Shortcut "Ghi chi tiêu" + hướng dẫn gán vào Action Button
- [ ] #intent Intent nhận số tiền + tên cửa hàng cho automation Apple Pay; màn hình hướng dẫn cài đặt

## M3 — Thói quen & còn được tiêu (tuần 5)
- [ ] #core HabitEngine: tự đánh giá thói quen mẫu theo giao dịch + chốt ngày
- [ ] #app Thẻ "Hôm nay còn được tiêu" trên Home
- [ ] #app Màn hình thói quen: vòng sức mạnh, chuỗi mềm, đánh dấu thủ công, ngày nghỉ
- [ ] #app Thông báo "Chốt ngày" với nút hành động
- [ ] #app Tổng kết tuần (Chủ nhật)

## M4 — Hoàn thiện & TestFlight (tuần 6)
- [ ] #app Onboarding 3 màn
- [ ] #app Paywall + StoreKit 2 (Xu Pro, mua một lần), khôi phục giao dịch
- [ ] #app Chính sách quyền riêng tư, App Privacy trên App Store Connect
- [ ] #research Spike: OCR ảnh chuyển khoản bằng Vision — kiểm tra hỗ trợ tiếng Việt, độ chính xác với 5 ngân hàng phổ biến
- [ ] #release Đo thời gian ghi trung vị (log cục bộ), sửa chỗ chậm
- [ ] #release TestFlight cho 20–50 người dùng thử, form phản hồi

## v1.1 (sau ra mắt)
- Đồng bộ iCloud · OCR chuyển khoản · Tách nhiều khoản · Số bằng chữ (giọng nói) · Face ID · Danh mục tùy chỉnh · Biểu đồ tháng · Control Center control

## v1.2
- Đa tiền tệ cho người Việt ở nước ngoài · Mục tiêu gửi tiền về nhà · Apple Watch · Thử thách + Live Activity

## Quy trình làm việc đề xuất

- Nhánh `main` luôn build được. Mỗi issue một nhánh `feature/<số-issue>-<mô-tả>`.
- PR nhỏ, có ảnh chụp màn hình nếu đổi UI, có test nếu đổi XuCore.
- Cuối mỗi milestone: ghi lại thời gian ghi trung vị và 3 điều học được vào `docs/nhat-ky.md`.
