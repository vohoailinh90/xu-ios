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

## Việc tiếp theo cho parser

- [ ] Số bằng chữ từ giọng nói: "ba mươi lăm nghìn", "một triệu hai" (issue E9).
- [ ] Tách nhiều khoản trong một câu (issue E8).
- [ ] Từ lóng tiền: `lít`, `xị`, `chai` — tắt mặc định vì dễ nhầm ("2 lít xăng"), cho bật trong Cài đặt.
- [ ] Giờ: "7h sáng" → gán giờ cho `occurredAt`.
- [ ] Đo hiệu năng: 10.000 lần `parse` phải < 1 giây trên iPhone đời cũ nhất hỗ trợ.
- [ ] Bộ dữ liệu thật: cho phép người dùng (tự nguyện) gửi các câu parser hiểu sai để bổ sung test.
