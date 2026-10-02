# 07 — Kinh doanh, ASO và ra mắt

## Giá

| Gói | Giá gợi ý | Ghi chú |
|---|---|---|
| Free | 0 | Ghi chép không giới hạn, không quảng cáo |
| Xu Pro (mua một lần) | Việt Nam: khoảng 99.000–199.000đ · Quốc tế: 7,99–9,99 USD | Chọn mức gần nhất trong bảng giá App Store; dùng giá theo từng quốc gia |
| (Tùy chọn, sau) Xu Pro+ theo năm | Thấp, ví dụ 5–10 USD/năm | Chỉ cho tính năng tốn chi phí vận hành thật (AI trên cloud, sao lưu nâng cao) |

Lý do mua một lần: người dùng đang mệt mỏi với thuê bao, và đây là thông điệp marketing khác biệt so với YNAB/Copilot. Doanh thu một lần thấp hơn về lâu dài — bù lại bằng tỷ lệ chuyển đổi cao hơn và lan truyền tốt hơn. Có thể đánh giá lại sau 6 tháng dựa trên số liệu.

**Thời điểm hiện paywall:** không bao giờ lúc đang ghi. Hiện khi người dùng chạm vào tính năng Pro, và một lần sau ngày thứ 7 dùng liên tục ("Bạn đã ghi chép 7 ngày liền 🎉 — mở khóa Pro để…").
Cách làm (`ProInvite` trong XuCore): "dùng" = có ghi ít nhất một khoản hoặc đã chốt ngày, như thói quen "Ghi chép mỗi ngày".
Thẻ mời (không phải paywall) hiện trên Home vào ngày sau 7 ngày liền, chỉ xét các ngày trước hôm nay để không bật ra giữa
lúc đang ghi; ở lại hết ngày đó rồi thôi, "Để sau" là tắt hẳn. Người đã mua Pro không thấy.

## Đặt tên

Tiêu chí: ngắn, gõ được không dấu, không trùng app lớn, có ý nghĩa với người Việt, còn trống trên App Store (kiểm tra trước khi quyết).

Ứng viên: **Xu** · Sổ Xu · Ví Nhẹ · Tiêu Gì · Chi Nhanh · 2 Giây

Tên hiển thị trên App Store nên kèm từ khóa: *"Xu – Ghi chi tiêu 2 giây"* (tối đa 30 ký tự).

## ASO (tối ưu App Store)

Tên, phụ đề, từ khoá, mô tả đủ 3 thứ tiếng (vi/en/ja): xem `docs/10-app-store.md`. (Dãy từ khoá tiếng Việt cũ ở đây
dài 103 ký tự, quá giới hạn 100, và lặp "chi tiêu" đã có trong tên — đã thay ở `docs/10`.)

**Ảnh chụp màn hình** — mỗi ảnh một thông điệp, chữ lớn:
1. "Gõ 'cà phê 35k'. Xong." (cảnh ô nhập + thẻ xem trước)
2. "Chạm 1 lần trên màn hình chính" (widget khoản quen)
3. "Biết hôm nay còn được tiêu bao nhiêu" (thẻ còn được tiêu)
4. "Xây thói quen, không cảm giác tội lỗi" (vòng sức mạnh thói quen)
5. "Không cần liên kết ngân hàng. Dữ liệu là của bạn." (offline, CSV)

**Video preview 15–30 giây**: quay màn hình thật, ghi 5 khoản trong 10 giây.

## Kênh ra mắt

| Kênh | Cách làm |
|---|---|
| TikTok / Reels | Video "thử ghi chi tiêu nhanh nhất" so với cách truyền thống; series "một tháng ghi chép cùng Xu" |
| Nhóm Facebook tài chính cá nhân, tiết kiệm, sinh viên | Chia sẻ câu chuyện làm app một mình, xin người thử TestFlight — không spam quảng cáo |
| Threads / X (cộng đồng indie dev) | Build in public: đăng tiến độ hàng tuần, số liệu thật |
| Product Hunt, Reddit (r/iosapps, r/personalfinance) | Khi có bản tiếng Anh |
| Apple | Dùng tốt widget tương tác, App Intents, Dynamic Type, VoiceOver → tăng cơ hội được giới thiệu. Gửi đề cử qua form "Promote your app" của Apple Developer |

## Chỉ số đo lường

| Chỉ số | Mục tiêu 3 tháng đầu |
|---|---|
| Thời gian ghi trung vị | < 3 giây |
| D1 / D7 / D30 retention | 50% / 35% / 25% |
| Số ngày ghi chép / người dùng / 30 ngày | > 15 |
| Tỷ lệ đoán đúng danh mục | > 80% |
| Chuyển đổi Free → Pro | 3–5% |
| Đánh giá App Store | ≥ 4,7 (hỏi đánh giá bằng `requestReview` sau lần chốt ngày thứ 5) |

## Rủi ro

| Rủi ro | Giảm thiểu |
|---|---|
| Money Lover / MISA thêm nhập nhanh | Tốc độ ra tính năng của indie + trải nghiệm iOS thuần + thói quen là lõi |
| Người dùng vẫn bỏ sau 30 ngày | Theo dõi D30 từ TestFlight; thử nghiệm nhắc nhở, tổng kết tuần, thử thách |
| Parser đoán sai nhiều câu thật | Thu thập câu thật từ M0, test hóa, cho người dùng gửi câu sai |
| Doanh thu thấp do chỉ mua một lần | Bản địa hóa quốc tế sớm (tiếng Anh), cân nhắc gói năm cho tính năng AI |
