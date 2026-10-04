# Xu (iOS) — hướng dẫn cho Claude

Trả lời bằng tiếng Việt. Đọc `README.md` và `docs/01-tam-nhin-san-pham.md` trước khi làm bất cứ việc gì.

## Luật

1. **Tôn trọng 4 nguyên tắc** trong `README.md` (mục "Nguyên tắc sản phẩm"): quy tắc 2 giây, không tội lỗi, riêng tư/offline, Việt Nam trước. Thay đổi làm chậm việc ghi thì không làm.
2. **Không làm** những mục trong "Không làm" của `docs/01-tam-nhin-san-pham.md` (liên kết ngân hàng, mạng xã hội, đầu tư/crypto, Android sớm).
3. **Không bịa** số liệu, link, giá hay điều khoản App Store. Chưa chắc thì ghi "cần kiểm tra".
4. **Pháp lý & chính sách:** dữ liệu tài chính cá nhân, App Privacy, thanh toán → ghi "cần kiểm tra văn bản mới nhất", không tư vấn như luật sư.
   Mọi tính năng số bán qua IAP (StoreKit 2); không lách IAP.
5. **Không bao giờ khoá việc ghi và xuất dữ liệu** sau paywall; paywall không hiện lúc đang ghi.
6. **Không thu thập dữ liệu** ngoài máy người dùng nếu chưa có quyết định ghi trong `docs/`.
7. **Phạm vi một người làm được:** ưu tiên thay đổi nhỏ, không thêm thư viện ngoài khi chưa cần.
8. Ý tưởng tính năng mới và chấm điểm làm ở repo
   [App-idea-lab](https://github.com/vohoailinh90/App-idea-lab) (`products/xu/`), không làm ở đây.

## Sau khi mở PR

Comment `@codex review` lên PR kèm một dòng nói cần xem gì. Sửa tới khi Codex không còn finding ở commit mới nhất.

Được **tự merge** PR (chủ dự án cho phép 2026-10-04, áp dụng cho mọi PR) khi đủ cả 4 điều kiện:
1. Codex đã review **commit mới nhất** và không còn finding (không có đề xuất, hoặc chỉ thả 👍). Sau mỗi lần push sửa, comment lại `@codex review` và chờ kết quả cho commit đó.
2. Mọi thread review đã được trả lời; thread đã sửa thì resolve. Thread đang chờ chủ dự án quyết (ví dụ cách hiểu một luật) thì **không** tự đóng, và PR chưa tự merge cho tới khi có câu trả lời.
3. Không xung đột với `main`; CI xanh (XuCore tests, App build).
4. Test trong repo chạy qua (CI macOS chạy `swift test`).

Merge xong thì làm tiếp việc kế tiếp mà không cần hỏi lại. Không có ngoại lệ theo loại file: PR sửa cả `CLAUDE.md`/`AGENTS.md` cũng tự merge khi đủ 4 điều kiện (chủ dự án xác nhận 2026-10-04).

## Dùng chung với Codex

`AGENTS.md` là bản cho Codex của file này — sửa luật ở file này thì sửa cả `AGENTS.md`.
