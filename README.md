# Xu — ghi chi tiêu trong 2 giây

> Tên tạm: **Xu** (đồng xu). Ngắn, dễ nhớ, dễ gõ. Có thể đổi sau — xem phần "Đặt tên" trong `docs/07-kinh-doanh-aso.md`.

Xu là app iOS giúp ghi chi tiêu **nhanh nhất có thể**, không cần liên kết ngân hàng, không làm người dùng thấy tội lỗi, và biến việc quản lý tiền thành **thói quen nhẹ nhàng**.

```
Gõ:  "cà phê 35k"            →  35.000đ · ☕ Cà phê & đồ uống · Hôm nay
Gõ:  "grab 52k hôm qua"      →  52.000đ · 🛵 Di chuyển · Hôm qua
Gõ:  "1tr2 tiền nhà"         →  1.200.000đ · 🧾 Hóa đơn · Hôm nay
Gõ:  "lương +15tr"           →  +15.000.000đ · 💰 Lương · Hôm nay
```

## Nguyên tắc sản phẩm

1. **Quy tắc 2 giây** — ghi một khoản chi không được mất quá 2–3 giây. Mọi tính năng mới phải qua được bài kiểm tra này.
2. **Không tội lỗi** — không dùng màu đỏ trừng phạt, không reset chuỗi về 0 vì lỡ một ngày.
3. **Riêng tư, offline** — dữ liệu nằm trên máy (và iCloud của người dùng), không cần tài khoản, không cần mạng.
4. **Việt Nam trước** — hiểu "35k", "1tr2", "1,5 củ", "hôm qua", "thứ 2", chuyển khoản QR, ví điện tử.

## Cấu trúc repo

```
xu-ios/
├── docs/                   Tài liệu sản phẩm & kỹ thuật (đọc theo thứ tự số)
├── XuCore/                 Swift Package: logic thuần, không phụ thuộc UI, có unit test
│   ├── Sources/XuCore/     Parser câu nhập, danh mục, thói quen, "còn được tiêu"
│   └── Tests/XuCoreTests/
├── App/
│   ├── Xu/                 Target app (SwiftUI)
│   ├── Shared/             Code dùng chung app + widget (SwiftData, App Intents)
│   └── XuWidgets/          Widget extension (widget tương tác, màn hình khóa)
├── project.yml             Cấu hình XcodeGen để sinh file .xcodeproj
├── scripts/                Script tạo label/milestone/issue trên GitHub
└── .github/                CI chạy test XuCore, mẫu issue & PR
```

## Bắt đầu

Yêu cầu: macOS, Xcode 16+, iOS 17+ (SwiftData và widget tương tác cần iOS 17).

```bash
# 1. Chạy test phần lõi (không cần Xcode project)
cd XuCore && swift test

# 2. Sinh Xcode project
brew install xcodegen
xcodegen generate
open Xu.xcodeproj
```

Trước khi chạy trên máy thật: đổi `com.example` trong `project.yml` thành bundle ID của bạn, và đổi App Group `group.com.example.xu` ở cả `project.yml` lẫn `App/Shared/Persistence/SharedStore.swift`.

## Tạo issue trên GitHub

```bash
gh auth login
./scripts/create-issues.sh
```

Script sẽ tạo label, milestone M0–M4 và toàn bộ issue của MVP theo `docs/06-lo-trinh.md`.

## Tài liệu

| File | Nội dung |
|---|---|
| `docs/01-tam-nhin-san-pham.md` | Định vị, chân dung người dùng, khoảng trống thị trường |
| `docs/02-tinh-nang-mvp.md` | Danh sách tính năng, user story, tiêu chí chấp nhận, Free vs Pro |
| `docs/03-kien-truc.md` | Kiến trúc, mô hình dữ liệu, giới hạn nền tảng iOS |
| `docs/04-bo-phan-tich-nhap-nhanh.md` | Đặc tả parser câu nhập tiếng Việt |
| `docs/05-thoi-quen-tai-chinh.md` | Thiết kế thói quen, công thức điểm, giọng văn |
| `docs/06-lo-trinh.md` | Lộ trình 6 tuần và danh sách issue |
| `docs/07-kinh-doanh-aso.md` | Giá, ASO, ra mắt, chỉ số đo lường |

## Đã có sẵn trong khung

| Phần | File chính | Trạng thái |
|---|---|---|
| Parser câu nhập tiếng Việt | `XuCore/Sources/XuCore/QuickEntryParser.swift` | Có test |
| Danh mục + học từ khóa | `XuCore/Sources/XuCore/CategoryCatalog.swift` | Có test |
| Thói quen (điểm sức mạnh, chuỗi mềm) | `XuCore/Sources/XuCore/HabitEngine.swift` | Có test |
| "Còn được tiêu hôm nay" | `XuCore/Sources/XuCore/SafeToSpend.swift` | Có test |
| Dữ liệu SwiftData dùng chung app + widget | `App/Shared/Persistence/` | Khung |
| Thanh nhập nhanh, xem trước, hoàn tác | `App/Xu/Features/QuickEntry/` | Khung |
| Home, xuất CSV, cài đặt ngân sách | `App/Xu/Features/Home/`, `Settings/` | Khung |
| Shortcuts / Action Button / Apple Pay | `App/Shared/Intents/` | Khung |
| Widget khoản quen + màn hình khóa | `App/XuWidgets/` | Khung |

## Repo này và repo ý tưởng

| Repo | Việc |
|------|------|
| `xu-ios` (repo này) | Code app, tài liệu sản phẩm, quyết định cuối |
| [App-idea-lab](https://github.com/vohoailinh90/App-idea-lab) | Chấm điểm ý tưởng, brainstorm tính năng (`products/xu/`), kế hoạch validate (`ideas/xu-ghi-chi-tieu-2-giay.md`) |

## Trạng thái

Đang ở giai đoạn **validate** (kế hoạch 7 ngày, 2026-09-26 → 2026-10-03, ở repo ý tưởng).
Chỉ build tiếp khi đạt ngưỡng trong kế hoạch đó.

Khung dự án ban đầu, **chưa được build thử bằng Xcode** (được viết ngoài môi trường macOS). Lần build đầu tiên có thể cần sửa vài lỗi nhỏ — hãy chạy `swift test` trong `XuCore` trước, rồi mới build app.
