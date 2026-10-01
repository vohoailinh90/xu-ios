# 01 — Tầm nhìn sản phẩm

## Một câu định vị

**Xu là cách nhanh nhất để ghi chi tiêu trên iPhone — gõ một câu, xong trong 2 giây, không cần ngân hàng, không cảm giác tội lỗi.**

## Vấn đề

Người dùng không bỏ app quản lý chi tiêu vì lười. Họ bỏ vì app được thiết kế sai:

| Nguyên nhân bỏ app | Cách Xu xử lý |
|---|---|
| Nhập tay quá phiền (mở app → chọn danh mục → nhập số → chọn ngày → lưu, 10–40 giây mỗi khoản) | Gõ một câu tự nhiên; widget bấm 1 chạm; mở app là bàn phím đã bật sẵn |
| Liên kết ngân hàng hay hỏng, ở Việt Nam chỉ hỗ trợ một số ngân hàng | Không phụ thuộc ngân hàng. Tận dụng thứ người Việt đã có: ảnh chụp chuyển khoản, Apple Pay |
| Màn hình đỏ, vượt ngân sách → xấu hổ → né mở app | Chỉ hiện "hôm nay còn được tiêu bao nhiêu", không có màu đỏ, lời nhắn nhẹ nhàng |
| Ghi xong không có phần thưởng, không có lý do quay lại | Thói quen tài chính: chuỗi "không tiêu vặt", điểm sức mạnh thói quen, nghi thức "chốt ngày" |
| Thuê bao đắt, đổi giá, app đóng cửa là mất dữ liệu | Mua một lần; dữ liệu trên máy và iCloud của người dùng; xuất CSV bất cứ lúc nào |

## Khoảng trống thị trường

- **Money Lover, MISA MoneyKeeper**: phổ biến ở Việt Nam, nhiều tính năng, nhưng luồng nhập kiểu biểu mẫu truyền thống, thiết kế chưa theo kịp chuẩn iOS hiện đại (widget tương tác, Shortcuts, Apple Watch).
- **Copilot, YNAB, Monarch**: thiết kế đẹp hoặc phương pháp mạnh, nhưng xoay quanh ngân hàng Mỹ, giá ~100 USD/năm.
- **Streaks, Finch** (thói quen): Streaks thắng nhờ mua một lần và nhanh; Finch thắng nhờ giọng điệu không trừng phạt. **Chưa có app nào đem triết lý của Finch sang chuyện tiền bạc.**

Xu đứng ở giao điểm: **tốc độ của Streaks + sự nhẹ nhàng của Finch + hiểu tiếng Việt và thói quen thanh toán của người Việt.**

## Chân dung người dùng

### A. Minh, 24 tuổi, mới đi làm (người dùng chính)
- Lương 10–15 triệu, tiêu nhiều khoản nhỏ: cà phê, trà sữa, Grab, Shopee.
- Đã cài Money Lover hai lần, bỏ sau 2 tuần vì "ghi mệt quá".
- Muốn biết cuối tháng tiền đi đâu, muốn để dành được một ít.
- Thành công với Xu = vẫn ghi chép sau 30 ngày, tháng thứ 2 có ít ngày tiêu vặt hơn.

### B. Chị Lan, 32 tuổi, dân văn phòng bận rộn
- Thanh toán chủ yếu bằng chuyển khoản QR và thẻ.
- Không có thời gian ngồi nhập. Chỉ cần tổng quan theo tuần.
- Thành công với Xu = ghi được bằng widget và ảnh chụp chuyển khoản, xem tổng kết tuần mỗi Chủ nhật.

### C. Người Việt ở nước ngoài (giai đoạn sau, v1.2 — phần Nhật làm sớm từ 2026-10-01)
- Du học sinh, thực tập sinh, người lao động ở Nhật, Hàn, Đài Loan, Úc.
- Thu nhập bằng ngoại tệ, gửi tiền về nhà định kỳ.
- Cần: nhiều loại tiền, mục tiêu gửi về nhà, danh mục đặc thù (tiền nhà, bảo hiểm, phí chuyển tiền).
- Đã làm sớm cho Nhật: tiền yên, câu nhập tiếng Nhật ("コーヒー 350円", "lương 25 man"), giao diện Việt/Anh/Nhật — xem `08-thi-truong-nhat-va-ngon-ngu.md`.
  Hàn, Đài Loan, Úc và mục tiêu gửi về nhà vẫn để v1.2.

## Không làm (ít nhất trong năm đầu)

- Không liên kết ngân hàng trực tiếp.
- Không làm mạng xã hội, không bảng xếp hạng công khai.
- Không đầu tư, chứng khoán, crypto.
- Không làm Android trước khi iOS đạt tỷ lệ giữ chân mục tiêu.

## Chỉ số thành công (North Star)

**Số ngày có ghi chép trên mỗi người dùng hoạt động trong 30 ngày đầu.**

Chỉ số phụ:
- Thời gian trung vị để ghi một khoản: < 3 giây (đo từ lúc focus ô nhập đến lúc lưu).
- Tỷ lệ còn dùng sau 30 ngày (D30): mục tiêu > 25%.
- Tỷ lệ khoản chi được nhận đúng danh mục tự động: > 80%.
- Tỷ lệ chuyển đổi Free → Pro: 3–5%.
