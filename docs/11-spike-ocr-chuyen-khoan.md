# 11 — Spike: đọc ảnh chuyển khoản bằng Vision (OCR trên máy)

> Cập nhật 2026-10-03. Trạng thái: **làm dở**. Phần máy móc đã chạy (Vision có tiếng Việt, đọc tốt trên ảnh dựng sẵn); phần quyết
> định (có làm tính năng hay không) cần **ảnh thật** của chủ dự án và chưa có. Đừng đọc các con số dưới đây như độ chính xác với ngân hàng nào.
> Mục `#research` ở `docs/06` còn mở cho tới khi có kết quả trên ảnh thật.

## Câu hỏi và tiêu chí

| Câu hỏi | Trả lời hiện tại |
|---|---|
| Vision có đọc tiếng Việt không? | Có trên macOS 15 (ảnh dựng sẵn). **Chưa kiểm trên iPhone iOS 17/18** |
| Số tiền đúng bao nhiêu % trên biên lai thật của 5 ngân hàng? | **Chưa biết** — cần ≥ 50 ảnh thật |
| Đủ nhanh và giữ được nguyên tắc (riêng tư, một chạm lưu)? | Thiết kế bên dưới; tốc độ trên máy thật chưa đo |

Tiêu chí quyết định lấy từ file tính năng
[ocr-anh-chuyen-khoan](https://github.com/vohoailinh90/App-idea-lab/blob/main/products/xu/features/ocr-anh-chuyen-khoan.md)
ở App-idea-lab (luật 8: ý tưởng và chấm điểm làm ở đó) và trang chấm `prototypes/cham-bien-lai.html`:

- Số tiền đọc đúng **≥ 95%** trên 50 ảnh thật (5 ngân hàng) → đáng làm.
- **< 90%** → hoãn, chuyển sang hướng "dán nội dung thông báo ngân hàng".
- 90–95%: file tính năng không nói; trang chấm chỉ nói xem bảng để biết ngân hàng nào cần xử lý riêng. Coi là "chưa đạt, quyết định lại".

## Thí nghiệm 1 — Vision trên ảnh dựng sẵn (đã chạy, CI macOS)

`scripts/spike-ocr.swift`, workflow `.github/workflows/spike-ocr.yml` (chỉ chạy khi đổi script hoặc bấm tay). Dựng 4 mẫu biên lai **giả**
(chuyển đi, quét QR, nhận tiền, ví; số tiền `-1.356.780 VND`, `52.000đ`, `+2.500.000 VND`, `1.200.000 ₫`), sáng/tối, ở 6 biến thể: sạch 3x, sạch 2x,
JPEG 40%, thu nhỏ 50% + JPEG 50% (như ảnh qua Zalo/Messenger), chữ nhỏ và nhãn nhạt, và chữ nhỏ + thu nhỏ + JPEG. Mỗi biến thể 8 ảnh (4 mẫu × sáng/tối),
chạy `VNRecognizeTextRequest` với 5 cấu hình. Lần chạy: [run 37162110417](https://github.com/vohoailinh90/xu-ios/actions/runs/37162110417)
(macOS 15.7.9, Vision revision 3).

**Ngôn ngữ hỗ trợ** (`supportedRecognitionLanguages`):

- Chế độ chính xác (accurate): `en-US, fr-FR, it-IT, de-DE, es-ES, pt-BR, zh-Hans, zh-Hant, yue-Hans, yue-Hant, ko-KR, ja-JP, ru-RU, uk-UA, th-TH, vi-VT, ar-SA, ars-SA` — **có `vi-VT`, có `ja-JP`**.
- Chế độ nhanh (fast): chỉ `en-US, fr-FR, it-IT, de-DE, es-ES, pt-BR` — **không có tiếng Việt**.

**Độ chính xác** (chế độ accurate; 4 cấu hình accurate cho kết quả gần như giống nhau, chỗ khác ghi riêng; đúng/tổng):

| Biến thể | Số tiền: đúng các chữ số | Số tiền: lấy từ dòng chữ cao nhất | Số tiền: đúng nguyên văn | Tên người nhận/ngân hàng (nguyên văn) | Nội dung | Ghép nhãn–giá trị theo hàng |
|---|---|---|---|---|---|---|
| Sạch 3x, sạch 2x, JPEG 40%, chữ nhỏ nhạt 3x | 8/8 | 8/8 | 6/8 | 10/10 | 8/8 | 36/36 |
| Thu nhỏ 50% + JPEG 50% | 8/8 | 8/8 | 6/8 | 10/10 (9/10 khi tắt sửa lỗi theo ngôn ngữ) | 8/8 | 36/36 (35/36 khi tắt sửa lỗi) |
| Chữ nhỏ nhạt + thu nhỏ 50% + JPEG 50% | 8/8 | 8/8 | 7/8 | 9/10 (đúng khi bỏ dấu: 10/10) | 8/8 | 36/36 |

- Ngày giờ và mã giao dịch đúng 100% ở mọi biến thể (chế độ accurate).
- "Đúng nguyên văn" thấp hơn "đúng chữ số" chỉ vì mẫu ví `1.200.000 ₫`: ký hiệu `₫` không được đọc nguyên văn (chưa xem ảnh thô nên chưa biết nó thành gì). Với app chỉ cần chữ số, đây là chi tiết cần xử lý ở bước trích xuất, không phải lỗi số tiền.
- Chế độ **fast** kém: ngày giờ 0/8, tên 2/10 (bỏ dấu 6–8/10), nội dung 2/8, ghép nhãn–giá trị 7–14/36, số tiền sai chữ số 2/8 ảnh. **Chỉ dùng accurate.**
- Mặc định ngôn ngữ, `en-US` và `vi-VT` không khác biệt đáng kể trên dữ liệu này; bật hay tắt "sửa lỗi theo ngôn ngữ" chỉ khác một chỗ (dòng tên ở ảnh nén mạnh).
- Tốc độ trên máy chủ CI (máy ảo, **không đại diện cho iPhone**): accurate ~0,6–1,5 giây mỗi ảnh, fast ~35–80 ms. Chưa đo trên iPhone.
- Thứ tự dòng Vision trả về **không đáng tin để ghép nhãn với giá trị**: cùng một hàng, nhãn và giá trị là hai ô riêng, và theo trục dọc ô nào đứng trước phụ thuộc chênh lệch cỡ chữ. Ghép theo toạ độ (cùng hàng) cho 35–36/36; thứ tự dòng thì không.

### Điều rút ra được và điều chưa

Rút ra được (với ảnh dựng sẵn): Vision accurate đọc được chữ Việt có dấu và số tiền khi ảnh sạch, bị nén, thu nhỏ hay chữ nhỏ nhạt; số tiền to nhất trên màn hình là
dấu hiệu tốt; phải ghép theo toạ độ; không dùng fast.

**Chưa rút ra được**: độ chính xác trên ảnh thật. Mẫu do tôi dựng, một phông, nền phẳng, không biểu tượng, không mã QR, không nhiều con số cùng cỡ (số tiền, phí, số dư),
không số tài khoản che `****1234`, không ảnh chụp màn hình bị cắt. Đọc tốt ở đây chỉ nói rằng Vision không là điểm nghẽn hiển nhiên; điểm nghẽn có thể là **chọn đúng số**
trong bố cục từng ngân hàng — và đó đúng là thứ chỉ ảnh thật mới trả lời. Cũng chưa có ảnh nào bị chụp lệch, chụp màn hình bằng máy khác, hay có chữ chồng lên ảnh nền.

## Thí nghiệm 2 — ảnh thật (chưa làm, cần chủ dự án)

Dùng `prototypes/cham-bien-lai.html` (đã có: dán chữ OCR, nhập số đúng, xem tỉ lệ theo ngân hàng; ngưỡng 95%/90% có sẵn). Cần: ≥ 50 ảnh biên lai **của chính bạn**,
5 ngân hàng/ví phổ biến (che số tài khoản, tên người nhận nếu chia sẻ màn hình; biên lai là dữ liệu tài chính cá nhân — cần kiểm tra văn bản mới nhất về bảo vệ dữ liệu cá nhân).

Cần **cách lấy chữ OCR từ ảnh thật bằng đúng bộ đọc của Vision**. Trang chấm hướng dẫn dùng phím tắt "Thử biên lai" hoặc Văn bản trực tiếp (Live Text); chưa kiểm hai đường
đó dùng cùng bộ đọc và cùng tham số với `VNRecognizeTextRequest` — **cần kiểm tra**. Đã chọn (2026-10-04): **màn hình thử trong app, chỉ bản Debug** — chạy đúng
`VNRecognizeTextRequest` trên iPhone thật, cho luôn danh sách ngôn ngữ và tốc độ trên iOS 17/18.

### Màn hình thử (bản Debug)

`App/Xu/Features/Settings/ReceiptOCRLabView.swift`, bọc trong `#if DEBUG`: **không có trong bản Release/TestFlight/App Store** (chưa kiểm bằng một bản Release — CI chỉ dựng Debug; nên
kiểm khi làm TestFlight). Cách dùng:

1. Mở bằng Xcode, chạy cấu hình **Debug** (mặc định khi bấm Run) trên iPhone thật; ký bằng Team của bạn. Trình mô phỏng cũng chạy được nhưng không cho số đo tốc độ/ngôn ngữ của máy thật.
2. Cài đặt (nút bánh răng) › kéo xuống cuối › **Thử đọc biên lai**.
3. Mục "Máy này": ghi lại hệ điều hành, thiết bị, và hai dòng **Tiếng Việt / Tiếng Nhật (chính xác)** có hay không — đó là kết quả cho mục kiểm `vi-VT`/`ja-JP` bên dưới. Làm trên cả iOS 17 và 18 nếu có hai máy.
4. **Chọn ảnh biên lai** (tối đa 60 ảnh một lần, của chính bạn). Mỗi ảnh hiện: số tiền đọc được (dòng chữ cao nhất có chữ số), thời gian đọc, và chữ theo hàng (nhãn | giá trị).
5. Chọn **ngân hàng/ví** và gõ **số đúng** (bằng chữ số, ví dụ `1356780`) ở mỗi ảnh: màn hình báo Đúng/Sai và hiện bảng **đúng/tổng theo ngân hàng** cùng tỉ lệ %. Chỉ so các chữ số; `52k`, `1tr2` chưa hiểu. Ảnh không đọc được, hoặc đọc xong mà không có dòng nào có chữ số, tính là **sai** (không bỏ khỏi mẫu số); chọn ngân hàng cho cả ảnh lỗi. Ảnh **trùng byte** với ảnh đã chọn trước (bản sao trong thư viện) được báo và không tính hai lần; hai ảnh chụp lại cùng một biên lai thì app không nhận ra — tự tránh chọn trùng.
   Kết quả **chỉ nằm trong bộ nhớ**, mất khi chọn ảnh khác hoặc rời màn hình: chọn cả 50 ảnh một lần (tối đa 60) và ghi bảng lại vào đây trước khi thoát.
6. Muốn dùng trang chấm `prototypes/cham-bien-lai.html` thay vì bảng trong app: **Sao chép chữ**, rồi dán trên **chính iPhone này** (bảng nhớ đặt `localOnly` — không sang Mac/iPad qua Universal Clipboard — và tự hết hạn sau 2 phút).
7. Thử đổi **Chế độ / Ngôn ngữ / Sửa lỗi theo ngôn ngữ** rồi "Đọc lại" để so cùng một ảnh. Chế độ Nhanh không có tiếng Việt/Nhật: chọn ngôn ngữ đó ở chế độ Nhanh sẽ đọc bằng mặc định và có ghi chú.

Riêng tư (luật 6): không xin quyền thư viện ảnh (bộ chọn ảnh của hệ thống chỉ trao ảnh đã chọn), ảnh chỉ nằm trong bộ nhớ, không lưu, không gửi đi. Chữ đọc được có thể có số tài khoản và tên
người nhận; chữ chỉ vào bảng nhớ khi bạn bấm Sao chép (`localOnly`, hết hạn sau 2 phút).

## Thiết kế dự kiến nếu làm (chưa cam kết)

- **Đường vào**: Share → Xu (Share Extension) và nút "Từ ảnh" trong app dùng bộ chọn ảnh của hệ thống. **Không tự quét thư viện ảnh** ở bản đầu: "gợi ý ảnh chụp mới nhất" cần quyền đọc thư viện (cần kiểm tra quy định App Store/quyền riêng tư và chịu cái giá niềm tin) — để sau, và cần quyết định.
- **Luồng**: ảnh → Vision (`.accurate`, `vi-VT` + `en-US`) trên máy → các dòng kèm toạ độ → trích xuất → **thẻ xem trước** (đúng luồng xem trước rồi lưu hiện có) → một chạm Lưu, không đòi gõ. Mục tiêu theo file tính năng: ~3 giây tới thẻ xem trước rồi ~1 giây để lưu (**chưa đo**).
- **Trích xuất** tách khỏi Vision, là hàm thuần trong `XuCore` (test được bằng `swift test`): số tiền = dòng chữ cao nhất có chữ số, hoặc cạnh nhãn "Số tiền/Amount"; bỏ phí/số dư/hạn mức; nội dung = hàng "Nội dung/Lời nhắn"; ngày giờ; dùng lại `QuickEntryParser` cho phần chữ. Quy tắc dự kiến đang ở `prototypes/cham-bien-lai.html` (`findAmounts`), bản JavaScript — **chưa có bản Swift**, chỉ viết khi có số liệu ảnh thật.
- **Không chắc thì để trống, đừng đoán**: không tìm ra số tiền hoặc có hai số ngang điểm thì ô số tiền để trống cho người dùng gõ, kèm câu giọng "không tội lỗi" (không "đọc thất bại"). Không bao giờ lưu số tiền đoán mà không hiện ra để người dùng thấy.
- **Dữ liệu**: không lưu ảnh. Chỉ lưu những trường cần (số tiền, ngày, nội dung ngắn). **Không lưu toàn bộ chữ OCR** vào `rawInput` (có tên người nhận, số tài khoản). Tên người nhận chỉ dùng làm ghi chú nếu người dùng giữ lại trên thẻ xem trước.
- **Riêng tư**: Vision chạy trên máy, ảnh không rời máy, nên câu trả lời App Privacy "Data Not Collected" (`docs/09`) giữ nguyên miễn là không gửi ảnh/chữ đi đâu (không OCR ngoài máy: `docs/09` đòi ghi quyết định trước). Khi phát hành phải thêm một dòng vào Cài đặt › Quyền riêng tư, `docs/privacy-policy.md` và mô tả App Store — **cần kiểm tra văn bản mới nhất**.
- **Đường lui** (nếu ảnh thật < 90%): "dán nội dung thông báo ngân hàng": người dùng sao chép chữ từ thông báo/tin nhắn rồi dán vào ô nhập; cùng hàm trích xuất. Bố cục chữ thì mỗi ngân hàng một kiểu, nên vẫn cần mẫu riêng.

## Quyết định chờ chủ dự án

1. **Miễn phí hay Pro?** `docs/02` xếp "OCR chuyển khoản" vào Pro, và file tính năng ở App-idea-lab nêu "dùng thử 5 lần miễn phí". Nhưng đây là một **đường ghi**, mà luật 5 nói không khoá việc ghi; cùng lý do bạn đã chọn Apple Pay automation miễn phí (2026-10-03). Đề xuất của tôi: đọc một ảnh miễn phí; Pro bán tiện ích đi kèm (nhiều ảnh một lần, xoá ảnh sau khi ghi, gợi ý ảnh chụp mới nhất nếu về sau làm). Việc này đổi `docs/02` nên cần bạn quyết.
2. **Ai gom 50 ảnh thật** (5 ngân hàng/ví) và chạy màn hình thử ở trên.
3. **Có làm "gợi ý ảnh chụp mới nhất" không** (quyền đọc thư viện ảnh) — đề xuất: không ở bản đầu.

## Việc còn lại để đóng spike

- [x] Màn hình thử trong app (bản Debug) — chờ chạy thử trên iPhone thật.
- [ ] Có số đo trên ≥ 50 ảnh thật / 5 ngân hàng (màn hình thử + trang chấm), ghi bảng theo ngân hàng vào đây.
- [ ] Kiểm `supportedRecognitionLanguages` có `vi-VT` và `ja-JP` trên **iPhone thật iOS 17 và 18** (mục "Máy này" của màn hình thử; kết quả ở trên là macOS 15 trên máy chủ CI).
- [ ] Đo thời gian đọc một ảnh trên iPhone cũ nhất hỗ trợ (CI ~1 giây là máy ảo).
- [ ] Xem chữ thô của biên lai có `₫` (màn hình thử hiện chữ theo hàng) để biết ký hiệu bị đọc thành gì và có cần xử lý ở bước trích xuất.
- [ ] Quyết định 1–3 ở trên; cập nhật điểm và nhật ký của tính năng ở App-idea-lab (luật 8) sau khi có số liệu thật.
