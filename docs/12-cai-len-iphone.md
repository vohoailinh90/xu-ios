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
   In-App Purchase, Push notifications, iCloud và Siri. Với Xu: **mua** Xu Pro qua Sandbox/TestFlight cần tài khoản trả phí (In-App Purchase không có ở cột miễn phí, và sản phẩm phải tạo trong App Store Connect).
   Thử **cục bộ** bằng tệp cấu hình StoreKit (`.storekit`) của Xcode thì khác: Apple mô tả đây là môi trường thử không cần kết nối máy chủ App Store, dùng được khi
   chưa thiết lập app trong App Store Connect, và trang đó không nói phải trả phí. Repo **chưa có** tệp này (cần thêm một sản phẩm không tiêu hao với mã `com.example.xu.pro`,
   hoặc mã bạn đã đổi, rồi chọn tệp trong tuỳ chọn chạy của scheme); chưa ai thử trên Xu.
   Thông báo của Xu là thông báo cục bộ nên không cần Push; iCloud thuộc v1.1, chưa làm; `project.yml` không khai báo Siri.
   **Chưa ai thử ký Xu bằng tài khoản miễn phí** (có thể vướng giới hạn 10 App ID mỗi 7 ngày hoặc lỗi khác): nếu Xcode báo lỗi thì ghi lại nguyên văn.
4. **Apple Developer Program** (trả phí): **99 USD mỗi năm**, tính bằng tiền địa phương nếu có; giá có thể khác theo khu vực và chỉ hiện bằng tiền địa phương lúc đăng ký
   (Apple không ghi sẵn số tiền đồng hay yên). Các trang Apple đã đọc (2026-10-06) chỉ nói theo **năm**, không có gói theo tháng; chia đều chỉ là cách tính cho dễ hình dung
   (99 / 12 ≈ 8,25 USD mỗi tháng), vẫn phải trả cả năm một lần. Đăng ký bằng app Apple Developer thì là thuê bao năm **tự gia hạn cho tới khi huỷ**; đăng ký trên web thì chọn
   cách thanh toán Apple đưa ra. Đăng ký cá nhân bằng thẻ tín dụng phải dùng thẻ của chính bạn, nếu không việc đăng ký bị chậm và Apple đòi bản sao giấy tờ tuỳ thân có ảnh;
   nếu khu vực của bạn không có sản phẩm Apple Developer ở Apple Store Online thì Apple đưa biểu mẫu thẻ tín dụng thanh toán được bằng USD (nguồn bên dưới).
   Có TestFlight, App Store Connect, Xcode Cloud và In-App Purchase (để thử mua Xu Pro qua Sandbox/TestFlight). Dù sao cũng cần khi nộp App Store (`docs/10`).
   Giá và điều khoản: **cần kiểm tra lại lúc đăng ký**.

## Chọn đường

| Bạn có | Đường | Ghi chú |
|---|---|---|
| Mac + iPhone | **A.** Cắm cáp, chạy từ Xcode | Nhanh nhất. Bản Debug có màn thử đọc biên lai (`docs/11`). Tài khoản miễn phí đủ để thử Apple Pay và đọc biên lai (chưa ai thử); thử mua Xu Pro cục bộ bằng tệp `.storekit` (chưa có trong repo), còn Sandbox/TestFlight cần trả phí |
| iPhone, không Mac, chịu trả phí | **B.** CI build → TestFlight | Cần thêm workflow (chưa có). Bản TestFlight là Release nên **không có** màn Debug |
| Chỉ iPhone, không Mac, không trả phí | **C.** Không chạy được Xu | Chỉ còn thử Vision bằng ảnh dựng sẵn trên CI (spike, `docs/11`). Không đưa biên lai thật lên GitHub (có tên, số tài khoản) |

**Tình hình hiện tại (chủ dự án, 2026-10-06): có Mac, chưa đăng ký tài khoản trả phí.** Đề xuất: bắt đầu bằng **đường A với tài khoản Apple miễn phí** (thêm Apple Account trong
Xcode, mục Accounts của phần cài đặt Xcode; tên mục cần kiểm tra theo bản Xcode). Chưa cần trả phí để thử Apple Pay automation và màn đọc biên lai. Đăng ký trả phí khi cần
TestFlight cho 20–50 người thử (`docs/06`, M4), thử mua Xu Pro qua Sandbox, hoặc khi chuẩn bị nộp App Store. Chưa ai thử ký Xu bằng tài khoản miễn phí: nếu Xcode báo lỗi ký thì
ghi lại nguyên văn rồi mới quyết định trả phí.

## Đường A — có Mac

1. Cài Xcode (App Store) và `brew install xcodegen`; clone repo.
2. Đổi định danh thành của bạn (đã ghi trong `project.yml`): `bundleIdPrefix`, `PRODUCT_BUNDLE_IDENTIFIER` của app và widget, App Group
   (2 chỗ trong `project.yml` **và** `appGroupID` ở `App/Shared/Persistence/SharedStore.swift`, phải khớp nhau), `DEVELOPMENT_TEAM` (Team ID của bạn).
   Mã sản phẩm mua `com.example.xu.pro` (`ProEntitlement.productID`) chỉ cần đổi khi thử mua Xu Pro.
3. `xcodegen generate`, mở `Xu.xcodeproj`, chọn scheme **Xu**.
4. Cắm iPhone, chọn "Tin cậy máy tính này". Bật **Chế độ nhà phát triển** trên iPhone (Cài đặt › Quyền riêng tư & Bảo mật; mục này chỉ hiện sau khi Xcode
   nhận máy; Apple nói cần bật trên iOS 16 trở lên, còn tên mục **cần kiểm tra** theo bản iOS của bạn). Chọn iPhone làm thiết bị chạy, bấm Run.
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

## Nguồn (Apple, đọc 2026-10-04 và 2026-10-06)

- [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios): bảng capability theo loại thành viên (đọc thẳng từ HTML của trang): App groups ✓ cả ba cột; In-App Purchase, Push notifications, iCloud, Siri không có ở cột miễn phí.
- [StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode): thử mua cục bộ bằng tệp `.storekit`, không cần kết nối máy chủ App Store, dùng được khi chưa thiết lập app trong App Store Connect; nhắc bật Chế độ nhà phát triển trên iOS 16 trở lên.
- [So sánh thành viên miễn phí và trả phí](https://developer.apple.com/support/compare-memberships/): chạy trên máy của mình từ Xcode, giới hạn tài khoản miễn phí, TestFlight/App Store Connect/Xcode Cloud chỉ cho tài khoản trả phí.
- [TestFlight](https://developer.apple.com/testflight/): số người thử nội bộ/bên ngoài, số thiết bị, App Review cho bản đầu của người thử bên ngoài.
- [Apple Developer Program](https://developer.apple.com/programs/), [Enroll](https://developer.apple.com/programs/enroll/) và [Program enrollment](https://developer.apple.com/help/account/membership/program-enrollment/) (đọc thẳng HTML 2026-10-06): phí 99 USD mỗi năm (Enterprise 299 USD), tính bằng tiền địa phương nếu có và hiện lúc đăng ký; đăng ký bằng app Apple Developer là thuê bao năm tự gia hạn; đăng ký cá nhân bằng thẻ tín dụng phải dùng thẻ của chính bạn.
