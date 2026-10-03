# 04 — Bộ phân tích câu nhập nhanh (QuickEntryParser)

Code: `XuCore/Sources/XuCore/QuickEntryParser.swift` · Test: `XuCore/Tests/XuCoreTests/QuickEntryParserTests.swift`

## Đầu vào và đầu ra

```
parse("Grab 52k hôm qua", now: 25/09/2026)
→ amount: 52000, isIncome: false, date: 24/09/2026,
  categoryID: "transport", note: "Grab", hasMultipleAmounts: false
```

## Các bước

1. **Chuẩn hóa**: đưa chuỗi về dạng NFC, rồi tạo bản "gấp" (chữ thường, bỏ dấu, `đ → d`) **giữ nguyên số ký tự** để vị trí trong bản gấp khớp 1:1 với chuỗi gốc. Nhờ vậy ghi chú trả về vẫn giữ dấu tiếng Việt.
2. **Tìm ngày** trên bản gấp, theo thứ tự ưu tiên: ngày tường minh `12/9`, `12/9/2026` → từ tương đối → thứ trong tuần. Đánh dấu vùng đã dùng.
3. **Tìm số tiền** trên bản gấp đã che vùng ngày.
4. **Nhận danh mục và thu/chi** từ phần ghi chú còn lại.
5. **Ghi chú** = chuỗi gốc bỏ vùng ngày và vùng số tiền được chọn, gộp khoảng trắng, bỏ dấu câu thừa ở hai đầu.

## Số tiền

| Người dùng gõ | Kết quả | Luật |
|---|---|---|
| `35k`, `35K`, `35 nghìn`, `35 ngàn` | 35.000 | × 1.000 |
| `1tr`, `1 triệu`, `1 củ` | 1.000.000 | × 1.000.000 |
| `1tr2`, `1tr25`, `1tr250` | 1.200.000 / 1.250.000 / 1.250.000 | Chữ số sau đơn vị là phần thập phân của đơn vị đó |
| `1k5` | 1.500 | như trên |
| `1.5tr`, `1,5 triệu` | 1.500.000 | Nhóm sau dấu cuối không đủ 3 chữ số → dấu thập phân |
| `35.000`, `1.250.000đ`, `35,000` | 35.000 / 1.250.000 / 35.000 | Mọi nhóm sau dấu đều đủ 3 chữ số → dấu phân cách hàng nghìn |
| `35000`, `35000đ`, `35000 vnd` | 35.000 | × 1 |
| `phở 45` (số trần < 1000) | 45.000 | Tùy chọn `smallNumbersAreThousands`, bật mặc định — người Việt hay bỏ "k" |
| `+15tr` | 15.000.000, thu nhập | Dấu `+` đứng trước |

**Khi có nhiều số:**
- Ưu tiên số có đơn vị tường minh (k, tr, đ…) hơn số trần. `trà sữa 2 ly 60k` → 60.000, ghi chú "trà sữa 2 ly".
- Nhiều số có đơn vị → lấy số đầu tiên và bật `hasMultipleAmounts` để UI gợi ý tách. `ăn trưa 45k tip 5k` → 45.000, ghi chú "ăn trưa tip 5k".
- Chỉ có số trần → lấy số lớn nhất, không gợi ý tách (`trà sữa 2 ly 30` không phải hai khoản).

### Số bằng chữ — đọc chính tả (E9, từ 2026-10-02)

`SpokenAmounts.swift` · Test: `XuCore/Tests/XuCoreTests/SpokenAmountTests.swift`. Câu đọc bằng giọng nói có thể ra chữ
thay vì số (máy viết số hay chữ tuỳ phiên bản iOS — cần kiểm tra trên máy thật); parser hiểu cả hai.

| Người dùng nói | Kết quả |
|---|---|
| `ba mươi lăm nghìn`, `hai lăm nghìn`, `ba mốt nghìn`, `năm chục nghìn` | 35.000 · 25.000 · 31.000 · 50.000 |
| `hai trăm năm mươi nghìn đồng`, `một trăm linh năm nghìn` | 250.000 · 105.000 |
| `một triệu rưỡi`, `hai nghìn rưỡi`, `một triệu hai trăm nghìn` | 1.500.000 · 2.500 · 1.200.000 |
| `hai nghìn năm trăm`, `hai nghìn năm mươi`, `một triệu năm mươi` | 2.500 · 2.050 · 1.050.000 — phần lẻ đọc rõ hàng trăm/chục là số của hàng kế dưới |
| `một triệu hai`, `một triệu hai lăm`, `hai nghìn năm` | 1.200.000 · 1.250.000 · 2.500 — nói tắt như `1tr2`, `1tr25`, `2k5`; chỉ khi là chữ cuối của cụm (`một triệu hai ly` → 1.000.000, ghi chú "hai ly") |
| `cơm ba trăm năm mươi yên` | 350 yên; `nghìn` nhân 1.000 với tiền của nơi chi tiêu như `k`, `triệu` luôn là tiền đồng |

- Phải có đơn vị (nghìn/ngàn, triệu, yên; `đồng` sau nghìn/triệu) và chữ số **có dấu** như máy đọc chính tả viết ra.
  Không dấu (`ba muoi nghin`) thì để nguyên: `bay` có thể là bay, `nam` là năm hay nam — người gõ tay thì gõ số.
- Không đoán bừa: `ba ly`, `năm nay` (không có đơn vị), `hai củ khoai` (`củ` không nhận), `hai đồng hồ` (`đồng` đứng
  một mình không nhận) không phải số tiền. Từ ghép không phải đơn vị: `triệu chứng`, `triệu phú`, `yên tâm`, `yên xe`,
  `đồng hồ`… (`SpokenAmounts.compounds`); `triệu đô` là đô-la, không nhận.
- Câu đã có số tiền gõ bằng chữ số kèm đơn vị thì **không** đọc số bằng chữ: câu gõ tay giữ nguyên kết quả cũ
  (`quà cho một triệu phú 50k` → 50.000). Có `+` sát trước thì là khoản thu, như `+10tr`: `+mười triệu`.
- Số bằng chữ là số có đơn vị: thắng số trần, và tách được như số gõ tay
  (`cà phê ba mươi lăm nghìn và bánh hai mươi nghìn`).

### Tách nhiều khoản (E8, từ 2026-10-02)

`split(_:)` trong `EntrySplitter.swift` · Test: `XuCore/Tests/XuCoreTests/SplitEntryTests.swift`.
Thẻ xem trước hiện thêm nút "✂️ Tách thành N khoản · 45k, 5k"; chạm là lưu hết trong một lần, toast "Hoàn tác" xoá hết.
Enter vẫn lưu **một** khoản như cũ — nút tách chỉ là thêm một lựa chọn, không làm chậm luồng ghi.

| Người dùng gõ | Các khoản |
|---|---|
| `ăn trưa 45k tip 5k` | ăn trưa 45.000 · tip 5.000 (cả hai là Ăn uống) |
| `cà phê 35k, grab 52k, bánh mì 20k` | cà phê · grab · bánh mì, mỗi khoản một danh mục |
| `35k cà phê 20k bánh mì` | cà phê 35.000 · bánh mì 20.000 |
| `hôm qua grab 52k và cà phê 35k` | cả hai là hôm qua |
| `lương +15tr thưởng +2tr` | hai khoản thu |
| `コーヒー350円とパン200円` | コーヒー 350 yên · パン 200 yên |

- Mỗi số tiền có đơn vị là một khoản; số trần (`2 ly`) ở lại trong ghi chú. Ngày tìm một lần, dùng chung cho mọi khoản.
- Chữ giữa hai số tiền thuộc khoản nào, theo thứ tự:
  1. có dấu câu ngăn (`,` `;` `、` `。` `+` `&`) thì cắt ở đó: `ăn trưa 45k với bạn, grab 20k` → "ăn trưa với bạn" · "grab";
  2. không có thì cắt ở chữ nối: `và` `and` `と` đứng riêng, hoặc `と` sát ngay sau số tiền mà sau nó là katakana/chữ Hán
     (`350円とパン`) hay mở đầu một từ khoá danh mục (`350円とお茶`, `とうどん`, `とおにぎり`). `と` là chữ đầu của từ thì
     giữ — thà để sót trợ từ còn hơn cắt mất chữ: `980円とんかつ`, `とうふ`;
  3. không có cả hai thì theo cách gõ cả câu: có chữ trước số tiền đầu tiên → chữ đi với số đứng sau nó; câu mở đầu
     bằng số tiền → chữ đi với số đứng trước nó.
- `va` không dấu **không** là chữ nối: có thể là "vá" (`gui xe 5k va xe 30k` → "gui xe" · "va xe").
  `với` cũng không: thường là "cùng với" ("ăn trưa với bạn").
- Khoản không nhận ra danh mục lấy danh mục khoản chi của cả câu — cái thẻ xem trước đang hiện, kể cả khi người dùng
  đã chọn tay (`fallbackCategoryID`): "tip" vẫn là Ăn uống.
  Khoản thu chỉ khi khoản đó có `+` hoặc từ khoá thu nhập; danh mục thu nhập của cả câu không lan sang khoản khác.
- Danh mục chọn tay trên thẻ xem trước cũng là của khoản đầu (khoản thẻ đang hiện) và được học theo ghi chú của khoản đó.
- Vẫn là gợi ý: `giảm 20k còn 80k`, `nạp 100k tặng 20k` có hai số tiền nhưng là một khoản — người dùng cứ Enter.

## Ngày

| Người dùng gõ | Kết quả (hôm nay là thứ Sáu 25/09/2026) |
|---|---|
| (không có) / `hôm nay` / `sáng nay` / `trưa nay` / `chiều nay` / `tối nay` | 25/09 |
| `hôm qua` / `tối qua` / `đêm qua` / `sáng qua` | 24/09 |
| `hôm kia` | 23/09 |
| `thứ 2`, `thu 2`, `t2` | 21/09 (thứ Hai gần nhất, tính cả hôm nay) |
| `cn`, `chủ nhật` | 20/09 |
| `12/9` | 12/09/2026 |
| `28/12` | 28/12/**2025** (ngày trong tương lai của năm nay → hiểu là năm ngoái) |

Mẹo: trong lịch Gregorian của Foundation, `weekday` 1 = Chủ nhật, 2 = thứ Hai… 7 = thứ Bảy — **trùng khớp với cách người Việt gọi "thứ 2…thứ 7"**, nên chuyển đổi rất gọn.

**Tránh nhầm "thu" (thứ) với "thu" (thu tiền):** `thu 5 triệu tiền thưởng` không phải "thứ 5" vì theo sau là đơn vị tiền. Regex thứ trong tuần có lookahead loại trừ trường hợp số được theo sau bởi đơn vị tiền hoặc chữ số.

## Giờ (từ 2026-10-03)

`findTime(in:original:)` trong `QuickEntryParser.swift` · Test: `XuCore/Tests/XuCoreTests/TimeOfDayTests.swift`.
Kết quả là `QuickEntryResult.minutesOfDay` (số phút từ 0:00, `nil` nếu câu không có giờ). `date` vẫn chỉ là ngày: **giờ không bao giờ đổi
ngày của khoản** (`storedDay`). Có giờ thì `Ledger` lưu `occurredAt` đúng giờ đó; không có thì như cũ (hôm nay: bây giờ,
ngày khác: 12:00). Thẻ xem trước hiện "Hôm qua · 19:00" để người dùng thấy ngay nếu hiểu sai.

**Nguyên tắc: chỉ nhận giờ khi người dùng nói rõ đó là một thời điểm.** Một con số dính chữ `h`/`:` chưa chứng minh gì: `2h30` là thời lượng,
`1:20` là tỷ lệ, `20h` là pin. Chữ buổi đứng cạnh nó cũng chưa đủ: mỗi chữ buổi là **đầu của cả một họ từ ghép** (`tối đa`, `tối ưu`, `tối thiểu`,
`sáng tạo`, `sáng kiến`, `chiều cao`…) hay một từ khác sau khi bỏ dấu (`tôi`/`tối`). Danh sách loại trừ thì không bao giờ đủ, nên mô hình dựa vào
**hai bảo đảm cấu trúc** thay vì đoán từng từ. Mọi thứ không qua được thì bỏ qua và giữ nguyên chữ của người dùng. Bỏ sót giờ thì khoản vẫn
đúng ngày như trước khi có tính năng này; nhầm giờ thì ghi chú mất chữ, `occurredAt` sai, hoặc mất số tiền.

**Ba cách nói rõ một thời điểm:**

| Cách | Ví dụ | Giờ · ghi chú còn lại |
|---|---|---|
| 1. Buổi đứng **ngay sau** giờ, mà sau buổi là **hết câu, dấu câu hoặc con số** | `cà phê 7h sáng 35k` · `xem phim 8h15 tối 120k` · `grab 7h tối` | 07:00 `cà phê` · 20:15 `xem phim` · 19:00 `grab` |
| 2. Buổi đứng **đầu câu**, hoặc kèm `nay`/`qua`; liền sau là chữ số | `sáng 7h cà phê 35k` · `chiều nay 3h trà sữa 45k` · `tối qua 7h taxi 100k` | 07:00 `cà phê` · 15:00 hôm nay `trà sữa` · 19:00 hôm qua `taxi` |
| 3. `lúc` / `vào lúc` | `đi chợ lúc 7h30 100k` · `vào lúc 7:30 phở 45` · `lúc 7h tối qua grab 52k` | 07:30 `đi chợ` · 07:30 `phở` · 19:00 hôm qua `grab` |

Cụm giờ (cả `lúc`, `vào lúc` và buổi đứng đầu câu) bỏ khỏi ghi chú.

**Bảo đảm 1, từ ghép:** chữ buổi chỉ nhận khi cấu trúc chứng minh nó không phải đầu một từ ghép: liền sau nó là chữ số (cách 2, không thể là từ ghép) hoặc
sau nó là hết câu/dấu câu/con số (cách 1). Chữ buổi đứng cạnh giờ mà sau đó là **một từ khác** thì mơ hồ: bỏ cả giờ, không đoán AM/PM.
`taxi lúc 7h tối đa 100k` và `lúc 7h sáng tạo logo 500k` không có giờ, ghi chú giữ nguyên. Chuỗi dấu câu **dính liền** chữ buổi (một hay nhiều dấu) rồi tới ngay một chữ cái
(`tối-đa`, `sáng-tạo`, `tối'đa`, `tối--đa`) cũng nối thành một từ ghép, không phải ranh giới; dấu có khoảng trắng sau hoặc quanh nó (`7h sáng, mua`, `7h sáng - 35k`)
hay theo sau là số (`7h sáng,35k`) thì là dấu câu thật. Khoảng trắng giữa các thành phần của cụm giờ (`7h  tối`, `vào  lúc`, `sáng  nay`) có thể là một hay nhiều (dấu cách, tab, NBSP), và cụm ngày bên trong nó (`tối  qua`, `hôm   qua`, `last   night`) nhận cùng quy tắc, để giờ và ngày luôn hiểu cùng một câu. Cái giá: `7h tối ăn phở 45k` (giờ, buổi, rồi một từ) không nhận;
viết `tối 7h ăn phở 45k` hoặc `ăn phở 7h tối 45k` thì được.

**Bảo đảm 2, tiền:** **giờ không bao giờ lấy mất con số mà bộ phân tích tiền sẽ chọn** (số có đơn vị đầu tiên, nếu không thì số trần lớn nhất — đúng như `parse`).
Nếu cụm giờ che con số đó thì số đó là tiền, không phải phút: bỏ giờ, giữ tiền (`cà phê lúc 7:30`, `2 ly cà phê lúc 7 giờ 45`). Bỏ giờ thì quay về đúng kết quả như trước khi có
tính năng giờ. Một bất biến chung (ở `analyze`) thay cho việc đoán từng cách viết tiền: dấu phân nhóm, nhiều dấu cách, đơn vị lạ, số trần vô can như `2 ly`.
Ở gốc, phút chỉ là phút khi sau nó **không tiếp tục cú pháp số tiền**: không có `.000`/`,5` (`30.000đ`, `30,5 triệu`) và không có đơn vị tiền sau bất kỳ khoảng trắng nào
(`7 giờ 30 nghìn`, `30  triệu`, `30 yên`). Phút bị từ chối thì `cà phê lúc 7 giờ 30.000đ` là 07:00 và 30.000; `2 ly cà phê lúc 7 giờ 30.000đ` cũng vậy (`2 ly` ở lại trong ghi chú).

Không nhận (giờ = không có, ghi chú giữ nguyên):

| Người dùng gõ | Vì sao |
|---|---|
| `19h30 grab 52k`, `7:30 phở 45`, `23h grab 90k` | dạng trần: không nói rõ là thời điểm |
| `thuê phòng 2h30 100k`, `thuê phòng trong 2:30 100k`, `pin dùng được 20h giá 500k`, `tỷ lệ 1:20 phí 50k` | thời lượng / tỷ lệ |
| `ăn tối 7h 80k`, `ăn sáng 7h30 35k`, `đèn sáng 20h giá 500k` | buổi nằm giữa câu là chữ của ghi chú, không phải bằng chứng |
| `7:30 sáng cà phê 35k`, `in bản đồ tỷ lệ 1:20 sáng nay 50k` | dạng dấu hai chấm chỉ nhận khi có `lúc` (`sáng nay` vẫn là ngày hôm nay) |
| `thuê phòng trong 2h30 sáng nay 100k`, `7h tối qua grab 52k` | buổi theo sau mà mở đầu `nay`/`qua` thuộc về cụm ngày: `2h30 sáng nay` (thời lượng + ngày) và `7h tối qua` (giờ + ngày) về chữ không phân biệt được, nên không đoán. `tối qua 7h` thì rõ; có `lúc` thì cũng rõ |
| `tối qua 1h taxi 100k` | giờ sau nửa đêm, có thể là 1 giờ sáng nay: mơ hồ |

- Buổi: `sáng`, `trưa`, `chiều`, `tối`, `đêm`; mỗi buổi chỉ nhận khoảng giờ người ta thật sự nói với nó (giờ 12h hoặc 24h): `sáng` 1–11 ·
  `trưa` 10–13 và 1–3 (→ 13–15) · `chiều` 1–7 (→ 13–19) và 13–18 · `tối` 5–11 (→ 17–23) và 17–23 · `đêm` 9–11 (→ 21–23), 12 (→ 0), 0–5, 21–23.
  Ngoài khoảng đó (`5h trưa`, `11h chiều`, `1h tối`, `12h sáng`, `19h sáng`) thì không phải giờ, không cộng 12 bừa.
- **Chữ buổi và `lúc` phải viết đủ dấu**, đối chiếu với chữ gốc: chuỗi đã bỏ dấu coi `tôi` (đại từ) như `tối`, `đem` như `đêm`, `sang` như `sáng`
  (`lúc 7h tôi ăn phở 45k` là 7 giờ, ghi chú giữ `tôi ăn phở`). Gõ không dấu (`7h toi`, `luc 19h30`) thì không đoán, như `SpokenAmounts`
  chỉ nhận chữ số có dấu. Hoa thường không quan trọng (`7h TỐI`).
- `nay`/`qua` có thể cách chữ buổi bằng nhiều dấu cách (văn bản dán vào): `2h30 sáng  nay` vẫn là thời lượng rồi ngày.
- Với `lúc` mà không có buổi thì giờ là số viết ra, 0–23 (`lúc 7h` → 07:00, `lúc 19h` → 19:00); muốn chiều/tối thì thêm buổi theo cách 1 (`lúc 7h tối 52k`).
- Phút dính liền `h` (`7h30`); riêng "giờ" cho một dấu cách (`7 giờ 30`). `7h 35k` là `7h` rồi `35k`; `7 giờ 30k` là 30k, không phải 7:30.
  Giờ không hợp lệ (`24h`, `25:61`) hoặc dính chữ (`wifi7h30`) thì bỏ qua.
- Số trong cụm giờ không bao giờ là số tiền: `lúc 7:30 phở 45` → 45.000 (không phải 30).
- `split`: cụm giờ không tính là chữ đi trước số tiền đầu tiên (`sáng 7h 35k cà phê 20k bánh` → `cà phê` · `bánh`); mọi khoản dùng chung giờ.
- Chưa làm: giờ kiểu Nhật (`7時30分`), kiểu Anh (`7am`), sửa giờ trên màn sửa khoản.
- Tốc độ: `analyze` thêm một regex cho giờ (và, khi cần, một lần tìm số tiền thứ hai cho bất biến tiền). `QuickEntryParserTests/testPerformance` (`measure`) đã
  theo dõi; mục tiêu < 1 giây cho 10.000 lần `parse` trên iPhone đời cũ nhất hỗ trợ vẫn phải đo trên máy thật (CI chạy Debug trên máy Mac nên không đại diện).

## Danh mục

- So khớp trên ghi chú đã gấp, theo **cụm từ nguyên vẹn** (có ranh giới từ), **cụm dài nhất thắng**: `tiền nước` (Hóa đơn) thắng `nước` (Đồ uống).
- Từ khóa học được của người dùng được xét trước từ khóa mặc định.
- Tránh từ khóa một âm tiết dễ trùng nghĩa sau khi bỏ dấu: `bé/be` (app Be), `cho/chợ`, `bạn/bán`, `trả/trà`. Dùng cụm dài hơn: `di cho`, `tra sua`.
- Thu nhập: dấu `+` hoặc danh mục thu nhập (`luong`, `thuong`, `hoan tien`, `nhan tien`…). Có dấu `+` mà danh mục đoán được là khoản chi → chuyển thành "Thu nhập khác".

## Thị trường Nhật, tiếng Nhật và tiếng Anh (từ 2026-10-01)

Quyết định và phạm vi: `docs/08-thi-truong-nhat-va-ngon-ngu.md`. Test: `XuCore/Tests/XuCoreTests/JapanMarketTests.swift`.
Parser nhận `Options.market` (Việt Nam / Nhật) và trả thêm `currency` (VND / JPY).

**Chuẩn hoá:** bản gấp đưa chữ/số toàn khổ của bàn phím Nhật về nửa khổ (`３５０円` → `350円`, `￥` → `¥`) và **chỉ bỏ dấu cho chữ Latin**:
bỏ dấu ゛゜ của kana sẽ làm `バス` (xe buýt) trùng `パス`, và `パスタ` bị hiểu là đi lại.
Ranh giới từ chỉ xét chữ Latin và số, nên chữ Nhật đứng sát số vẫn tách được: `コーヒー350円`.

### Số tiền

| Người dùng gõ | Kết quả | Luật |
|---|---|---|
| `350円`, `¥350`, `￥３５０`, `350 yên` | 350 yên | 円, ¥, yên luôn là yên, ở cả hai thị trường |
| `ラーメン 980` (thị trường Nhật) | 980 yên | Số trần là tiền của nơi chi tiêu; `smallNumbersAreThousands` chỉ áp cho tiền đồng |
| `1万`, `1.5万`, `1万2千円`, `1万2000`, `1万500`, `2千5百円` | 10.000 / 15.000 / 12.000 / 12.000 / 10.500 / 2.500 | Số kiểu Nhật, luôn là yên |
| `1万2`, `2千5` | 12.000 / 2.500 | Một chữ số đứng sau 万/千 là cách nói tắt; từ hai chữ số trở lên thì cộng nguyên (`1万25` = 10.025) |
| `千円`, `百円`, `千五百円`, `一万二千円`, `二〇〇円` | 1.000 / 100 / 1.500 / 12.000 / 200 | Số viết toàn chữ Hán chỉ là tiền khi ngay sau là 円: `千葉`, `百貨店`, `八百屋` không phải số tiền |
| `25 man`, `1man2`, `3 sen` (thị trường Nhật) | 250.000 / 12.000 / 3.000 yên | Từ lóng của người Việt ở Nhật (vạn, nghìn yên). **Tắt** ở thị trường Việt Nam để không nhầm "mận", "sen" |
| `35k`, `35 nghìn` (thị trường Nhật) | 35.000 yên | k / nghìn / ngàn nhân 1.000 với tiền của nơi chi tiêu |
| `gửi về nhà 5tr`, `50.000đ` (thị trường Nhật) | tiền đồng | tr, triệu, củ, đ, đồng, vnd chỉ thuộc về tiền đồng |
| `100均 330`, `100円ショップ 550円` | 330 / 550 | Tên cửa hàng có số được che trước khi tìm số tiền |

### Ngày

| Người dùng gõ | Kết quả (hôm nay là thứ Sáu 25/09/2026) |
|---|---|
| `今日`, `今朝`, `今夜`, `today`, `tonight`, `this morning` | 25/09 |
| `昨日`, `きのう`, `昨夜`, `昨晩`, `yesterday`, `last night` | 24/09 |
| `一昨日`, `おととい`, `day before yesterday` | 23/09 |
| `9/20` | Thị trường Nhật: 20/09 (tháng trước, ngày sau). Thị trường Việt Nam vẫn là ngày/tháng |
| `2026/9/1`, `2026-09-01` | 01/09/2026 (năm trước) |
| `9月20日`, `2026年9月1日`, `令和8年9月1日`, `20日` | 20/09 · 01/09 · 01/09/2026 (令和元年 = 2019) · 20/09. `28日` chưa tới trong tháng → 28/08. `3日間`, `3日分`, `2日目` không phải ngày. `N日` thiếu tháng chỉ là ngày khi đứng riêng: bên trái là đầu câu, khoảng trắng hoặc dấu câu; bên phải là hết câu, khoảng trắng, dấu câu, buổi trong ngày, `から`, `ごろ`/`頃` hoặc `の` (`20日朝`, `20日午後`, `20日から`, `20日の`). `1日乗車券`, `2日酔い`, `3日で5000円`, `1日につき500円`, `最長3日まで`, `3泊4日`, `3泊 4日` không phải ngày |
| `月曜`, `月曜日`, `(月)`, `（月）`, `monday` | 21/09 (thứ Hai gần nhất, tính cả hôm nay) |
| `9/23(水)`, `9/23 (水曜日)` | 23/09; thứ trong ngoặc ngay sau ngày cũng bỏ khỏi ghi chú |

- Tiếng Anh chỉ hiểu tên thứ đầy đủ: viết tắt `mon`, `sat` trùng `món`, `sát` sau khi bỏ dấu.
- `昨日のランチ` → ghi chú `ランチ`, `20日から 旅行` → `旅行`: bỏ trợ từ ngay sau ngày, nhưng thà để sót trợ từ còn hơn cắt mất chữ:
  `の`, `に`, `は`, `で` giữ lại nếu sau nó là hiragana (`昨日のり弁` → `のり弁`); `から` chỉ bỏ khi đứng riêng
  (`昨日から揚げ` → `から揚げ`, `20日から旅行` → `から旅行`).
- Trợ từ hay dùng cho thời lượng/đơn giá (`まで`, `で`, `に`, `は`, `も`) không làm "N日" thành ngày: `最長3日まで`, `3日で`, `1日につき`, `3日は無料`.
  Nhầm ngày thì khoản chi bị ghi sang ngày khác mà người dùng không thấy; bỏ sót ngày thì vẫn thấy ngay trên thẻ xem trước.

### Danh mục

- Từ khoá có chữ Nhật được so khớp **chuỗi con** (tiếng Nhật không có khoảng trắng giữa từ); cụm dài nhất vẫn thắng: `セブンでコーヒー` → đồ uống.
- Tránh từ khoá một chữ Hán nằm trong từ khác: `本` có trong `日本`, `パン` có trong `パンツ`. Dùng `本屋`, `パン屋`.
- Test `testNoKeywordInTwoCategories` chặn một từ khoá nằm ở hai danh mục; `testKeywordsAreWrittenFolded` bắt từ khoá viết
  chưa ở dạng đã gấp (sẽ không bao giờ khớp).
- Tiếng Việt: không thêm từ khoá một âm tiết mà bỏ dấu thành từ khác nghĩa (bé/be, chợ/cho, bạn/bán, trà/trả…).
  Các âm tiết đã có từ trước mà nhiều nghĩa — `ca` (cá, cà / cả), `trung` (trứng / trung tâm, trung thu), `tui` (túi / tui = tôi),
  `mung` (mừng / mùng 1), `son` (son / Sơn) — khai trong `CategoryCatalog.ambiguousSyllables` kèm các dạng có dấu được tính.
  Xét **từng âm tiết**: gõ đúng dạng đó ("cá 50k", "cà chua") hoặc gõ không dấu ("ca", "trung gà", "tui xách") thì khớp như cũ;
  gõ bằng dạng có dấu khác nghĩa ("cả nhà", "mùng 1", "Sơn") thì không. "tui" không dấu vừa là "túi" vừa là "tui" (tôi)
  nên vẫn khớp mua sắm như trước — không đoán được.
  Mọi từ khoá khác giữ nguyên như trước; chỉ thêm cụm rõ nghĩa (`nuoc mam`, `giay ve sinh`, `tieng anh`, `an trung`…).
  Coi chừng cụm cũng trùng: `mua ca` khớp cả "mua cà phê" lẫn "mua cả sách" — danh sách cấm nằm trong
  `testAmbiguousSyllablesAreNotKeywords`.

## Việc tiếp theo cho parser

- [x] Số bằng chữ từ giọng nói: "ba mươi lăm nghìn", "một triệu hai" (issue E9) — 2026-10-02.
- [x] Tách nhiều khoản trong một câu (issue E8) — 2026-10-02.
- [x] Từ lóng tiền `lít`, `xị`, `chai`: **không hỗ trợ** (quyết định 2026-10-03). Giá trị khác nhau theo vùng và dễ nhầm
  ("2 lít xăng"). Xu chỉ hiểu cách viết chuẩn: `k`, `nghìn`, `tr`, `triệu`, số bằng chữ.
- [x] Giờ: "7h sáng" → gán giờ cho `occurredAt` — 2026-10-03.
- [ ] Đo hiệu năng: 10.000 lần `parse` phải < 1 giây trên iPhone đời cũ nhất hỗ trợ. (Đã có `testPerformance` để theo dõi; phải đo trên máy thật.)
- [ ] Bộ dữ liệu thật: cho phép người dùng (tự nguyện) gửi các câu parser hiểu sai để bổ sung test.
- [x] Tiếng Nhật: số viết bằng chữ Hán (`千五百円`), năm 令和, thứ trong ngoặc (`(月)`) — 2026-10-02.
- [ ] Tiếng Nhật: năm 令和 viết tắt kiểu hoá đơn (`R8.9.30`), số chữ Hán trộn chữ số (`1万五千円`).
