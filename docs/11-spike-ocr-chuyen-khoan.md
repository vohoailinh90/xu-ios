# 11 — Spike: đọc ảnh chuyển khoản bằng Vision (OCR trên máy)

> Cập nhật 2026-10-03. Trạng thái: **làm dở**. Phần máy móc đã chạy (Vision có tiếng Việt, đọc tốt trên ảnh dựng sẵn); phần quyết
> định (có làm tính năng hay không) cần **ảnh thật** của chủ dự án và chưa có. Đừng đọc các con số dưới đây như độ chính xác với ngân hàng nào.
> Mục `#research` ở `docs/06` còn mở cho tới khi có kết quả trên ảnh thật.

## Câu hỏi và tiêu chí

| Câu hỏi | Trả lời hiện tại |
|---|---|
| Vision có đọc tiếng Việt không? | Có trên macOS 15 (ảnh dựng sẵn). **Chưa kiểm trên iPhone iOS 17/18** |
| Số tiền đúng bao nhiêu % trên biên lai thật của 5 ngân hàng? | **Sơ bộ 39/39 (100%)** bằng Văn bản trực tiếp/Phím tắt trên iPhone của chủ dự án, chưa đủ 50 ảnh và chưa chắc cùng bộ đọc với Vision trong app; xem "Kết quả sơ bộ" |
| Đủ nhanh và giữ được nguyên tắc (riêng tư, một chạm lưu)? | Thiết kế bên dưới; tốc độ trên máy thật chưa đo |

Tiêu chí quyết định lấy từ file tính năng
[ocr-anh-chuyen-khoan](https://github.com/vohoailinh90/App-idea-lab/blob/main/products/xu/features/ocr-anh-chuyen-khoan.md)
ở App-idea-lab (luật 8: ý tưởng và chấm điểm làm ở đó) và trang chấm `prototypes/cham-bien-lai.html`:

- Số tiền đọc đúng **≥ 95%** trên 50 ảnh thật (5 ngân hàng) → đáng làm.
- **< 90%** → hoãn, chuyển sang hướng "dán nội dung thông báo ngân hàng".
- Từ 90% đến **dưới** 95%: file tính năng không nói; trang chấm chỉ nói xem bảng để biết ngân hàng nào cần xử lý riêng. Coi là "chưa đạt, quyết định lại".

## Thí nghiệm 1 — Vision trên ảnh dựng sẵn (đã chạy, CI macOS)

`scripts/spike-ocr.swift`, workflow `.github/workflows/spike-ocr.yml` (chỉ chạy khi đổi script hoặc bấm tay). Dựng 4 mẫu biên lai **giả**
(chuyển đi, quét QR, nhận tiền, ví; số tiền `-1.356.780 VND`, `52.000đ`, `+2.500.000 VND`, `1.200.000 ₫`), sáng/tối, ở 6 biến thể: sạch 3x, sạch 2x,
JPEG 40%, thu nhỏ 50% + JPEG 50% (tự dựng bằng cách thu nhỏ rồi nén JPEG; **không phải** ảnh thật đã gửi qua Zalo/Messenger hay ứng dụng nào), chữ nhỏ và nhãn nhạt, và chữ nhỏ + thu nhỏ + JPEG. Mỗi biến thể 8 ảnh (4 mẫu × sáng/tối),
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
- "Đúng nguyên văn" thấp hơn "đúng chữ số" ở mọi biến thể (6/8 hoặc 7/8). Lần chạy đầu in từng ca sai và cả 4 ca trượt của nó đều là mẫu ví `1.200.000 ₫`; lần chạy 6 biến thể không in từng ca, chỉ có số đếm (khớp với việc hai ảnh của mẫu ví trượt). **Chưa biết nguyên nhân**: có thể là ký hiệu `₫`, khoảng trắng trước nó hay dấu phân cách hàng nghìn; chưa có log từng ca sai ở mức ký tự. Chữ số đều đúng, nên với app chỉ cần chữ số thì chưa phải lỗi số tiền, nhưng chưa nên kết luận cách xử lý ở bước trích xuất trước khi xem chữ thô.
- Chế độ **fast** kém: ngày giờ 0/8, tên 2/10 (bỏ dấu 6–8/10), nội dung 2/8, ghép nhãn–giá trị 7–14/36, số tiền sai chữ số 2/8 ảnh. **Chỉ dùng accurate.**
- Ngôn ngữ mặc định và `vi-VT` không khác biệt đáng kể trong lần chạy 6 biến thể này; bật hay tắt "sửa lỗi theo ngôn ngữ" chỉ khác một chỗ (dòng tên ở ảnh nén mạnh). Cấu hình `en-US` **không có** trong lần chạy này: chỉ lần chạy đầu (4 mẫu sạch, [run 37161821721](https://github.com/vohoailinh90/xu-ios/actions/runs/37161821721)) có và cho kết quả giống mặc định. Chưa biết `en-US` có khác trên ảnh nén hay chữ nhỏ.
- Tốc độ trên máy chủ CI (máy ảo, **không đại diện cho iPhone**): accurate ~0,6–1,5 giây mỗi ảnh, fast ~35–80 ms. Chưa đo trên iPhone.
- Thứ tự dòng Vision trả về **không đáng tin để ghép nhãn với giá trị**: cùng một hàng, nhãn và giá trị là hai ô riêng, và theo trục dọc ô nào đứng trước phụ thuộc chênh lệch cỡ chữ. Ghép theo toạ độ (cùng hàng) cho 35–36/36; thứ tự dòng thì không.

### Điều rút ra được và điều chưa

Rút ra được (với ảnh dựng sẵn): Vision accurate đọc được chữ Việt có dấu và số tiền khi ảnh sạch, bị nén, thu nhỏ hay chữ nhỏ nhạt; số tiền to nhất trên màn hình là
dấu hiệu tốt; phải ghép theo toạ độ; không dùng fast.

**Chưa rút ra được**: độ chính xác trên ảnh thật. Mẫu do tôi dựng, một phông, nền phẳng, không biểu tượng, không mã QR, không nhiều con số cùng cỡ (số tiền, phí, số dư),
không số tài khoản che `****1234`, không ảnh chụp màn hình bị cắt. Đọc tốt ở đây chỉ nói rằng Vision không là điểm nghẽn hiển nhiên; điểm nghẽn có thể là **chọn đúng số**
trong bố cục từng ngân hàng — và đó đúng là thứ chỉ ảnh thật mới trả lời. Cũng chưa có ảnh nào bị chụp lệch, chụp màn hình bằng máy khác, hay có chữ chồng lên ảnh nền.

## Thí nghiệm 2 — ảnh thật (đang làm: 39/50 ảnh)

Dùng `prototypes/cham-bien-lai.html` (đã có: dán chữ OCR, nhập số đúng, xem tỉ lệ theo ngân hàng; ngưỡng 95%/90% có sẵn). Cần: ≥ 50 ảnh biên lai **của chính bạn**,
5 ngân hàng/ví phổ biến (che số tài khoản, tên người nhận nếu chia sẻ màn hình; biên lai là dữ liệu tài chính cá nhân — cần kiểm tra văn bản mới nhất về bảo vệ dữ liệu cá nhân).

Cần **cách lấy chữ OCR từ ảnh thật bằng đúng bộ đọc của Vision**. Trang chấm hướng dẫn dùng phím tắt "Thử biên lai" hoặc Văn bản trực tiếp (Live Text); chưa kiểm hai đường
đó dùng cùng bộ đọc và cùng tham số với `VNRecognizeTextRequest` — **cần kiểm tra**. Đã chọn (2026-10-04): **màn hình thử trong app, chỉ bản Debug** — chạy đúng
`VNRecognizeTextRequest` trên iPhone thật, cho luôn danh sách ngôn ngữ và tốc độ trên iOS 17/18.

### Kết quả sơ bộ trên biên lai thật (2026-10-04, 39/50 ảnh)

Chủ dự án chấm bằng trang `prototypes/cham-bien-lai.html` (bản đã đăng), lấy chữ bằng iPhone (Văn bản trực tiếp hoặc Phím tắt, **chưa ghi cách nào**, máy và iOS cũng **chưa ghi**). Số liệu chép từ ảnh chụp màn hình của trang, không có dữ liệu cá nhân.

| | Kết quả |
|---|---|
| Số tiền đọc đúng | **39/39 = 100%** (mọi ngân hàng đều 100%) |
| Tên người nhận đọc đúng | **43,6%** (khoảng 17/39). Tiêu chí tích ô "đúng dấu tiếng Việt" chưa rõ: nhiều biên lai in tên viết hoa không dấu, nên số này **chưa giải thích được**, cần hỏi lại |
| Số ảnh theo ngân hàng/ví | Khác 14 · Vietcombank 8 · Techcombank 6 · VietinBank 4 · Sacombank 4 · MB Bank 2 · ACB 1 |

Đọc con số này thế nào:

- **Chưa đủ để kết luận.** 39/39 đúng thì cận dưới khoảng tin cậy 95% (công thức Wilson) vẫn chỉ khoảng 91%, nên chưa loại trừ được tỉ lệ thật dưới 95%. Ngưỡng 95% trên 50 ảnh cho phép sai tối đa 2 ảnh (48/50 = 96%).
- **Nhóm "Khác" chiếm 14/39** nên chưa biết ngân hàng/ví nào trong đó; ACB mới 1 ảnh, MB Bank 2 ảnh: quá ít để nói về từng ngân hàng.
- **Đây là quy tắc chọn số của trang chấm (`findAmounts`) chạy trên chữ từ iPhone**, không phải bộ đọc Vision của app: bộ đọc của Văn bản trực tiếp/Phím tắt có cùng tham số với app hay không vẫn chưa kiểm. Số đo chỉ là chỉ báo.
- **Tên người nhận 43,6%** không nằm trong tiêu chí quyết định (chỉ số tiền) nhưng ảnh hưởng đến việc điền sẵn ghi chú; cần biết nguyên nhân (mất dấu, sai chữ, hay chỉ do cách tích ô) trước khi kết luận.
- Từ ảnh thứ 39 trang không lưu thêm được trên điện thoại của chủ dự án. **Chưa tái hiện được lỗi, nên chưa biết nguyên nhân**: mô phỏng 70 lần lưu trong trình duyệt không giao diện chạy hết (723 ms, không lỗi), và quy tắc chọn số chạy 1,3 triệu ký tự trong 176 ms. Điều đó chỉ cho thấy lỗi không xuất hiện ở môi trường thử; **không loại trừ** lỗi của trang (DOM, `localStorage`, giới hạn tài nguyên) hay hành vi riêng của trình duyệt điện thoại. Cần kiểm tra trên đúng thiết bị và trình duyệt đó. Sau đó mở lại trang thì **dữ liệu cũ mất hết** (tôi đã nói là sẽ còn: sai, vì chưa kiểm). Trang chỉ lưu trong bộ nhớ của trình duyệt đang mở; điện thoại có thể xoá nó hoặc mở ở ngữ cảnh khác thì không thấy. 39 ảnh vì vậy chỉ còn lại **bảng đã chụp**, không thể chấm lại hay xem từng ảnh. Lần sau: chép bảng ra ngoài ngay khi chấm xong.

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

- **Đường vào**: Share → Xu (Share Extension) và nút "Từ ảnh" trong app dùng bộ chọn ảnh của hệ thống. **Không tự quét thư viện ảnh** ở bản đầu: "gợi ý ảnh chụp mới nhất" cần quyền đọc thư viện (cần kiểm tra quy định App Store/quyền riêng tư và chịu cái giá niềm tin) — để sau (chủ dự án chốt không làm ở bản đầu, 2026-10-04).
- **Luồng**: ảnh → Vision (`.accurate`, `vi-VT` + `en-US`) trên máy → các dòng kèm toạ độ → trích xuất → **thẻ xem trước** (đúng luồng xem trước rồi lưu hiện có) → một chạm Lưu, không đòi gõ. Mục tiêu theo file tính năng: ~3 giây tới thẻ xem trước rồi ~1 giây để lưu (**chưa đo**).
- **Trích xuất** tách khỏi Vision, là hàm thuần trong `XuCore` (test được bằng `swift test`). **Phần số tiền đã có** (2026-10-04): `ReceiptAmountReader` (`XuCore/Sources/XuCore/ReceiptAmountReader.swift`), bản Swift của `findAmounts` + `pick` trong `prototypes/cham-bien-lai.html` — cùng quy tắc chọn số (cửa sổ ngữ cảnh đếm theo UTF-16 và tách dòng theo `\n` như trang), nên số đo của trang chấm tham khảo được cho app **với chữ Latin/ASCII thường gặp trên biên lai**. **Khác có chủ ý**: Swift dùng `TextFolding` chung với phần còn lại của `XuCore` nên chữ/số toàn khổ được đưa về nửa khổ (trang không), và số vượt `Int64` bị bỏ (trang vẫn nhận); ký tự lạ khác chưa kiểm hết, nên số đo của trang không phải bằng chứng cho mọi đầu vào. Các giá trị mong đợi trong test lấy từ việc chạy **chính đoạn JavaScript của trang** trên cùng chuỗi mẫu (dữ liệu giả). Quy tắc: số có dấu nhóm nghìn hoặc số trần ≥ 4 chữ số có đơn vị `vnd`/`đ`; điểm: đơn vị +3, dấu +/− +2, nhãn "số tiền/amount/tổng tiền" +4, nhãn "số dư/balance/phí/fee/hạn mức" −6; hoà điểm lấy số lớn hơn nhưng báo `isAmbiguous`. **Giới hạn đã biết** (giữ để khớp trang chấm, ghi thành test): số trần không đơn vị như `52000` bị bỏ; nhãn tìm theo chuỗi con nên "phi" trong từ khác cũng trừ điểm; nhãn trừ điểm ở dòng trên kéo điểm số ở dòng dưới xuống; `₫` và `dong` không tính là đơn vị. **Chưa làm**: tên người nhận, nội dung, ngày giờ; nối vào màn hình thử Debug hay luồng ghi. Quy tắc mới được thử trên ít biên lai thật (chưa đủ 50 ảnh/5 ngân hàng): chưa kết luận.
- **Không chắc thì để trống, đừng đoán**: không tìm ra số tiền hoặc có hai số ngang điểm thì ô số tiền để trống cho người dùng gõ, kèm câu giọng "không tội lỗi" (không "đọc thất bại"). Không bao giờ lưu số tiền đoán mà không hiện ra để người dùng thấy.
- **Dữ liệu**: không lưu ảnh. Chỉ lưu những trường cần (số tiền, ngày, nội dung ngắn). **Không lưu toàn bộ chữ OCR** vào `rawInput` (có tên người nhận, số tài khoản). Tên người nhận chỉ dùng làm ghi chú nếu người dùng giữ lại trên thẻ xem trước.
- **Riêng tư**: Vision chạy trên máy, ảnh không rời máy, nên câu trả lời App Privacy "Data Not Collected" (`docs/09`) giữ nguyên miễn là không gửi ảnh/chữ đi đâu (không OCR ngoài máy: `docs/09` đòi ghi quyết định trước). Khi phát hành phải thêm một dòng vào Cài đặt › Quyền riêng tư, `docs/privacy-policy.md` và mô tả App Store — **cần kiểm tra văn bản mới nhất**.
- **Đường lui** (nếu ảnh thật < 90%): "dán nội dung thông báo ngân hàng": người dùng sao chép chữ từ thông báo/tin nhắn rồi dán vào ô nhập; cùng hàm trích xuất. Bố cục chữ thì mỗi ngân hàng một kiểu, nên vẫn cần mẫu riêng.

## Kết luận tạm của spike (2026-10-04)

Chủ dự án chấp nhận lấy **39 ảnh** (thay vì 50) làm số liệu, vì trang không lưu thêm được và dữ liệu cũ mất; chỉ có bảng ở trên.

- **Trạng thái tiêu chí: chưa đạt, chưa kiểm.** Tiêu chí là số tiền ≥ 95% trên 50 ảnh thật/5 ngân hàng bằng bộ đọc của app (Vision). Mới có 39/39 = 100% là **tín hiệu sơ bộ tích cực** về quy tắc chọn số, chứ chưa phải kết quả của thí nghiệm quyết định: chưa đủ 50 ảnh (cận dưới ~91%); chữ lấy từ Văn bản trực tiếp/Phím tắt, **chưa phải Vision trong app**; nhóm "Khác" 14/39; ACB và MB Bank rất ít ảnh.
- **Chưa biết**: Vision trên iPhone thật (iOS 17/18, ngôn ngữ, tốc độ); vì sao tên người nhận chỉ 43,6%; chữ `₫`.
- **Đề xuất của tôi (quyết định là của chủ dự án):** coi 39/39 là **tín hiệu sơ bộ, không phải kết luận**. Việc nên làm trước khi xây tính năng cho người dùng là kiểm Vision trên iPhone thật với đủ 50 ảnh. Nếu chủ dự án chọn làm sớm ở phạm vi nhỏ (chọn ảnh → đọc → thẻ xem trước → lưu; số tiền chưa chắc thì để trống) thì đó là chấp nhận rủi ro Vision chưa kiểm, và **vẫn chưa nhắc "đọc ảnh chuyển khoản" trong mô tả App Store hay với người dùng** cho tới khi kiểm xong (`docs/10`: chỉ nói những gì đã làm được). Cập nhật nhật ký và điểm của tính năng ở App-idea-lab (luật 8).

## Quyết định của chủ dự án (2026-10-04)

1. **Miễn phí hay Pro — chốt:** OCR vẫn là quyền lợi Pro, nhưng người dùng Free được **đọc 5 ảnh miễn phí trong một tháng** (lời chủ dự án: "cho phép đọc 5 ảnh miễn phí 1 tháng"). Thay cho "dùng thử 5 lần" trước đó. Ghi tay không bị ảnh hưởng nên luật 5 (không khoá việc ghi) vẫn giữ.
   Các chi tiết dưới đây là **tôi diễn giải, chủ dự án chưa duyệt từng điểm**:
   - "Một tháng" = mỗi tháng dương lịch có 5 ảnh, đặt lại vào ngày 1. (Nếu ý là chỉ 5 ảnh trong tháng đầu tiên thì sửa mục này.)
   - Chỉ trừ lượt khi ảnh **đã được lưu thành khoản**; ảnh đọc lỗi hoặc bị bỏ qua không bị trừ (hợp "không tội lỗi").
   - Bộ đếm chỉ nằm trên máy (`AppSettings`), không gửi đi đâu (luật 6). Người đã mua Xu Pro không bị đếm.
   - Hết lượt thì chỉ hiện một dòng nhẹ kèm liên kết tới Xu Pro; **không** chặn bằng paywall giữa lúc đang ghi (`docs/02`), và ô ghi tay luôn dùng được.
2. **Gợi ý "ảnh chụp mới nhất" — chốt: không làm** ở bản đầu (cần quyền đọc thư viện ảnh).
3. **Nhiều ảnh một lượt — chốt: làm cho app Xu**, không phải trang chấm. Thiết kế ở App-idea-lab (`products/xu/features/ocr-anh-chuyen-khoan.md`, mục "Mở rộng: nhiều ảnh một lần"); chưa làm.
   Chưa chốt: khi người dùng Free chọn nhiều ảnh hơn số lượt còn lại. Đề xuất: báo trước "còn N lượt tháng này" và chỉ đọc N ảnh đầu, không đọc hết rồi mới chặn lưu; phần còn lại ghi tay hoặc mở khoá Pro.
   Lưu ý về giá trị: 5 ảnh mỗi tháng nghĩa là một lượt chọn nhiều ảnh dễ dùng hết hạn mức Free, nên tính năng này chủ yếu có ích cho người dùng Pro.
4. **Còn mở:** ai gom đủ 50 ảnh thật (5 ngân hàng/ví) và chạy màn hình thử Debug trên iPhone thật.

## Việc còn lại để đóng spike

- [x] Màn hình thử trong app (bản Debug) — chờ chạy thử trên iPhone thật.
- [x] Số đo trên ảnh thật: **39 ảnh** (chủ dự án chấp nhận thay vì 50), bảng ở mục "Kết quả sơ bộ". Tên người nhận 43,6% chưa giải thích được.
- [ ] Kiểm `supportedRecognitionLanguages` có `vi-VT` và `ja-JP` trên **iPhone thật iOS 17 và 18** (mục "Máy này" của màn hình thử; kết quả ở trên là macOS 15 trên máy chủ CI).
- [ ] Đo thời gian đọc một ảnh trên iPhone cũ nhất hỗ trợ (CI ~1 giây là máy ảo).
- [ ] Xem chữ thô của biên lai có `₫` (màn hình thử hiện chữ theo hàng), và/hoặc thêm log từng ca không khớp nguyên văn vào script, để biết nguyên nhân (ký hiệu, khoảng trắng hay dấu phân cách) trước khi quyết định xử lý ở bước trích xuất.
- [x] Quyết định Free/Pro, gợi ý ảnh mới nhất và nhiều ảnh một lượt (2026-10-04, mục trên); nhật ký ở App-idea-lab đã ghi.
- [ ] Chấm lại điểm tính năng ở App-idea-lab (luật 8) sau khi có số liệu Vision thật.
