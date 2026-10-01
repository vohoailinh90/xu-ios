# Bản mô phỏng HTML của Xu

Hai trang HTML chạy thẳng trong trình duyệt (mở file hoặc xem bản đã đăng). Đây là **bản mô phỏng để thử ý tưởng**,
không phải code app — code thật nằm ở `XuCore/` và `App/`.

| File | Để làm gì | Bản đã đăng |
|------|-----------|-------------|
| [xu-demo.html](xu-demo.html) | Bấm thử luồng ghi chi tiêu: gõ câu ("cà phê 35k"), chip khoản quen, hoàn tác, "hôm nay còn được tiêu", Báo cáo, Cài đặt giới hạn, xuất CSV | https://claude.ai/artifact/HkjeRU3nTVyhn944p6F6g1 |
| [cham-bien-lai.html](cham-bien-lai.html) | Chấm độ chính xác khi đọc ảnh: biên lai chuyển khoản (Việt Nam) hoặc hoá đơn cửa hàng ở Nhật (レシート). Dán chữ OCR, nhập số đúng, xem tỉ lệ đúng theo ngân hàng/cửa hàng | Mở file trên máy |

## Lưu ý

- `xu-demo.html` dùng bản JavaScript chép lại từ parser, danh mục và "còn được tiêu" của `XuCore`. Khi `XuCore` đổi,
  bản mô phỏng có thể lệch — tin `XuCore` và test của nó, không tin trang này.
- Dữ liệu trong `xu-demo.html` chỉ nằm trong trang, tải lại là mất.
- `cham-bien-lai.html` **không gửi gì ra ngoài máy** (luật 6 của `CLAUDE.md`): kết quả (ngân hàng, số tiền, đúng/sai) chỉ lưu trong
  trình duyệt đang mở (localStorage); chữ OCR không được lưu. Muốn gom kết quả về một chỗ thì cần ghi quyết định vào `docs/` trước.
- Chỉ dùng biên lai của chính bạn; che số tài khoản, tên người nhận nếu chia sẻ màn hình. Biên lai là dữ liệu tài chính cá nhân
  (cần kiểm tra văn bản mới nhất về bảo vệ dữ liệu cá nhân).
- Chế độ hoá đơn Nhật chọn số ở dòng 合計/お会計, bỏ qua 小計, お預り, お釣り, dòng thuế. Kết quả hai loại được chấm riêng.
  Hoá đơn Nhật đang mượn tạm ngưỡng 95%/90% của biên lai chuyển khoản; tính năng đọc hoá đơn Nhật chưa có file ở App-idea-lab.
- Kết quả chấm biên lai dùng để cập nhật điểm và nhật ký của tính năng
  [ocr-anh-chuyen-khoan](https://github.com/vohoailinh90/App-idea-lab/blob/main/products/xu/features/ocr-anh-chuyen-khoan.md) ở App-idea-lab.
