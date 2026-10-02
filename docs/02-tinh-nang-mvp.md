# 02 — Tính năng MVP

Ưu tiên theo MoSCoW: **Must** (bắt buộc cho bản 1.0), **Should** (nên có), **Could** (nếu còn thời gian), **Later** (sau 1.0).

## Bản đồ các "kênh nhập" — trái tim của app

Xếp theo tốc độ, từ nhanh nhất:

| Kênh | Thao tác | Thời gian | Ưu tiên |
|---|---|---|---|
| Nút khoản quen trên widget màn hình chính | 1 chạm vào "☕ 35k" | ~1 giây | Must |
| Mở app → bàn phím đã bật sẵn → gõ câu → Enter | Gõ "pho 45" | ~2–3 giây | Must |
| Action Button / widget màn hình khóa → mở app | Bấm nút + gõ | ~3 giây | Must (miễn phí vì chỉ là mở app) |
| Shortcuts / Siri: "Ghi chi tiêu với Xu" | Nói hoặc gõ vào hộp thoại | ~4 giây | Must |
| Giọng nói trong app (đọc chính tả tiếng Việt của bàn phím) | Bấm mic, nói "cà phê ba mươi lăm nghìn" | ~3 giây | Should (cần parser hiểu số bằng chữ) |
| Tự động từ Apple Pay (Shortcuts automation "Giao dịch") | Không thao tác | 0 giây | Should |
| Chia sẻ / chọn ảnh chụp màn hình chuyển khoản | Share → Xu | ~3 giây | Should (v1.1 nếu trễ) |
| Apple Watch | Chạm khoản quen | ~2 giây | Later |

## Danh sách tính năng

### Ghi chép
| # | Tính năng | Ưu tiên |
|---|---|---|
| E1 | Ô nhập một dòng, tự focus khi mở app, xem trước kết quả phân tích ngay khi gõ | Must |
| E2 | Parser tiếng Việt: số tiền (35k, 1tr2, 1,5 triệu, 35.000đ), ngày (hôm qua, thứ 2, 12/9), thu nhập (+, lương) | Must |
| E3 | Tự nhận danh mục theo từ khóa; sửa danh mục bằng 1 chạm trên thẻ xem trước | Must |
| E4 | Học từ lần sửa của người dùng (lần sau gõ "bánh tráng" sẽ ra đúng danh mục đã sửa) | Must |
| E5 | Hoàn tác ngay sau khi lưu (toast "Đã ghi · Hoàn tác") | Must |
| E6 | Sửa / xóa giao dịch trong danh sách | Must |
| E7 | Khoản quen (Quick Chips): tự đề xuất từ các khoản lặp lại, ghim tối đa 8 | Must |
| E8 | Câu có nhiều số tiền ("ăn trưa 45k tip 5k") → gợi ý tách thành 2 khoản | Should |
| E9 | Số bằng chữ từ giọng nói ("ba mươi lăm nghìn") | Should |
| E10 | OCR ảnh chuyển khoản ngân hàng | Should / v1.1 |
| E11 | Apple Pay automation qua Shortcuts | Should |

### Tổng quan
| # | Tính năng | Ưu tiên |
|---|---|---|
| O1 | Thẻ "Hôm nay còn được tiêu" (từ ngân sách linh hoạt tháng) | Must |
| O2 | Danh sách giao dịch theo ngày | Must |
| O3 | Tổng kết tuần (Chủ nhật): tiêu bao nhiêu, danh mục lớn nhất, số ngày không tiêu vặt | Should |
| O4 | Biểu đồ theo danh mục theo tháng (Swift Charts) | Should |
| O5 | Xuất CSV | Must (xây dựng niềm tin: "dữ liệu là của bạn") |

### Thói quen tài chính (chi tiết ở `05-thoi-quen-tai-chinh.md`)
| # | Tính năng | Ưu tiên |
|---|---|---|
| H1 | Nghi thức "Chốt ngày" buổi tối: 1 chạm xác nhận đã ghi đủ | Must |
| H2 | Thói quen mẫu: Ghi chép mỗi ngày, Ngày không tiêu vặt, Không trà sữa, Nấu ăn ở nhà | Must |
| H3 | Điểm sức mạnh thói quen (không reset về 0) + chuỗi mềm có "ngày nghỉ" | Must |
| H4 | Thử thách tiết kiệm (52 tuần, 30 ngày không mua sắm online) | Could |

### Widget & tích hợp hệ thống
| # | Tính năng | Ưu tiên |
|---|---|---|
| W1 | Widget màn hình chính (nhỏ, vừa) với nút khoản quen tương tác | Must |
| W2 | Widget màn hình khóa: "hôm nay đã tiêu", chạm để mở app | Must |
| W3 | App Shortcut "Ghi chi tiêu" | Must |
| W4 | Control Center control (iOS 18) | Could |
| W5 | Live Activity khi đang thử thách | Later |

### Hệ thống
| # | Tính năng | Ưu tiên |
|---|---|---|
| S1 | Onboarding 3 màn: gõ thử 1 câu → đặt ngân sách linh hoạt → chọn 1 thói quen | Must |
| S2 | Nhắc nhở buổi tối (giờ tùy chọn) | Must |
| S3 | Đồng bộ iCloud (SwiftData + CloudKit) | Should / v1.1 |
| S4 | Khóa bằng Face ID | Should |
| S5 | Paywall + StoreKit 2 (mua một lần) | Must |

## User story và tiêu chí chấp nhận (các story quan trọng nhất)

### US-1: Ghi nhanh bằng một câu
> Là Minh, tôi muốn gõ "cà phê 35k" và nhấn Enter để khoản chi được lưu ngay, vì tôi không muốn chọn qua nhiều màn hình.

- Mở app từ trạng thái đóng → con trỏ đã nằm trong ô nhập, bàn phím đã hiện.
- Khi gõ, thẻ xem trước hiện: số tiền đã định dạng, danh mục (emoji + tên), ngày.
- Enter khi chưa có số tiền → không lưu, thẻ xem trước nhắc "Thêm số tiền, ví dụ 35k".
- Sau khi lưu: rung nhẹ, ô nhập được xóa và **vẫn giữ focus** để ghi khoản tiếp theo.
- Hiện toast "Đã ghi · Hoàn tác" trong 4 giây.

### US-2: Sửa danh mục và app học theo
> Là Minh, khi app đoán sai danh mục, tôi muốn sửa bằng một chạm và lần sau app đoán đúng.

- Chạm vào chip danh mục trên thẻ xem trước → bảng chọn danh mục dạng lưới emoji.
- Sau khi sửa, cụm từ ghi chú (đã bỏ dấu) được lưu thành từ khóa riêng của người dùng, được ưu tiên hơn từ khóa mặc định.

### US-3: Widget khoản quen
> Là chị Lan, tôi muốn chạm "☕ 35k" trên màn hình chính để ghi mà không cần mở app.

- Chạm nút → giao dịch được lưu, widget cập nhật "Hôm nay: 35k" trong vòng vài giây.
- Không mở app.

### US-4: Chốt ngày
> Là Minh, buổi tối tôi nhận nhắc nhở, chạm "Đã ghi đủ" để giữ thói quen, kể cả hôm đó tôi không tiêu gì.

- Thông báo có nút hành động "Đã ghi đủ" và "Ghi thêm".
- "Đã ghi đủ" đánh dấu ngày đã chốt, cập nhật thói quen "Ghi chép mỗi ngày" và cho phép tính "Ngày không tiêu vặt".

## Free vs Pro

| | Free | Pro (mua một lần) |
|---|---|---|
| Ghi chép không giới hạn, parser, học danh mục | ✅ | ✅ |
| Thẻ "còn được tiêu", danh sách, xuất CSV | ✅ | ✅ |
| Khoản quen trên widget | 2 nút | 8 nút |
| Thói quen | 2 | Không giới hạn + thử thách |
| Tổng kết tuần, biểu đồ | Tuần hiện tại; biểu đồ tháng: tháng hiện tại | Toàn bộ lịch sử (biểu đồ tháng: các tháng trước — đã làm; tuần cũ: chưa) |
| OCR chuyển khoản, Apple Pay automation | — | ✅ |
| Danh mục tùy chỉnh, Face ID, icon app, giao diện | — | ✅ |

Nguyên tắc: **không bao giờ khóa việc ghi chép và xuất dữ liệu.** Pro bán tốc độ và niềm vui, không bán quyền truy cập vào dữ liệu của chính người dùng.
