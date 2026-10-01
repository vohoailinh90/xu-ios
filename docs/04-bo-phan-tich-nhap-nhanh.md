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
- Nhiều số có đơn vị → lấy số đầu tiên và bật `hasMultipleAmounts` để UI gợi ý "Tách thành nhiều khoản?". `ăn trưa 45k tip 5k` → 45.000, ghi chú "ăn trưa tip 5k".
- Chỉ có số trần → lấy số lớn nhất.

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
- Tiếng Việt: không dùng một âm tiết mà bỏ dấu thành từ khác nghĩa — `tui` (túi/tui = tôi), `ca` (cá/cả), `trung`
  (trứng/trung tâm), `mung` (mừng/mùng 1), `son` (son/Sơn)… Hai cách thay:
  - cụm đã gấp rõ nghĩa: `tui xach`, `trung ga`, `mung cuoi`, `son moi`. Coi chừng cụm cũng trùng: `mua ca` khớp cả
    "mua cà phê" lẫn "mua cả sách";
  - từ **có dấu** trong `accentedKeywords`: `cá`, `trứng`, `túi`, `mừng` — so khớp trên ghi chú giữ dấu, nên "cá 50k" → đi chợ
    mà "cả hội" thì không. Gõ không dấu ("ca 50k") thì ra "Khác", sửa một chạm là Xu học.
  Cụm dài hơn vẫn thắng giữa hai loại ("cà phê" thắng "cá"); dài bằng nhau thì từ khoá đã gấp thắng như trước
  ("ăn cá 50k" → ăn uống), từ có dấu chỉ quyết khi không có gì khác khớp.
  Danh sách âm tiết/cụm cấm nằm trong `testAmbiguousSyllablesAreNotKeywords`.

## Việc tiếp theo cho parser

- [ ] Số bằng chữ từ giọng nói: "ba mươi lăm nghìn", "một triệu hai" (issue E9).
- [ ] Tách nhiều khoản trong một câu (issue E8).
- [ ] Từ lóng tiền: `lít`, `xị`, `chai` — tắt mặc định vì dễ nhầm ("2 lít xăng"), cho bật trong Cài đặt.
- [ ] Giờ: "7h sáng" → gán giờ cho `occurredAt`.
- [ ] Đo hiệu năng: 10.000 lần `parse` phải < 1 giây trên iPhone đời cũ nhất hỗ trợ.
- [ ] Bộ dữ liệu thật: cho phép người dùng (tự nguyện) gửi các câu parser hiểu sai để bổ sung test.
- [x] Tiếng Nhật: số viết bằng chữ Hán (`千五百円`), năm 令和, thứ trong ngoặc (`(月)`) — 2026-10-02.
- [ ] Tiếng Nhật: năm 令和 viết tắt kiểu hoá đơn (`R8.9.30`), số chữ Hán trộn chữ số (`1万五千円`).
