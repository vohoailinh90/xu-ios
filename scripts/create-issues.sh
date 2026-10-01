#!/usr/bin/env bash
# Tạo label, milestone M0–M4 và issue MVP trên GitHub (theo docs/06-lo-trinh.md).
# Yêu cầu: GitHub CLI đã đăng nhập (`gh auth login`), chạy trong thư mục repo.
# Chạy lại an toàn: label/milestone đã có sẽ được bỏ qua (issue thì sẽ bị tạo trùng — chỉ chạy 1 lần).
set -euo pipefail

echo "→ Tạo label"
while IFS='|' read -r name color desc; do
  gh label create "$name" --color "$color" --description "$desc" --force >/dev/null
done <<'LABELS'
setup|5319e7|Cấu hình dự án, CI, signing
research|fbca04|Khảo sát người dùng, thử nghiệm kỹ thuật
parser|0e8a16|Bộ phân tích câu nhập
core|1d76db|XuCore: logic thuần
app|c2e0c6|Giao diện app SwiftUI
widget|bfdadc|Widget màn hình chính / khóa
intent|d4c5f9|App Intents, Shortcuts, Action Button
release|b60205|TestFlight, App Store
LABELS

echo "→ Tạo milestone"
while IFS='|' read -r title desc; do
  gh api "repos/{owner}/{repo}/milestones" -f title="$title" -f description="$desc" >/dev/null 2>&1 \
    || echo "  (bỏ qua, đã có) $title"
done <<'MILESTONES'
M0 Nền móng|Tuần 1: repo, build, CI, khảo sát
M1 Ghi chép lõi|Tuần 2–3: parser + thanh nhập nhanh
M2 Kênh nhập nhanh|Tuần 4: widget, Shortcuts, Apple Pay
M3 Thói quen|Tuần 5: thói quen, còn được tiêu, chốt ngày
M4 TestFlight|Tuần 6: onboarding, paywall, beta
MILESTONES

echo "→ Tạo issue"
while IFS='|' read -r milestone label title; do
  [ -z "$title" ] && continue
  gh issue create --title "$title" --label "$label" --milestone "$milestone" \
    --body "Xem \`docs/06-lo-trinh.md\` và \`docs/02-tinh-nang-mvp.md\` để biết tiêu chí chấp nhận." >/dev/null
  echo "  ✓ $title"
done <<'ISSUES'
M0 Nền móng|setup|Tạo repo, chạy xcodegen, build app rỗng lên máy thật
M0 Nền móng|setup|Cấu hình App Group, bundle ID, signing cho app + widget
M0 Nền móng|setup|Bật CI GitHub Actions chạy swift test cho XuCore
M0 Nền móng|research|Đọc 100 review 1–3 sao của Money Lover, MISA, Spendee; ghi lại 20 phàn nàn phổ biến
M0 Nền móng|research|Thu thập 200 câu nhập thật từ bạn bè → test case cho parser
M1 Ghi chép lõi|parser|Hoàn thiện parser số tiền + ngày, đạt 100% test hiện có
M1 Ghi chép lõi|parser|Bổ sung test từ 200 câu thật thu thập ở M0
M1 Ghi chép lõi|core|Mở rộng từ khóa danh mục mặc định, kiểm tra trùng nghĩa khi bỏ dấu
M1 Ghi chép lõi|app|QuickEntryBar: tự focus, xem trước, Enter lưu, giữ focus sau khi lưu
M1 Ghi chép lõi|app|Thẻ xem trước: đổi danh mục bằng 1 chạm (lưới emoji)
M1 Ghi chép lõi|app|Học từ khóa khi người dùng sửa danh mục (LearnedKeyword)
M1 Ghi chép lõi|app|Toast "Đã ghi · Hoàn tác"
M1 Ghi chép lõi|app|Danh sách giao dịch theo ngày, sửa/xóa
M1 Ghi chép lõi|app|Xuất CSV qua ShareLink
M2 Kênh nhập nhanh|widget|Widget màn hình chính với nút khoản quen tương tác (LogChipIntent)
M2 Kênh nhập nhanh|widget|Widget màn hình khóa: "hôm nay đã tiêu", chạm mở ô nhập
M2 Kênh nhập nhanh|app|Quản lý khoản quen: tự đề xuất từ khoản lặp lại, ghim, sắp xếp
M2 Kênh nhập nhanh|intent|App Shortcut "Ghi chi tiêu" + hướng dẫn gán vào Action Button
M2 Kênh nhập nhanh|intent|LogPaymentIntent cho automation Apple Pay + màn hình hướng dẫn
M3 Thói quen|core|HabitEngine: tự đánh giá thói quen mẫu theo giao dịch + chốt ngày
M3 Thói quen|app|Thẻ "Hôm nay còn được tiêu" trên Home
M3 Thói quen|app|Màn hình thói quen: vòng sức mạnh, chuỗi mềm, đánh dấu thủ công, ngày nghỉ
M3 Thói quen|app|Thông báo "Chốt ngày" với nút hành động
M3 Thói quen|app|Tổng kết tuần (Chủ nhật)
M4 TestFlight|app|Onboarding 3 màn
M4 TestFlight|app|Paywall + StoreKit 2 (Xu Pro, mua một lần), khôi phục giao dịch
M4 TestFlight|app|Chính sách quyền riêng tư, khai báo App Privacy
M4 TestFlight|research|Spike: OCR ảnh chuyển khoản bằng Vision với 5 ngân hàng phổ biến
M4 TestFlight|release|Đo thời gian ghi trung vị, sửa chỗ chậm
M4 TestFlight|release|TestFlight cho 20–50 người dùng thử + form phản hồi
ISSUES

echo "Xong."
