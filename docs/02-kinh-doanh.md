# 02 — Kinh doanh

## Mô hình

- **Free:** ghi không giới hạn, không quảng cáo. **Không bao giờ khoá việc ghi và xuất dữ liệu.**
- **Xu Pro, mua một lần:** ~99.000–199.000đ ở Việt Nam, 7,99–9,99 USD quốc tế (theo bảng giá App Store).
  Bán tốc độ và niềm vui: 8 nút widget, thói quen không giới hạn, lịch sử đầy đủ, OCR, Apple Pay automation, danh mục/icon/giao diện.
- Kênh thu tiền duy nhất: App Store IAP (StoreKit 2). Không thu tiền ngoài App Store.
- Paywall không bao giờ hiện lúc đang ghi; hiện khi chạm tính năng Pro và sau 7 ngày dùng liên tục.

## Đối thủ

Money Lover, MISA MoneyKeeper (phổ biến ở VN, nhập kiểu biểu mẫu) · Copilot, YNAB, Monarch (xoay quanh ngân hàng Mỹ, ~100 USD/năm) ·
Streaks, Finch (app thói quen — Xu muốn đem giọng điệu của Finch sang chuyện tiền) ·
Monity, SUO, SSMoney, NoteMoney, Monew (manh mối 2026-09-25, chưa xác minh).

Thị trường app chi tiêu **rất đông**. Lợi thế của Xu phải đến từ tốc độ + tiếng Việt + cảm xúc, không từ "có thêm tính năng".

## Rủi ro

- Chưa có bằng chứng người dùng bỏ app vì "ghi mệt" (giả thuyết).
- Free quá hào phóng + mua một lần → tỷ lệ mua Pro và doanh thu dài hạn có thể thấp.
- Dữ liệu tài chính cá nhân: App Privacy; **cần kiểm tra văn bản mới nhất** về bảo vệ dữ liệu cá nhân. Không phải tư vấn pháp lý.

## Kill criteria

- TestFlight 30–50 người: D30 < 15% **hoặc** thời gian ghi trung vị > 5 giây sau 2 vòng sửa → xoay hướng.
- Sau ra mắt 60 ngày: Free → Pro < 1% → xem lại gói Pro.
