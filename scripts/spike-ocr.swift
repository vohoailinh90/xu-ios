// Spike OCR ảnh chuyển khoản (docs/11): Vision trên máy có đọc được chữ tiếng Việt (dấu) và số tiền
// trong ảnh kiểu biên lai chuyển khoản không?
//
// Chạy: `swift scripts/spike-ocr.swift` (macOS có Xcode). CI chạy ở .github/workflows/spike-ocr.yml.
//
// Giới hạn — đọc kỹ trước khi dùng kết quả:
// - Ảnh là mẫu **tự dựng** (dữ liệu giả, chữ sạch, phông hệ thống), không phải ảnh chụp màn hình thật của ngân hàng nào.
//   Kết quả ở đây là **cận trên**: Vision đọc tệ trên chữ sạch thì chắc chắn tệ trên ảnh thật; đọc tốt ở đây chưa chứng minh gì
//   về ảnh thật (phông riêng, chữ xám nhỏ, biểu tượng, ảnh nén). Độ chính xác trên ảnh thật phải chấm bằng
//   prototypes/cham-bien-lai.html với ≥ 50 ảnh của chính chủ dự án.
// - Chạy trên macOS của máy chủ CI, không phải iPhone: danh sách ngôn ngữ và độ chính xác có thể khác trên iOS 17/18. Chỉ là
//   chỉ báo; kiểm lại trên máy thật.
import CoreGraphics
import CoreText
import Foundation
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
func render(_ sample: Sample, dark: Bool, scale: CGFloat) -> CGImage? {
    let width = 390 * scale
    let step = 36 * scale
    let height = CGFloat(sample.rows.count) * step + 170 * scale
    guard let ctx = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    let background = dark ? CGColor(red: 0.07, green: 0.08, blue: 0.09, alpha: 1) : CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    let strong = dark ? CGColor(red: 0.92, green: 0.93, blue: 0.94, alpha: 1) : CGColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
    let muted = dark ? CGColor(red: 0.58, green: 0.6, blue: 0.63, alpha: 1) : CGColor(red: 0.45, green: 0.47, blue: 0.5, alpha: 1)
    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let margin = 20 * scale
    var y = height - 50 * scale
    drawText(sample.headline, ctx: ctx, size: 16 * scale, bold: true, color: strong, y: y, align: .center, canvasWidth: width, margin: margin)
    y -= 56 * scale
    drawText(sample.amount, ctx: ctx, size: 30 * scale, bold: true, color: strong, y: y, align: .center, canvasWidth: width, margin: margin)
    y -= 56 * scale
    for row in sample.rows {
        drawText(row.label, ctx: ctx, size: 14 * scale, bold: false, color: muted, y: y, align: .left, canvasWidth: width, margin: margin)
        drawText(row.value, ctx: ctx, size: 15 * scale, bold: false, color: strong, y: y, align: .right, canvasWidth: width, margin: margin)
        y -= step
    }
    return ctx.makeImage()
}

// MARK: - OCR

struct Config {
    let name: String
    let level: VNRequestTextRecognitionLevel
    let correction: Bool
    let languages: [String]?
}

var cpuOnly = false

func recognize(_ image: CGImage, _ config: Config) throws -> [String] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = config.level
    request.usesLanguageCorrection = config.correction
    if let languages = config.languages { request.recognitionLanguages = languages }
    if cpuOnly { request.usesCPUOnly = true }
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    let observations = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
    return observations.compactMap { $0.topCandidates(1).first?.string }
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
    Config(name: "accurate · sửa lỗi theo ngôn ngữ · mặc định", level: .accurate, correction: true, languages: nil),
    Config(name: "accurate · không sửa lỗi · mặc định", level: .accurate, correction: false, languages: nil),
    Config(name: "fast · sửa lỗi · mặc định", level: .fast, correction: true, languages: nil),
    Config(name: "accurate · sửa lỗi · en-US", level: .accurate, correction: true, languages: ["en-US"])
]
if let vietnamese {
    configs.append(Config(name: "accurate · sửa lỗi · \(vietnamese)", level: .accurate, correction: true, languages: [vietnamese]))
    configs.append(Config(name: "accurate · không sửa lỗi · \(vietnamese)", level: .accurate, correction: false, languages: [vietnamese]))
}

// Thử một lần; nếu máy chủ ảo không có GPU/ANE thì dùng CPU.
if let warmup = render(samples[0], dark: false, scale: 3) {
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
    var exact = 0
    var folded = 0
    var total = 0
}

var tallies: [String: [Kind: Tally]] = [:]
var amountDigitsOK: [String: Int] = [:]
var amountTotal = 0
var misses: [String] = []
var shown: Set<String> = []
let variants: [(dark: Bool, scale: CGFloat)] = [(false, 2), (false, 3), (true, 2), (true, 3)]

for sample in samples {
    for variant in variants {
        guard let image = render(sample, dark: variant.dark, scale: variant.scale) else { continue }
        let expected = [(Kind.amount, sample.amount)] + sample.rows.map { ($0.kind, $0.value) }
        amountTotal += 1
        for config in configs {
            let lines: [String]
            do { lines = try recognize(image, config) } catch {
                print("Lỗi OCR (\(config.name), \(sample.title)): \(error)")
                continue
            }
            let joined = lines.joined(separator: "\n")
            let joinedFolded = fold(joined)
            for (kind, value) in expected {
                var tally = tallies[config.name, default: [:]][kind, default: Tally()]
                tally.total += 1
                let isExact = joined.contains(value)
                if isExact { tally.exact += 1 }
                if joinedFolded.contains(fold(value)) { tally.folded += 1 }
                tallies[config.name, default: [:]][kind] = tally
                if kind == .amount {
                    let want = value.filter(\.isNumber)
                    if numbers(in: joined).contains(want) { amountDigitsOK[config.name, default: 0] += 1 }
                }
                if !isExact, config.name == configs[0].name, misses.count < 24 {
                    misses.append("[\(sample.title) · \(variant.dark ? "tối" : "sáng") · \(Int(variant.scale))x · \(kind.rawValue)] cần \"\(value)\"")
                }
            }
            let key = "\(sample.title)|\(variant.dark)|\(variant.scale)|\(config.name)"
            if sample.title == samples[0].title, variant.scale == 3, !shown.contains(key),
               config.name == configs[0].name || config.name == configs.last?.name {
                shown.insert(key)
                print("\n--- OCR thô: \(sample.title) · \(variant.dark ? "tối" : "sáng") · 3x · \(config.name) ---")
                print(joined)
            }
        }
    }
}

print("\n=== KẾT QUẢ (đúng nguyên văn / đúng khi bỏ dấu, trên tổng số) — ảnh tự dựng, CHỈ LÀ CẬN TRÊN ===")
for config in configs {
    print("\n\(config.name)")
    let perKind = tallies[config.name, default: [:]]
    for kind in Kind.allCases {
        let t = perKind[kind, default: Tally()]
        print("  \(kind.rawValue.padding(toLength: 9, withPad: " ", startingAt: 0)) nguyên văn \(t.exact)/\(t.total) · bỏ dấu \(t.folded)/\(t.total)")
    }
    print("  số tiền đúng các chữ số: \(amountDigitsOK[config.name, default: 0])/\(amountTotal)")
}

print("\n=== Chỗ sai của cấu hình đầu (tối đa 24) ===")
for miss in misses { print(miss) }
if misses.isEmpty { print("(không có)") }
