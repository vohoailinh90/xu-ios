# 12 — Cài Xu lên iPhone thật để thử

> Viết 2026-10-04 để trả lời câu hỏi của chủ dự án: "làm sao cài app trên iPhone thật để chạy thử". **Chưa ai chạy thử các bước này trên repo này.**
> Thông tin về Apple lấy từ các trang Apple ghi ở cuối (đọc 2026-10-04, 06 và 10). Điều khoản, giá và giới hạn của Apple đổi thường xuyên nên
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
   Thuế: khi áp dụng, Apple tính thuế theo mức của khu vực của bạn lên khoản mua (trang Program enrollment), nên số tiền thanh toán có thể cao hơn giá niêm yết.
   Giá và điều khoản: **cần kiểm tra lại lúc đăng ký**.

## Chọn đường

| Bạn có | Đường | Ghi chú |
|---|---|---|
| iPhone + Mac (của bạn hoặc mượn được) | **A.** Cắm cáp, chạy từ Xcode | Nhanh nhất. Bản Debug có màn thử đọc biên lai (`docs/11`). Tài khoản miễn phí đủ để thử Apple Pay và đọc biên lai (chưa ai thử); thử mua Xu Pro cục bộ bằng tệp `.storekit` (chưa có trong repo), còn Sandbox/TestFlight cần trả phí |
| iPhone, không Mac, chịu trả phí | **B.** CI build → TestFlight | Không cần Mac nào của bạn; cần tài khoản trả phí và một workflow (chưa có). Bản TestFlight là Release nên **không có** màn Debug |
| iPhone, không Mac, không trả phí | **C.** Chưa có cách đã kiểm để cài Xu | Chỉ thử từng phần (mục "Thử từng phần khi chưa cài được app"). Đường D (công cụ bên thứ ba) chưa kiểm, không khuyến nghị |

**Tình hình hiện tại (chủ dự án): 2026-10-06 nói có Mac; 2026-10-10 nói không có Mac. Chưa đăng ký tài khoản trả phí.** Theo tin mới nhất là không có Mac, nên đường A chỉ dùng được khi
mượn được một máy Mac (tài khoản miễn phí, hồ sơ hết hạn sau 7 ngày nên mỗi tuần phải cài lại, tức mỗi lần lại cần Mac). Không mượn được thì đường đã rõ là **B (99 USD mỗi năm)**; khoản này
dù sao cũng cần khi làm TestFlight cho 20–50 người thử (`docs/06`, M4) và khi nộp App Store. Apple chỉ cho build iOS trên macOS: máy Mac đó có thể là máy mượn hoặc máy của GitHub (CI).

## Đường A — có Mac (của bạn hoặc mượn được)

Mượn Mac: nên dành thời gian rộng rãi, vì cài Xcode, thiết lập ký (signing) và xử lý App Group phụ thuộc máy và đường truyền, và chưa ai thử trên repo này nên mình không ước lượng số giờ; tài khoản miễn phí thì hồ sơ hết hạn sau 7 ngày nên phải làm lại mỗi tuần. Thuê Mac từ xa (dịch vụ đám mây) **không** thay được
việc cắm iPhone của bạn vì Xcode cần iPhone nối cáp hoặc cùng mạng với Mac (mình chưa kiểm cách nào khác); thuê chỉ giúp build và đưa lên TestFlight (cần tài khoản trả phí). Việc đó CI của GitHub **có thể** làm sau khi thêm và kiểm workflow ký/archive/tải lên; hiện CI chỉ build Debug cho trình mô phỏng, không ký (`.github/workflows/ci.yml`), nên **chưa** làm được.

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

Các bước phía Apple làm được trên web hoặc trên iPhone, không cần Mac.

1. **Đăng ký Apple Developer Program** (99 USD mỗi năm, mục 4 ở trên). Điều kiện (trang Program enrollment): Apple Account bật xác thực hai yếu tố và đủ tuổi thành niên theo khu vực của bạn.
   **Cá nhân** (hoặc chủ doanh nghiệp một người): tên pháp lý của bạn sẽ hiện là người bán trên App Store, không nhập biệt danh hay tên công ty. Có hai cách đăng ký: bằng **app Apple Developer**
   trên iPhone, iPad hoặc Mac (dùng cùng một thiết bị suốt quá trình; xác minh danh tính bằng ảnh giấy tờ tuỳ thân có ảnh, Apple nhận hộ chiếu ở hầu hết khu vực), hoặc trên web. Sau khi thanh toán
   bạn nhận email xác nhận; quá 24 giờ chưa có thì liên hệ Apple kèm Enrollment ID (theo trang Program enrollment). **Tổ chức** (công ty) thì cần pháp nhân và số D-U-N-S, có thêm bước xác minh khác;
   không áp dụng nếu bạn đăng ký cá nhân. **Khu vực:** Apple ghi app Apple Developer có ở các khu vực App Store hỗ trợ nhưng việc đăng ký có thể không được hỗ trợ ở một số khu vực (ví dụ do lệnh
   trừng phạt hay hạn chế khác); trang không có danh sách, và không bảo đảm đăng ký trên web giải quyết được. Khu vực của bạn đăng ký được hay không: **cần kiểm tra** khi thử.
2. **Chọn định danh của bạn** (tiền tố bundle ID, tên App Group) và gửi mình **Team ID** của tài khoản (10 ký tự, xem trong phần Membership details của tài khoản developer; vị trí trong giao diện
   cần kiểm tra; Team ID không phải bí mật). Mình sửa trong repo (không cần Mac): đổi định danh và đặt Team ID vào `DEVELOPMENT_TEAM` của `project.yml`, hiện đang để trống; thiếu Team ID thì ký tự động
   trong CI không biết ký cho đội nào. Định danh phải khác mọi app khác; không cần có tên miền.
3. Trong **Certificates, Identifiers & Profiles** (web, cần tài khoản trả phí), đăng ký trước các định danh của Xu (khớp `project.yml`): (a) hai **explicit App ID**, một cho app
   (`<tiền-tố>.xu`) và một cho widget (`<tiền-tố>.xu.widgets`); (b) một **App Group** (`group.<tiền-tố>.xu`); (c) bật capability App Groups cho cả hai App ID rồi gán App Group đó (nút Configure).
   Theo các trang Apple (Register an App ID, Register an app group, Enable app capabilities): App ID loại explicit dùng cho đúng một app và phải khớp bundle ID trong Xcode; In-App Purchase
   mặc định bật cho explicit App ID. Ký tự động trong CI **có thể** tự đăng ký các thứ này, nhưng mình **chưa kiểm**, nên đăng ký tay trước cho chắc.
4. Trong App Store Connect (web): tạo app record, chọn bundle ID của app đã đăng ký ở bước 3 (app record phải gắn với một explicit App ID; cần kiểm tra khi làm).
5. **Xin quyền dùng App Store Connect API rồi tạo khoá API cho CI.** Theo trang Apple (App Store Connect API, Creating API Keys): chỉ **Account Holder** xin được quyền: Users and Access › Integrations ›
   Request Access, đồng ý điều khoản, Submit; Apple xét duyệt từng trường hợp (thời gian chờ: **cần kiểm tra**). Có quyền rồi, Account Holder hoặc Admin tạo **team API key** (tab Team Keys, Generate API Key),
   **không** phải khoá cá nhân vì Apple ghi khoá cá nhân không dùng được các endpoint Provisioning. Vai trò của khoá phải đủ để tạo chứng chỉ và hồ sơ cấp phép (Admin là rộng nhất; vai trò tối thiểu cần dùng:
   **cần kiểm tra**). Tệp `.p8` chỉ tải được **một lần** và Apple không giữ bản sao: tải xong cất kỹ, rồi lưu `.p8`, Key ID, Issuer ID vào GitHub Secrets. **Không dán khoá vào chat và không commit vào repo.**
   Ký tự động bằng khoá API trong CI (tạo chứng chỉ và hồ sơ cấp phép không cần Xcode trên máy bạn) là cách mình định dùng nhưng **chưa kiểm**: cần kiểm tra khi chạy thật.
6. **Chuẩn bị trong repo (mình làm, chưa làm):** (a) **biểu tượng app**: repo hiện không có asset catalog hay `AppIcon`; trang Preparing your app for distribution của Apple liệt kê app icon là thông tin cần có
   trước khi tải build lên TestFlight hoặc App Store (dùng tệp Icon Composer hoặc asset catalog). Mình tạo biểu tượng tạm và nối vào target; biểu tượng thật do bạn quyết; (b) **chuỗi build duy nhất** cho mỗi lần tải
   lên: `CURRENT_PROJECT_VERSION` đang là "1", còn Apple dùng chuỗi build để nhận diện duy nhất từng build (trang Upload builds); (c) **khai báo mã hoá xuất khẩu** trong Info.plist (khoá
   `ITSAppUsesNonExemptEncryption`; tên khoá cần kiểm tra): Apple nói đặt NO nếu app không dùng mã hoá hoặc chỉ dùng loại được miễn; Xu không tự cài mã hoá riêng, nhưng thuộc diện miễn hay không là câu hỏi
   tuân thủ xuất khẩu, **cần kiểm tra văn bản mới nhất**, mình không tự kết luận.
7. Mình viết workflow chạy tay (`workflow_dispatch`) trên máy Mac của GitHub: `xcodegen generate` → archive → tải lên App Store Connect. Trang Upload builds của Apple liệt kê các công cụ tải lên:
   Xcode, Swift Playground, altool, Transporter (có bản dòng lệnh, xác thực bằng JWT), API và Xcode Cloud; nên tải lên từ CI không cần Xcode trên máy bạn. **Chưa có trong repo.** Mình sửa dần
   bằng cách đọc log Actions sau khi bạn thêm secrets và bấm chạy.
8. TestFlight (App Store Connect › app › tab TestFlight), theo trang Add internal testers của Apple: tạo một nhóm **Internal Testing** (nút + cạnh Internal Testing); ô "Enable automatic distribution" bật thì
   Xcode tự giao build cho cả nhóm, không bật thì phải thêm từng build vào nhóm bằng tay. Mời chính bạn vào nhóm: người thử nội bộ phải là người dùng App Store Connect có quyền (Account Holder, Admin,
   App Manager, Developer hoặc Marketing), tối đa 100 người. Khi đã có build sẵn để thử, bạn nhận email mời và mở bằng app TestFlight trên iPhone; chỉ các build đã được giao cho nhóm mới cài được, và người thử
   nội bộ tải và thử các build đó trong 90 ngày. Trang Apple nói "tự giao" cho trường hợp Xcode tải lên; build tải lên từ CI có được tự giao không thì **cần kiểm tra**, nên chuẩn bị sẵn thao tác thêm build bằng tay.
   Theo trang TestFlight, App Review chỉ được nhắc khi **mời người thử bên ngoài** (tối đa 10.000): build đầu của app khi đó được gửi cho App Review, các build sau có thể không cần duyệt đầy đủ. Trang không
   nói người thử nội bộ phải qua bước này (cần kiểm tra khi làm).
9. Bản này là Release: **không có** các màn Debug. Muốn đo Vision bằng ảnh thật trên TestFlight thì cần thêm một cờ build riêng (chưa làm).

## Đường D — ký lại bằng công cụ bên thứ ba (chưa kiểm, không khuyến nghị)

Có công cụ bên thứ ba (kiểu AltStore, Sideloadly) ký lại một tệp IPA bằng Apple ID miễn phí từ máy Windows. Mình **chưa kiểm** và không khuyến nghị làm đầu tiên: (1) phải đưa Apple ID vào phần
mềm bên thứ ba; (2) CI sẽ phải tạo IPA chưa ký, mà `SharedStore.container` gọi `fatalError` nếu không tạo được kho dữ liệu trong App Group, nên nếu việc ký lại làm mất entitlement App Group
thì app sập khi mở; (3) hồ sơ miễn phí vẫn hết hạn sau 7 ngày. Chỉ cân nhắc khi không có Mac và không muốn trả phí, và nên dùng một Apple ID riêng cho việc này.

## Thử từng phần khi chưa cài được app

- **Đọc chữ biên lai:** `prototypes/cham-bien-lai.html` cùng Văn bản trực tiếp (Live Text) hoặc Phím tắt đọc chữ từ ảnh trên chính iPhone, cách đã cho ra mốc sơ bộ 39/39 số tiền ở `docs/11` (ở đó chưa ghi dùng cách nào trong hai cách). Đây là số đo **gần đúng**,
  không phải Vision trong app (`docs/11` nói rõ); làm tiếp tới ≥ 50 ảnh/5 ngân hàng/ví.
- **Vision trên CI:** spike `scripts/spike-ocr.swift` chạy trên máy Mac của GitHub với ảnh dựng sẵn (`.github/workflows/spike-ocr.yml`, `docs/11`). Không đưa biên lai thật lên GitHub.
- Apple Pay chạy nền và danh sách khoản chờ **không** thử được nếu chưa có app trên máy.

## Việc cần thử trên máy thật (khi đã cài được)

1. **Apple Pay chạy nền.** Làm theo màn hướng dẫn (Cài đặt › Nhập nhanh hơn), quẹt một khoản nhỏ thật, kiểm tra khoản có trong danh sách. Quẹt tiếp tới khi
   hết 5 lượt trong tháng: Home phải hiện thẻ "Khoản Apple Pay chưa được tự ghi", danh sách có khoản đó. Ghi lại lời nhắn của tác vụ và thông báo
   (nếu đã cho phép) có hiện khi chạy nền không (`docs/02`, `docs/06`).
2. **Tác vụ nền thêm khoản lúc danh sách đang mở.** Mở danh sách khoản chờ, rồi quẹt thêm một khoản: danh sách phải cập nhật, không mất khoản nào.
3. **Vision với ≥ 50 ảnh thật, 5 ngân hàng/ví** (chỉ bản Debug: đường A; đường B cần cờ build riêng): theo `docs/11`; ghi kết quả vào đó.
4. **Nhập nhiều biên lai** (bản Debug): chọn nhiều ảnh, hạn mức 5 ảnh/tháng, ảnh trùng, thẻ "không chắc".

Biên lai và khoản thật có tên người, số tiền: không chụp màn hình gửi lên GitHub hay chat.

## Nguồn (Apple, đọc 2026-10-04, 06 và 10)

- [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios): bảng capability theo loại thành viên (đọc thẳng từ HTML của trang): App groups ✓ cả ba cột; In-App Purchase, Push notifications, iCloud, Siri không có ở cột miễn phí.
- [StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode): thử mua cục bộ bằng tệp `.storekit`, không cần kết nối máy chủ App Store, dùng được khi chưa thiết lập app trong App Store Connect; nhắc bật Chế độ nhà phát triển trên iOS 16 trở lên.
- [So sánh thành viên miễn phí và trả phí](https://developer.apple.com/support/compare-memberships/): chạy trên máy của mình từ Xcode, giới hạn tài khoản miễn phí, TestFlight/App Store Connect/Xcode Cloud chỉ cho tài khoản trả phí.
- [TestFlight](https://developer.apple.com/testflight/): số người thử nội bộ/bên ngoài, số thiết bị, App Review cho bản đầu của người thử bên ngoài.
- [Apple Developer Program](https://developer.apple.com/programs/), [Enroll](https://developer.apple.com/programs/enroll/) và [Program enrollment](https://developer.apple.com/help/account/membership/program-enrollment/) (đọc thẳng HTML 2026-10-06): phí 99 USD mỗi năm (Enterprise 299 USD), tính bằng tiền địa phương nếu có và hiện lúc đăng ký; đăng ký bằng app Apple Developer là thuê bao năm tự gia hạn; đăng ký cá nhân bằng thẻ tín dụng phải dùng thẻ của chính bạn.
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview) và [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers) (đọc thẳng HTML 2026-10-10): người thử nội bộ tối đa 100 người dùng App Store Connect, tải và thử mọi build trong 90 ngày; App Review cho build đầu khi mời người thử bên ngoài.
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds) (đọc thẳng HTML 2026-10-10): các công cụ tải build lên (Xcode, Swift Playground, altool, Transporter, API, Xcode Cloud).
- [Enrolling in the app](https://developer.apple.com/help/account/membership/enrolling-in-the-app) (đọc thẳng HTML 2026-10-10): đăng ký Apple Developer Program bằng app Apple Developer trên iPhone, iPad hoặc Mac (cá nhân: cùng một thiết bị, xác minh danh tính bằng ảnh giấy tờ có ảnh; tên pháp lý hiện là người bán trên App Store), thuê bao năm tự gia hạn; chú thích: đăng ký có thể không được hỗ trợ ở một số khu vực.
- [Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/), [Register an app group](https://developer.apple.com/help/account/identifiers/register-an-app-group/) và [Enable app capabilities](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/) (đọc thẳng HTML 2026-10-10): đăng ký explicit App ID khớp bundle ID trong Xcode; đăng ký App Group bằng mô tả và định danh; bật capability App Groups cho App ID rồi gán nhóm bằng Configure.
- [App Store Connect API](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/) và [Creating API Keys](https://developer.apple.com/documentation/AppStoreConnectAPI/creating-api-keys-for-app-store-connect-api) (đọc thẳng HTML/JSON 2026-10-10): Account Holder xin quyền API (Request Access, xét duyệt từng trường hợp); team key do Account Holder hoặc Admin tạo; khoá cá nhân không dùng được Provisioning endpoints; tệp khoá riêng chỉ tải một lần.
- [Preparing your app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution) và [Complying with Encryption Export Regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations) (đọc thẳng JSON 2026-10-10): app icon là thông tin cần có khi chuẩn bị phân phối (Icon Composer hoặc asset catalog); khai báo mã hoá xuất khẩu bằng khoá trong Info.plist, đặt NO nếu không dùng mã hoá hoặc chỉ dùng loại được miễn.
