// Spike OCR ảnh chuyển khoản (docs/11): Vision trên máy có đọc được chữ tiếng Việt (dấu) và số tiền
// trong ảnh kiểu biên lai chuyển khoản không?
//
// Chạy: `swift scripts/spike-ocr.swift` (macOS có Xcode). CI chạy ở .github/workflows/spike-ocr.yml.
//
// Giới hạn — đọc kỹ trước khi dùng kết quả:
// - Ảnh là mẫu **tự dựng** (dữ liệu giả, phông hệ thống), không phải ảnh chụp màn hình thật của ngân hàng nào. Có thêm các biến thể gần
//   ảnh thật hơn (nén JPEG, thu nhỏ, chữ nhỏ và nhạt) nhưng vẫn là mô phỏng. Kết quả ở đây là **cận trên có điều kiện**: đọc tệ ở đây thì chắc
//   chắn tệ trên ảnh thật; đọc tốt ở đây chưa chứng minh gì về ảnh thật (phông riêng, biểu tượng, nền chuyển màu, ảnh qua Zalo/Messenger).
//   Độ chính xác trên ảnh thật phải chấm bằng prototypes/cham-bien-lai.html với ≥ 50 ảnh của chính chủ dự án.
// - Chạy trên macOS của máy chủ CI, không phải iPhone: danh sách ngôn ngữ, độ chính xác và tốc độ có thể khác trên iOS 17/18.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Vision

// MARK: - Mẫu (toàn bộ là dữ liệu giả)

enum Kind: String, CaseIterable {
    case amount, datetime, id, name, note
}

struct Row {
    let label: String
    let value: String
    let kind: Kind
}

struct Sample {
    let title: String
    let headline: String
    let amount: String
    let rows: [Row]
}

let samples: [Sample] = [
    Sample(title: "chuyển đi, VND", headline: "Chuyển tiền thành công", amount: "-1.356.780 VND", rows: [
        Row(label: "Thời gian", value: "26/09/2026 08:41:12", kind: .datetime),
        Row(label: "Tài khoản nguồn", value: "0123456789", kind: .id),
        Row(label: "Người nhận", value: "NGUYỄN VĂN AN", kind: .name),
        Row(label: "Ngân hàng nhận", value: "ACB", kind: .name),
        Row(label: "Nội dung", value: "Tiền ăn trưa tháng 9", kind: .note),
        Row(label: "Mã giao dịch", value: "FT26269123456", kind: .id)
    ]),
    Sample(title: "quét QR, đ", headline: "Thanh toán thành công", amount: "52.000đ", rows: [
        Row(label: "Thời gian", value: "27/09/2026 19:05", kind: .datetime),
        Row(label: "Người nhận", value: "TRẦN THỊ BÍCH NGỌC", kind: .name),
        Row(label: "Nội dung", value: "ca phe voi Lan", kind: .note),
        Row(label: "Mã giao dịch", value: "2609271905123456", kind: .id)
    ]),
    Sample(title: "nhận tiền, VND", headline: "Biến động số dư", amount: "+2.500.000 VND", rows: [
        Row(label: "Thời gian", value: "28/09/2026 10:15:30", kind: .datetime),
        Row(label: "Người gửi", value: "LÊ HOÀNG ĐỨC", kind: .name),
        Row(label: "Nội dung", value: "Hoàn tiền mua chung đợt 1", kind: .note),
        Row(label: "Số dư", value: "8.431.200 VND", kind: .id)
    ]),
    Sample(title: "ví, ₫", headline: "Giao dịch thành công", amount: "1.200.000 ₫", rows: [
        Row(label: "Thời gian", value: "29/09/2026 21:40", kind: .datetime),
        Row(label: "Đến", value: "PHẠM QUỐC KHÁNH", kind: .name),
        Row(label: "Lời nhắn", value: "Gửi anh tiền điện nước tháng 9", kind: .note),
        Row(label: "Mã giao dịch", value: "88123456790", kind: .id)
    ])
]

// MARK: - Dựng ảnh

enum Align { case left, right, center }

func drawText(_ text: String, ctx: CGContext, size: CGFloat, bold: Bool, color: CGColor,
              y: CGFloat, align: Align, canvasWidth: CGFloat, margin: CGFloat) {
    let kind: CTFontUIFontType = bold ? .emphasizedSystem : .system
    let font = CTFontCreateUIFontForLanguage(kind, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    let attributes: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
    let attributed = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attributed)
    let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    let x: CGFloat
    switch align {
    case .left: x = margin
    case .right: x = canvasWidth - margin - textWidth
    case .center: x = (canvasWidth - textWidth) / 2
    }
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, ctx)
}

/// Một màn hình 390 pt rộng (iPhone), `scale` là số điểm ảnh mỗi pt (2x/3x). Chữ nhãn xám, giá trị đậm hơn, số tiền to ở giữa.
/// `small`: chữ nhỏ (nhãn 11 pt, giá trị 12 pt, số tiền 22 pt) và nhãn rất nhạt — kiểu màn hình dày thông tin.
func render(_ sample: Sample, dark: Bool, scale: CGFloat, small: Bool) -> CGImage? {
    let width = 390 * scale
    let step = (small ? 28 : 36) * scale
    let height = CGFloat(sample.rows.count) * step + 170 * scale
    guard let ctx = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    let background = dark ? CGColor(red: 0.07, green: 0.08, blue: 0.09, alpha: 1) : CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    let strong = dark ? CGColor(red: 0.92, green: 0.93, blue: 0.94, alpha: 1) : CGColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
    let mutedLevel: CGFloat = small ? (dark ? 0.42 : 0.62) : (dark ? 0.58 : 0.45)
    let muted = CGColor(red: mutedLevel, green: mutedLevel + 0.01, blue: mutedLevel + 0.03, alpha: 1)
    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let margin = 20 * scale
    var y = height - 50 * scale
    drawText(sample.headline, ctx: ctx, size: (small ? 13 : 16) * scale, bold: true, color: strong, y: y, align: .center, canvasWidth: width, margin: margin)
    y -= 56 * scale
    drawText(sample.amount, ctx: ctx, size: (small ? 22 : 30) * scale, bold: true, color: strong, y: y, align: .center, canvasWidth: width, margin: margin)
    y -= 56 * scale
    for row in sample.rows {
        drawText(row.label, ctx: ctx, size: (small ? 11 : 14) * scale, bold: false, color: muted, y: y, align: .left, canvasWidth: width, margin: margin)
        drawText(row.value, ctx: ctx, size: (small ? 12 : 15) * scale, bold: false, color: strong, y: y, align: .right, canvasWidth: width, margin: margin)
        y -= step
    }
    return ctx.makeImage()
}

func downscale(_ image: CGImage, factor: CGFloat) -> CGImage? {
    let w = max(1, Int(CGFloat(image.width) * factor))
    let h = max(1, Int(CGFloat(image.height) * factor))
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    ctx.interpolationQuality = .medium
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()
}

/// Nén JPEG rồi giải nén lại, như ảnh đi qua Zalo/Messenger.
func jpeg(_ image: CGImage, quality: CGFloat) -> CGImage? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    guard CGImageDestinationFinalize(destination), let source = CGImageSourceCreateWithData(data, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

struct Variant {
    let name: String
    let make: (Sample, Bool) -> CGImage?
}

let variants: [Variant] = [
    Variant(name: "sạch 3x") { render($0, dark: $1, scale: 3, small: false) },
    Variant(name: "sạch 2x") { render($0, dark: $1, scale: 2, small: false) },
    Variant(name: "JPEG 40%") { s, d in render(s, dark: d, scale: 3, small: false).flatMap { jpeg($0, quality: 0.4) } },
    Variant(name: "thu nhỏ 50% + JPEG 50%") { s, d in
        render(s, dark: d, scale: 3, small: false).flatMap { downscale($0, factor: 0.5) }.flatMap { jpeg($0, quality: 0.5) }
    },
    Variant(name: "chữ nhỏ, nhãn nhạt 3x") { render($0, dark: $1, scale: 3, small: true) },
    Variant(name: "chữ nhỏ, nhãn nhạt + thu nhỏ 50% + JPEG 50%") { s, d in
        render(s, dark: d, scale: 3, small: true).flatMap { downscale($0, factor: 0.5) }.flatMap { jpeg($0, quality: 0.5) }
    }
]

// MARK: - OCR

struct Config {
    let name: String
    let level: VNRequestTextRecognitionLevel
    let correction: Bool
    let languages: [String]?
}

struct Line {
    let text: String
    let box: CGRect   // toạ độ chuẩn hoá của Vision, gốc ở góc dưới trái
}

var cpuOnly = false

func recognize(_ image: CGImage, _ config: Config) throws -> [Line] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = config.level
    request.usesLanguageCorrection = config.correction
    if let languages = config.languages { request.recognitionLanguages = languages }
    if cpuOnly { request.usesCPUOnly = true }
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    return (request.results ?? []).compactMap { observation in
        observation.topCandidates(1).first.map { Line(text: $0.string, box: observation.boundingBox) }
    }
}

func fold(_ text: String) -> String {
    text.lowercased().replacingOccurrences(of: "đ", with: "d").folding(options: [.diacriticInsensitive], locale: nil)
}

let numberToken = try! NSRegularExpression(pattern: #"\d[\d.,]*\d|\d"#)

func numbers(in text: String) -> [String] {
    numberToken.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { m in
        Range(m.range, in: text).map { String(text[$0]).filter(\.isNumber) }
    }
}

/// Gom các ô chữ cùng một hàng (khoảng cách dọc giữa tâm nhỏ hơn 0,6 chiều cao chữ), trong hàng sắp từ trái sang phải.
func groupRows(_ lines: [Line]) -> [[Line]] {
    var groups: [[Line]] = []
    for line in lines.sorted(by: { $0.box.midY > $1.box.midY }) {
        if let reference = groups.last?.first,
           abs(reference.box.midY - line.box.midY) < max(reference.box.height, line.box.height) * 0.6 {
            groups[groups.count - 1].append(line)
        } else {
            groups.append([line])
        }
    }
    return groups.map { $0.sorted { $0.box.minX < $1.box.minX } }
}

// MARK: - Chạy

print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
let probe = VNRecognizeTextRequest()
print("Revision hiện tại: \(VNRecognizeTextRequest.currentRevision) · hỗ trợ: \(VNRecognizeTextRequest.supportedRevisions.sorted())")
probe.recognitionLevel = .accurate
let accurateLanguages = (try? probe.supportedRecognitionLanguages()) ?? []
probe.recognitionLevel = .fast
let fastLanguages = (try? probe.supportedRecognitionLanguages()) ?? []
print("Ngôn ngữ (accurate): \(accurateLanguages)")
print("Ngôn ngữ (fast): \(fastLanguages)")
let vietnamese = accurateLanguages.first { $0.lowercased().hasPrefix("vi") }
print("Có tiếng Việt (accurate): \(vietnamese ?? "KHÔNG")")

var configs = [
    Config(name: "accurate · sửa lỗi · mặc định", level: .accurate, correction: true, languages: nil),
    Config(name: "accurate · không sửa lỗi · mặc định", level: .accurate, correction: false, languages: nil)
]
if let vietnamese {
    configs.append(Config(name: "accurate · sửa lỗi · \(vietnamese)", level: .accurate, correction: true, languages: [vietnamese]))
    configs.append(Config(name: "accurate · không sửa lỗi · \(vietnamese)", level: .accurate, correction: false, languages: [vietnamese]))
}
configs.append(Config(name: "fast · sửa lỗi · mặc định", level: .fast, correction: true, languages: nil))

// Thử một lần; nếu máy chủ ảo không có GPU/ANE thì dùng CPU.
if let warmup = render(samples[0], dark: false, scale: 3, small: false) {
    do { _ = try recognize(warmup, configs[0]) } catch {
        print("Lần thử đầu lỗi (\(error)); thử lại bằng CPU")
        cpuOnly = true
        do { _ = try recognize(warmup, configs[0]) } catch {
            print("VISION_KHONG_CHAY_DUOC: \(error)")
            exit(1)
        }
    }
}
print("Chạy bằng CPU: \(cpuOnly)")

struct Tally {
    var imagesRun = 0
    var failures = 0         // OCR báo lỗi: tính là sai ở mọi mẫu số, không bỏ qua
    var amountExact = 0
    var amountDigits = 0
    var amountByHeight = 0   // dòng chữ cao nhất có chữ số đúng là số tiền
    var fields: [Kind: (exact: Int, folded: Int, total: Int)] = [:]
    var pairs = 0            // nhãn và giá trị cùng một hàng sau khi gom theo toạ độ
    var pairsTotal = 0
    var millis = 0.0
}

var tallies: [String: Tally] = [:]   // khoá: "biến thể | cấu hình"
var misses: [String] = []
var rawShown = 0

for variant in variants {
    for config in configs {
        var tally = Tally()
        for sample in samples {
            for dark in [false, true] {
                guard let image = variant.make(sample, dark) else { continue }
                let started = Date()
                let lines: [Line]
                var failed = false
                do { lines = try recognize(image, config) } catch {
                    // Không `continue`: bỏ ảnh lỗi khỏi mẫu số sẽ làm các tỉ lệ đúng/tổng cao giả tạo. Tính là đọc được 0 dòng (mọi trường sai).
                    print("Lỗi OCR (\(variant.name), \(config.name), \(sample.title)): \(error)")
                    lines = []
                    failed = true
                }
                if failed { tally.failures += 1 } else { tally.millis += Date().timeIntervalSince(started) * 1000 }
                tally.imagesRun += 1
                let joined = lines.map(\.text).joined(separator: "\n")
                let joinedFolded = fold(joined)

                // Số tiền: nguyên văn, đúng các chữ số, và "dòng chữ cao nhất".
                if joined.contains(sample.amount) { tally.amountExact += 1 }
                let want = sample.amount.filter(\.isNumber)
                if numbers(in: joined).contains(want) { tally.amountDigits += 1 }
                let tallest = lines.filter { $0.text.contains(where: \.isNumber) }.max { $0.box.height < $1.box.height }
                if let tallest, numbers(in: tallest.text).contains(want) { tally.amountByHeight += 1 }
                else if config.name == configs[0].name, misses.count < 30 {
                    misses.append("[\(variant.name) · \(sample.title) · \(dark ? "tối" : "sáng")] số tiền cần \"\(sample.amount)\", dòng cao nhất: \"\(tallest?.text ?? "(không có)")\"")
                }

                // Các trường còn lại.
                for row in sample.rows {
                    var entry = tally.fields[row.kind] ?? (0, 0, 0)
                    entry.total += 1
                    if joined.contains(row.value) { entry.exact += 1 }
                    if joinedFolded.contains(fold(row.value)) { entry.folded += 1 }
                    tally.fields[row.kind] = entry
                }

                // Ghép nhãn–giá trị theo hàng.
                let rows = groupRows(lines).map { fold($0.map(\.text).joined(separator: " | ")) }
                for row in sample.rows {
                    tally.pairsTotal += 1
                    if rows.contains(where: { $0.contains(fold(row.label)) && $0.contains(fold(row.value)) }) { tally.pairs += 1 }
                }

                // Một bản OCR thô để xem bằng mắt: ảnh đã nén, cấu hình đầu.
                if variant.name.hasPrefix("thu nhỏ 50% + JPEG") , config.name == configs[0].name, sample.title == samples[0].title, rawShown < 2 {
                    rawShown += 1
                    print("\n--- OCR thô (theo thứ tự Vision trả về): \(variant.name) · \(dark ? "tối" : "sáng") · \(config.name) ---")
                    for line in lines { print(String(format: "  y=%.3f h=%.3f x=%.3f  %@", line.box.midY, line.box.height, line.box.minX, line.text)) }
                }
            }
        }
        tallies["\(variant.name) | \(config.name)"] = tally
    }
}

func percent(_ a: Int, _ b: Int) -> String { b == 0 ? "-" : "\(a)/\(b)" }

print("\n=== KẾT QUẢ — ảnh tự dựng, CHỈ LÀ CHỈ BÁO. Mỗi ô: đúng/tổng ===")
for variant in variants {
    print("\n## \(variant.name)")
    for config in configs {
        guard let t = tallies["\(variant.name) | \(config.name)"] else { continue }
        let f = { (kind: Kind) -> String in
            let e = t.fields[kind] ?? (0, 0, 0)
            return "\(percent(e.exact, e.total)) (bỏ dấu \(percent(e.folded, e.total)))"
        }
        let timedImages = t.imagesRun - t.failures
        let average = timedImages <= 0 ? 0 : t.millis / Double(timedImages)
        let failureNote = t.failures > 0 ? " · LỖI OCR \(t.failures)/\(t.imagesRun) (đã tính là sai)" : ""
        print("- \(config.name) · \(String(format: "%.0f", average)) ms/ảnh\(failureNote)")
        print("    số tiền: nguyên văn \(percent(t.amountExact, t.imagesRun)) · đúng chữ số \(percent(t.amountDigits, t.imagesRun)) · chọn theo dòng cao nhất \(percent(t.amountByHeight, t.imagesRun))")
        print("    ngày giờ \(f(.datetime)) · tên \(f(.name)) · nội dung \(f(.note)) · mã \(f(.id)) · ghép nhãn–giá trị \(percent(t.pairs, t.pairsTotal))")
    }
}

print("\n=== Chỗ chọn sai số tiền theo dòng cao nhất, cấu hình đầu (tối đa 30) ===")
for miss in misses { print(miss) }
if misses.isEmpty { print("(không có)") }
