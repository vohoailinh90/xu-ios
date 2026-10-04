# 12 — Cài Xu lên iPhone thật để thử

> Viết 2026-10-04 để trả lời câu hỏi của chủ dự án: "làm sao cài app trên iPhone thật để chạy thử". **Chưa ai chạy thử các bước này trên repo này.**
> Thông tin về Apple lấy từ các trang Apple ghi ở cuối (đọc 2026-10-04). Điều khoản, giá và giới hạn của Apple đổi thường xuyên nên
> **cần kiểm tra văn bản mới nhất** trước khi trả tiền hay làm theo. Không phải tư vấn pháp lý.

## Bốn điều cần biết trước

1. **Build app iOS cần macOS + Xcode**, không có đường nào khác. Xu đã build được trên máy Mac của GitHub Actions (`macos-15`, `.github/workflows/ci.yml`),
   nhưng CI hiện chỉ chạy `swift test` và dựng cho trình mô phỏng; **không** tạo bản cài lên iPhone.
2. Tài khoản Apple **miễn phí** chạy được app lên iPhone của chính mình từ Xcode. Theo trang so sánh của Apple: hồ sơ cấp phép hết hạn sau 7 ngày (phải cài lại),
   tối đa 3 thiết bị, 3 app mỗi thiết bị, 10 App ID; không có TestFlight, App Store Connect, Xcode Cloud.
3. **Xu cần App Group** (`group.com.example.xu`: app, widget và App Intents dùng chung kho dữ liệu; đây là entitlement duy nhất `project.yml` khai báo).
   Bảng [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios) của Apple có ba cột: ADP (trả phí),
   ADEP (Enterprise, trả phí) và **Apple Developer** (tài khoản Apple đã đồng ý Thoả thuận nhà phát triển, miễn phí, không phân phối được app).
   Hàng *App groups* có dấu ✓ ở **cả ba cột**, nên theo Apple, **App Group không buộc phải trả phí**. Cũng theo bảng đó, cột miễn phí **không có**
   In-App Purchase, Push notifications, iCloud và Siri. Với Xu: không thử được **mua** Xu Pro (In-App Purchase) bằng tài khoản miễn phí (cách thử bằng tệp
   cấu hình StoreKit của Xcode: cần kiểm tra); thông báo của Xu là thông báo cục bộ nên không cần Push; iCloud thuộc v1.1, chưa làm; `project.yml` không khai báo Siri.
   **Chưa ai thử ký Xu bằng tài khoản miễn phí** (có thể vướng giới hạn 10 App ID mỗi 7 ngày hoặc lỗi khác): nếu Xcode báo lỗi thì ghi lại nguyên văn.
4. **Apple Developer Program** (trả phí): 99 USD mỗi năm, hoặc tiền địa phương nếu có (theo trang chương trình của Apple; **cần kiểm tra giá hiện tại**
   ở Việt Nam/Nhật). Có TestFlight, App Store Connect, Xcode Cloud và In-App Purchase (để thử mua Xu Pro). Dù sao cũng cần khi nộp App Store (`docs/10`).

## Chọn đường

| Bạn có | Đường | Ghi chú |
|---|---|---|
| Mac + iPhone | **A.** Cắm cáp, chạy từ Xcode | Nhanh nhất. Bản Debug có màn thử đọc biên lai (`docs/11`). Tài khoản miễn phí đủ để thử Apple Pay và đọc biên lai (chưa ai thử); thử mua Xu Pro cần trả phí |
| iPhone, không Mac, chịu trả phí | **B.** CI build → TestFlight | Cần thêm workflow (chưa có). Bản TestFlight là Release nên **không có** màn Debug |
| Chỉ iPhone, không Mac, không trả phí | **C.** Không chạy được Xu | Chỉ còn thử Vision bằng ảnh dựng sẵn trên CI (spike, `docs/11`). Không đưa biên lai thật lên GitHub (có tên, số tài khoản) |

## Đường A — có Mac

1. Cài Xcode (App Store) và `brew install xcodegen`; clone repo.
2. Đổi định danh thành của bạn (đã ghi trong `project.yml`): `bundleIdPrefix`, `PRODUCT_BUNDLE_IDENTIFIER` của app và widget, App Group
   (2 chỗ trong `project.yml` **và** `appGroupID` ở `App/Shared/Persistence/SharedStore.swift`, phải khớp nhau), `DEVELOPMENT_TEAM` (Team ID của bạn).
   Mã sản phẩm mua `com.example.xu.pro` (`ProEntitlement.productID`) chỉ cần đổi khi thử mua Xu Pro.
3. `xcodegen generate`, mở `Xu.xcodeproj`, chọn scheme **Xu**.
4. Cắm iPhone, chọn "Tin cậy máy tính này". Bật **Chế độ nhà phát triển** trên iPhone (Cài đặt › Quyền riêng tư & Bảo mật; mục này chỉ hiện sau khi Xcode
   nhận máy, iOS 16 trở lên; **cần kiểm tra** theo bản iOS của bạn). Chọn iPhone làm thiết bị chạy, bấm Run.
5. Nếu iPhone báo nhà phát triển không tin cậy: Cài đặt › Cài đặt chung › VPN & Quản lý thiết bị, tin cậy hồ sơ của bạn (cần kiểm tra tên mục theo iOS).
6. Run mặc định là **Debug**: có Cài đặt › **Thử đọc biên lai** và **Nhập nhiều biên lai** (cách dùng ở `docs/11`).

## Đường B — không có Mac, có tài khoản trả phí

1. Đăng ký Apple Developer Program (Apple có thể cần xác minh danh tính; cần kiểm tra thời gian và giấy tờ).
2. Đổi định danh như bước 2 của đường A (sửa file trong repo, không cần Mac).
3. Trong App Store Connect: tạo app với bundle ID đó; tạo khoá API cho CI (lưu tệp `.p8`, Key ID, Issuer ID vào GitHub Secrets).
4. Thêm workflow chạy tay (`workflow_dispatch`) trên máy Mac của GitHub: `xcodegen generate` → archive → tải lên App Store Connect bằng khoá API.
   **Chưa có trong repo.** Tôi chưa viết vì không thể thử khi chưa có tài khoản và khoá API; viết khi bạn chọn đường này.
5. TestFlight: thêm chính bạn làm người thử nội bộ (tối đa 100 thành viên trong đội có vai trò Account Holder, Admin, App Manager, Developer hoặc Marketing,
   theo trang TestFlight), rồi cài app TestFlight trên iPhone và cài Xu. Người thử bên ngoài (tối đa 10.000) cần build đầu được App Review duyệt cho TestFlight.
   Trang TestFlight không nói rõ người thử nội bộ có phải qua App Review không: cần kiểm tra.
6. Bản này là Release: **không có** các màn Debug. Muốn đo Vision bằng ảnh thật trên TestFlight thì cần thêm một cờ build riêng (chưa làm).

## Việc cần thử trên máy thật (khi đã cài được)

1. **Apple Pay chạy nền.** Làm theo màn hướng dẫn (Cài đặt › Nhập nhanh hơn), quẹt một khoản nhỏ thật, kiểm tra khoản có trong danh sách. Quẹt tiếp tới khi
   hết 5 lượt trong tháng: Home phải hiện thẻ "Khoản Apple Pay chưa được tự ghi", danh sách có khoản đó. Ghi lại lời nhắn của tác vụ và thông báo
   (nếu đã cho phép) có hiện khi chạy nền không (`docs/02`, `docs/06`).
2. **Tác vụ nền thêm khoản lúc danh sách đang mở.** Mở danh sách khoản chờ, rồi quẹt thêm một khoản: danh sách phải cập nhật, không mất khoản nào.
3. **Vision với ≥ 50 ảnh thật, 5 ngân hàng/ví** (chỉ bản Debug, đường A): theo `docs/11`; ghi kết quả vào đó.
4. **Nhập nhiều biên lai** (bản Debug): chọn nhiều ảnh, hạn mức 5 ảnh/tháng, ảnh trùng, thẻ "không chắc".

Biên lai và khoản thật có tên người, số tiền: không chụp màn hình gửi lên GitHub hay chat.

## Nguồn (Apple, đọc 2026-10-04)

- [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios): bảng capability theo loại thành viên (đọc thẳng từ HTML của trang): App groups ✓ cả ba cột; In-App Purchase, Push notifications, iCloud, Siri không có ở cột miễn phí.
- [So sánh thành viên miễn phí và trả phí](https://developer.apple.com/support/compare-memberships/): chạy trên máy của mình từ Xcode, giới hạn tài khoản miễn phí, TestFlight/App Store Connect/Xcode Cloud chỉ cho tài khoản trả phí.
- [TestFlight](https://developer.apple.com/testflight/): số người thử nội bộ/bên ngoài, số thiết bị, App Review cho bản đầu của người thử bên ngoài.
- [Apple Developer Program](https://developer.apple.com/programs/): phí thành viên (qua kết quả tìm kiếm; cần mở trang để kiểm tra giá hiện tại).
