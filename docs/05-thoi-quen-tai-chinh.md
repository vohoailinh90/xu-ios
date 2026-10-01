# 05 — Thói quen tài chính

Code: `XuCore/Sources/XuCore/HabitEngine.swift`, `SafeToSpend.swift`

## Vì sao thói quen là lõi, không phải phụ kiện

App chi tiêu thông thường chỉ đưa lại "thêm dữ liệu" sau mỗi lần ghi — không có phần thưởng, nên người dùng rơi khỏi app sau 2–4 tuần. Xu tạo **vòng lặp phần thưởng** ngay trong ngày:

```
Ghi khoản chi (2 giây) → thẻ "còn được tiêu" cập nhật
        → buổi tối "Chốt ngày" (1 chạm) → thói quen +1, điểm sức mạnh tăng
        → Chủ nhật: tổng kết tuần → "Tuần này có 4 ngày không tiêu vặt 🎉"
```

## Nghi thức "Chốt ngày"

- Thông báo buổi tối (mặc định 21:00, đổi được): *"Hôm nay có khoản nào chưa ghi không?"* với 2 nút: **Đã ghi đủ** · **Ghi thêm**.
- "Đã ghi đủ" tạo `DayClosure` cho ngày đó.
- Tại sao cần: nếu không có chốt ngày, một ngày không có giao dịch có thể là "không tiêu gì" hoặc "quên ghi". Thói quen "ngày không tiêu vặt" chỉ được tính khi ngày **đã chốt**, tránh thưởng nhầm cho việc quên.

## Thói quen mẫu (MVP)

| Mẫu | Cách đánh giá | Ghi chú |
|---|---|---|
| 📝 Ghi chép mỗi ngày | Tự động: có ≥ 1 giao dịch **hoặc** đã chốt ngày | Thói quen mặc định, bật sẵn |
| 🌱 Ngày không tiêu vặt | Tự động: đã chốt ngày **và** không có khoản chi ở danh mục "tiêu vặt" | Danh mục tiêu vặt mặc định: đồ uống, mua sắm, giải trí |
| 🧋 Không trà sữa | Tự động: đã chốt ngày **và** không có khoản chi đồ uống | Tên có thể đổi |
| 🍳 Nấu ăn ở nhà | Thủ công: người dùng tự đánh dấu | |
| 🐷 Để dành hôm nay | Thủ công | |

## Điểm sức mạnh thói quen (không reset về 0)

Lấy cảm hứng từ Loop Habit Tracker. Mỗi ngày:

```
m = 0,5 ^ (1/13)            ≈ 0,948  (chu kỳ bán rã ~13 ngày)
điểm = điểm_hôm_trước × m + (hoàn_thành ? 1 : 0) × (1 − m)
```

- Bỏ lỡ 1 ngày chỉ làm điểm giảm khoảng 5%, không mất trắng.
- Ngày nghỉ (người dùng đánh dấu ốm, đi du lịch…) không tính vào công thức.
- Hiển thị dạng phần trăm và vòng tròn: "Sức mạnh 72%".

## Chuỗi mềm (soft streak)

Vẫn giữ chuỗi vì người dùng thích con số, nhưng không tàn nhẫn:

- Mỗi 7 ngày được **1 lần "đóng băng"** tự động: lỡ 1 ngày thì chuỗi không đứt (nhưng ngày lỡ không được cộng).
- Hôm nay chưa xong thì chưa tính là lỡ — chuỗi đếm từ hôm qua.
- Lỡ 2 ngày trong cùng một cửa sổ 7 ngày → chuỗi kết thúc, **nhưng điểm sức mạnh vẫn còn**, và UI nói: *"Chuỗi mới bắt đầu, sức mạnh thói quen vẫn còn 64%."*

## "Hôm nay còn được tiêu" thay cho ngân sách đỏ

Người dùng chỉ đặt **một con số**: ngân sách linh hoạt tháng (tiền tiêu hàng ngày, không gồm tiền nhà, hóa đơn cố định).

```
số ngày còn lại    = từ hôm nay đến cuối kỳ (tính cả hôm nay)
mức mỗi ngày       = max(0, ngân sách − đã tiêu trước hôm nay) ÷ số ngày còn lại
còn được tiêu hôm nay = mức mỗi ngày − đã tiêu hôm nay
```

Khi hôm nay tiêu quá (số âm), **không hiện màu đỏ**. Hiện:

> "Hôm nay hơi quá tay 40k. Những ngày còn lại mỗi ngày còn khoảng 180k — vẫn ổn."

## Hướng dẫn giọng văn

| Tránh | Dùng |
|---|---|
| "Bạn đã vượt ngân sách!" | "Hôm nay hơi quá tay một chút." |
| "Chuỗi của bạn đã bị mất." | "Chuỗi mới bắt đầu. Sức mạnh thói quen vẫn còn." |
| "Cảnh báo chi tiêu" | "Nhìn lại tuần này" |
| Màu đỏ cho số âm | Màu hổ phách / cam nhạt |
| Dấu chấm than dồn dập | Câu ngắn, bình tĩnh, xưng "mình – bạn" |

## Ý tưởng mở rộng (sau MVP)

- **Thử thách** có thời hạn: 7 ngày không trà sữa, 30 ngày không mua Shopee, tiết kiệm 52 tuần. Hiển thị Live Activity.
- **Linh vật**: một chú heo đất / đồng xu nhỏ lớn dần theo điểm sức mạnh (kiểu Finch). Cần nghiên cứu kỹ để không làm rối giao diện tối giản.
- **Thói quen theo số lần mỗi tuần** (nấu ăn ở nhà 3 lần/tuần).
- **Chia sẻ thẻ tổng kết tuần** dạng ảnh đẹp lên mạng xã hội — kênh tăng trưởng tự nhiên.
