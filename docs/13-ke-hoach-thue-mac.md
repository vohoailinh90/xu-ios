# 13 — Kế hoạch thuê Mac vật lý để thử Xu trên iPhone

> Viết 2026-10-10 theo quyết định của chủ dự án: **thuê một máy Mac vật lý**, cắm iPhone của mình vào, dùng tài khoản Apple **miễn phí**, chưa đăng ký chương trình trả phí (lý do và giới hạn: `docs/12`).
> **Chưa ai chạy thử kế hoạch này.** Điều Apple nói lấy từ các trang ghi ở cuối `docs/12`; điều khoản và giới hạn của Apple đổi thường xuyên nên **cần kiểm tra văn bản mới nhất**.
> Giá thuê, điều kiện thuê và cấu hình máy của từng nơi cho thuê mình không biết, nên mọi thứ liên quan ghi **cần kiểm tra**.

## Số ngày thuê và hạn 7 ngày

Ước lượng của mình: **khoảng 3 ngày, có thể từ 2 đến 5; chưa đo lần nào.** Chỗ chưa biết lớn nhất là giai đoạn 1 (lần ký đầu bằng tài khoản miễn phí có thể gặp lỗi chưa lường được) và việc đọc ≥ 50 ảnh biên lai.
Thời gian thuê tối thiểu do nơi cho thuê quyết định (**cần kiểm tra**). Mỗi ngày thuê là tiền, nên làm hết phần chuẩn bị ở nhà trước. Thử xong thì ghi số ngày và tổng chi phí thuê thật vào bảng cuối trang,
để so với đường B (99 USD mỗi năm, `docs/12`).

Hồ sơ cấp phép của tài khoản miễn phí hết hạn sau **7 ngày** (`docs/12`). Mình hiểu là tính từ lúc Xcode tạo hồ sơ, tức gần lúc cài lần đầu (chưa kiểm), nên cài app lên iPhone **ngay ngày đầu**: sau khi trả máy,
app vẫn mở được cho tới khi hồ sơ hết hạn (suy ra từ giới hạn 7 ngày, chưa kiểm). Hết hạn thì app không mở được cho tới khi cài lại bằng Mac; cài lại có giữ dữ liệu trong app hay không: chưa kiểm.

## Trước khi thuê (làm ở nhà, không cần Mac)

1. **Hỏi nơi cho thuê** (mình không biết câu trả lời, mỗi mục **cần kiểm tra**): (a) macOS và Xcode đang cài là bản nào, hoặc có được tự cài Xcode không (quyền quản trị, Internet, dung lượng trống).
   Xu cần Xcode đủ mới để build (CI của Xu chạy trên máy `macos-15` của GitHub, `.github/workflows/ci.yml`; bản Xcode tối thiểu: chưa kiểm) và Xcode phải hỗ trợ bản iOS đang chạy trên iPhone của bạn;
   (b) có được đăng nhập Apple ID của bạn trong Xcode và cắm iPhone của bạn không; (c) khi trả máy, nơi cho thuê có xoá sạch tài khoản và dữ liệu không (để biết phải tự dọn những gì);
   (d) thời gian thuê tối thiểu, tiền cọc, giờ nhận và trả.
2. **iPhone và cáp.** iOS 17 trở lên (`deploymentTarget` trong `project.yml`); Control Center control cần iOS 18 (`docs/06`). Mang đúng loại **cáp** nối iPhone với cổng của Mac (USB‑C hay Lightning).
3. **Apple ID cho Xcode.** Máy thuê không phải của bạn: nên dùng một Apple ID riêng cho việc này (bạn quyết), có sẵn thiết bị hoặc số điện thoại để nhận mã khi Xcode đòi xác thực.
   Đừng chọn lưu mật khẩu trong trình duyệt của máy thuê; khi trả máy phải đăng xuất Apple ID khỏi Xcode (giai đoạn 3).
4. **Ảnh biên lai để đo Vision** (`docs/11`): ≥ 50 ảnh từ 5 ngân hàng/ví, để trong **Ảnh** của iPhone và đọc ngay trên iPhone. Biên lai thật có tên người và số tiền: **không** đưa lên GitHub, chat hay máy thuê.
5. **Apple Pay.** Chuẩn bị ≥ 6 giao dịch nhỏ thật bằng thẻ trong Wallet (5 lượt miễn phí mỗi tháng + 1 để thấy thẻ "chưa được tự ghi", `docs/12`). Nơi bạn ở dùng được Apple Pay không, và automation "Giao dịch"
   trong Phím tắt có chạy nền không: **cần kiểm tra**. Chưa quẹt được thì thử tạm bằng tay: tạo một phím tắt thường với hành động **Ghi giao dịch thẻ** của Xu (ô "Số tiền", "Người bán") rồi chạy 6 lần để xem
   hạn mức và danh sách chờ (chưa ai thử; chỉ thử phần hạn mức, không thay cho thử automation thật).
6. **Mã nguồn.** Repo `xu-ios` đang là repo **công khai** (kiểm 2026-10-10), nên máy thuê chạy `git clone https://github.com/vohoailinh90/xu-ios` mà không cần đăng nhập GitHub; nếu sau này đổi sang riêng tư thì
   cần cách khác. **Đừng đăng nhập GitHub hay dán token trên máy thuê.** Cần `git` (thường đi kèm công cụ dòng lệnh của Xcode: cần kiểm tra) và `xcodegen` (`brew install xcodegen` cần Homebrew và Internet;
   máy chưa có Homebrew thì cài thêm mất thời gian, chưa đo).

## Giai đoạn 1 — Dựng được app lên iPhone (ngày đầu)

Mục tiêu: Xu chạy trên iPhone, ghi được một khoản, widget thêm được. Cùng các bước của `docs/12` đường A, theo thứ tự:

1. Xem phiên bản macOS và Xcode của máy; mở Xcode một lần để nó hoàn tất cài đặt ban đầu nếu cần. Chưa có Xcode thì tải và cài (phụ thuộc đường truyền; mình không ước lượng giờ).
2. `git clone https://github.com/vohoailinh90/xu-ios`, rồi trong thư mục đó: `brew install xcodegen`, `xcodegen generate`, mở `Xu.xcodeproj`, chọn scheme **Xu**.
3. Đăng nhập Apple ID trong Xcode (Settings › Accounts; tên mục theo bản Xcode). Ở Signing & Capabilities của **Xu** và **XuWidgets**, chọn Team cá nhân (Personal Team).
4. Cắm iPhone, chọn "Tin cậy"; bật **Chế độ nhà phát triển** (Cài đặt › Quyền riêng tư & Bảo mật; iPhone khởi động lại; tên mục theo bản iOS); chọn iPhone làm thiết bị chạy; bấm Run.
5. iPhone báo nhà phát triển không tin cậy: Cài đặt › Cài đặt chung › VPN & Quản lý thiết bị, tin cậy hồ sơ của bạn (tên mục theo bản iOS).

**Xong khi:** app mở được trên iPhone; gõ "cà phê 35k" thì ghi được và thấy trong danh sách; thêm widget khoản quen vào màn hình chính và chạm một nút thì ghi được (`docs/06`, M2).

**Nếu có lỗi:** chép **nguyên văn** thông báo (không chụp dữ liệu thật). Những chỗ có thể vướng, đều **chưa ai thử**:
- Giới hạn tài khoản miễn phí (10 App ID mỗi 7 ngày, 3 app mỗi thiết bị, `docs/12`). Định danh đã đặt sẵn: **đừng đổi bundle ID khi đang thử**.
- App Group: bảng của Apple ghi tài khoản miễn phí dùng được, nhưng chưa ai thử với Xu. Mất entitlement này thì app sập khi mở (`SharedStore.container` gọi `fatalError`, xem `docs/12` Đường D): ghi lại nguyên văn.
- Xcode không hỗ trợ bản iOS của iPhone, hoặc quá cũ để build Xu: ghi phiên bản Xcode và iOS (đây là lý do phải hỏi trước, mục 1).

Chưa qua được thì ghi lại rồi quyết định: thuê thêm ngày, đổi máy thuê, hay đi đường B (99 USD mỗi năm, `docs/12`). Chi phí cụ thể lúc đó do bạn cân nhắc.

## Giai đoạn 2 — Thử theo danh sách (các ngày giữa)

Ghi mỗi mục vào bảng cuối trang (đạt / không đạt + nguyên văn lỗi); số đo Vision ghi vào `docs/11`. Làm **trước** những mục dễ lộ lỗi phải sửa code rồi cài lại, vì chỉ cài lại được khi còn Mac;
mục cần đời thật để dành cho phần "Sau khi trả máy".

1. **Vision với ≥ 50 ảnh thật, 5 ngân hàng/ví** (chỉ bản Debug): Cài đặt › **Thử đọc biên lai**, theo `docs/11`.
2. **Nhập nhiều biên lai** (bản Debug): chọn nhiều ảnh, hạn mức 5 ảnh/tháng, ảnh trùng, thẻ "không chắc".
3. **Apple Pay chạy nền** (`docs/12`, mục "Việc cần thử trên máy thật" số 1): theo màn hướng dẫn Cài đặt › Nhập nhanh hơn; quẹt tới khi hết 5 lượt; Home phải hiện thẻ "Khoản Apple Pay chưa được tự ghi".
   Ghi lại lời nhắn của tác vụ và thông báo có hiện khi chạy nền không.
4. **Tác vụ nền thêm khoản lúc danh sách chờ đang mở** (`docs/12`, mục số 2).
5. Nếu còn thời gian: Control Center control (iOS 18: thêm nút, chạm khi app đóng và khi app đang mở màn khác, `docs/06`); gán "Ghi chi tiêu" vào Action Button; thông báo nhắc buổi tối có nút;
   đo thời gian ghi (Cài đặt › Nhập nhanh hơn, `docs/06`); thử mua Xu Pro cục bộ (cần tạo tệp StoreKit configuration trong Xcode với sản phẩm không tiêu hao `com.vohoailinh90.xu.pro` và chọn trong scheme, `docs/12` mục 3; chưa ai thử).

**Khi thử lộ lỗi:** ghi triệu chứng hoặc nguyên văn lỗi (không chụp dữ liệu thật) và báo mình; mình sửa trong repo và nói nhánh nào; trên máy thuê `git pull` nhánh đó, `xcodegen generate`, chọn lại Team (project được sinh lại), Run lại.

## Giai đoạn 3 — Ghi lại, dọn máy, trả máy

1. Ghi kết quả vào bảng cuối trang và `docs/11`; ghi phiên bản macOS, Xcode, iOS và đời iPhone.
2. Dọn máy thuê (tên mục theo bản Xcode/macOS, **cần kiểm tra**): đăng xuất Apple ID khỏi Xcode (Settings › Accounts); xoá thư mục `xu-ios` và dữ liệu build của Xcode (DerivedData);
   xoá iPhone khỏi danh sách thiết bị của Xcode (Window › Devices and Simulators); đóng mọi phiên đăng nhập trong trình duyệt; đăng xuất iCloud và App Store nếu từng đăng nhập trên máy.
3. Trên iPhone: không cần gỡ app (xem hạn 7 ngày ở trên). iPhone đã "Tin cậy" máy thuê; cách thu hồi việc đó, và việc nó có đặt lại các quyền khác không: **cần kiểm tra** trước khi làm.

## Sau khi trả máy (trong hạn 7 ngày của hồ sơ)

Dùng Xu như bình thường và thử những thứ cần đời thật: Apple Pay ngoài cửa hàng nếu chưa đủ 6 lượt, nhắc buổi tối (mặc định 21:00, `docs/05`), widget và Control Center trong ngày. Ghi vào bảng.
Việc nào lộ lỗi cần sửa code thì phải có Mac mới cài lại: gom lại cho một lượt thuê sau, hoặc cân nhắc đường B (99 USD mỗi năm, `docs/12`).

## Bảng kết quả (điền sau khi thử)

| Mục | Kết quả (đạt / không đạt / chưa thử) | Ghi chú (nguyên văn lỗi, không có dữ liệu thật) |
|---|---|---|
| Build và ký bằng tài khoản miễn phí (cả Xu và XuWidgets) | | |
| Ghi "cà phê 35k"; widget khoản quen | | |
| Vision ≥ 50 ảnh, 5 ngân hàng/ví (`docs/11`) | | |
| Nhập nhiều biên lai | | |
| Apple Pay chạy nền: 5 lượt + thẻ chờ | | |
| Thêm khoản lúc danh sách chờ đang mở | | |
| Control Center control (iOS 18) | | |
| Số ngày thuê thật / tổng chi phí thuê | | |
