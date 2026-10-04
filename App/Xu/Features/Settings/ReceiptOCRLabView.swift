#if DEBUG
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Vision

/// Màn hình thử cho spike OCR ảnh chuyển khoản (docs/11) — **chỉ có trong bản Debug** (`#if DEBUG`): không vào TestFlight/App Store,
/// nên chữ ở đây không qua `L10n` (không dịch).
///
/// Mục đích: chạy đúng bộ đọc `VNRecognizeTextRequest` sẽ phát hành trên iPhone thật với biên lai thật của chủ dự án, để biết (1) máy này có
/// `vi-VT`/`ja-JP` không (iOS 17/18), (2) đọc mất bao lâu, (3) số tiền theo quy tắc "dòng chữ cao nhất có chữ số" (đã đo ở docs/11) có đúng không.
/// Nhập số đúng và chọn ngân hàng cho từng ảnh để thấy ngay tỉ lệ đúng theo ngân hàng (ngưỡng ở docs/11); kết quả chỉ nằm trong bộ nhớ
/// của màn hình này, mất khi chọn ảnh khác. Nút "Sao chép chữ" để chấm bằng `prototypes/cham-bien-lai.html` — chỉ dán được trên **chính máy này**.
///
/// Riêng tư (luật 6): ảnh chỉ nằm trong bộ nhớ, không lưu, không gửi đi; không xin quyền thư viện ảnh (bộ chọn ảnh của hệ thống chỉ trao ảnh
/// đã chọn). Chữ đọc được có thể chứa số tài khoản và tên người nhận: không lưu; chỉ chép vào bảng nhớ khi bạn bấm, với `localOnly` (không sang
/// máy khác qua Universal Clipboard) và tự hết hạn sau 2 phút.
struct ReceiptOCRLabView: View {
    @State private var picked: [PhotosPickerItem] = []
    @State private var runs: [OCRRun] = []
    @State private var running = false
    @State private var accurate = true
    @State private var languageChoice: LanguageChoice = .automatic
    @State private var correction = true
    @State private var truths: [Int: String] = [:]
    @State private var banks: [Int: String] = [:]
    @State private var copiedIndex: Int?
    private let environment = LabEnvironment.read()

    var body: some View {
        List {
            Section {
                PhotosPicker(selection: $picked, maxSelectionCount: 60, matching: .images) {
                    Label(running ? "Đang đọc…" : "Chọn ảnh biên lai (tối đa 60)", systemImage: "photo.on.rectangle")
                }
                .disabled(running)
            } footer: {
                Text("Chỉ dùng biên lai của chính bạn. Ảnh xử lý trên máy, không lưu, không gửi đi. Chữ đọc được có thể có số tài khoản và tên người nhận: đừng chụp màn hình này để chia sẻ.")
            }

            Section {
                Picker("Chế độ", selection: $accurate) {
                    Text("Chính xác").tag(true)
                    Text("Nhanh (kém, chỉ để so)").tag(false)
                }
                Picker("Ngôn ngữ", selection: $languageChoice) {
                    ForEach(LanguageChoice.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Sửa lỗi theo ngôn ngữ", isOn: $correction)
                Button("Đọc lại ảnh đã chọn với cài đặt này") { Task { await readAll() } }
                    .disabled(picked.isEmpty || running)
            } header: {
                Text("Cách đọc")
            } footer: {
                if let languageNotice { Text(languageNotice) }
            }

            Section {
                LabeledContent("Hệ điều hành") { Text(environment.system).font(.callout) }
                LabeledContent("Thiết bị") { Text(environment.machine).font(.callout) }
                LabeledContent("Tiếng Việt (chính xác)") { Text(environment.vietnamese ?? "KHÔNG CÓ").foregroundStyle(environment.vietnamese == nil ? .red : .green) }
                LabeledContent("Tiếng Nhật (chính xác)") { Text(environment.japanese ?? "KHÔNG CÓ").foregroundStyle(environment.japanese == nil ? .red : .green) }
                DisclosureGroup("Ngôn ngữ chế độ chính xác (\(environment.accurate.count))") {
                    Text(environment.accurate.joined(separator: ", ")).font(.caption).textSelection(.enabled)
                }
                DisclosureGroup("Ngôn ngữ chế độ nhanh (\(environment.fast.count))") {
                    Text(environment.fast.joined(separator: ", ")).font(.caption).textSelection(.enabled)
                }
            } header: {
                Text("Máy này")
            } footer: {
                Text("Ghi hai dòng tiếng Việt/Nhật và hệ điều hành vào docs/11 (kiểm trên iOS 17 và 18).")
            }

            if !runs.isEmpty {
                Section {
                    LabeledContent("Đã đọc") { Text("\(runs.count) ảnh · trung bình \(averageMilliseconds) ms") }
                    if checkedCount > 0 {
                        LabeledContent("Đúng số tiền") { Text("\(correctCount)/\(checkedCount) ảnh đã nhập số đúng").font(.callout) }
                    }
                    ForEach(bankRows, id: \.bank) { row in
                        LabeledContent(row.bank) { Text("\(row.correct)/\(row.total) · \(row.correct * 100 / row.total)%").font(.callout) }
                    }
                } header: {
                    Text("Tổng")
                } footer: {
                    Text("Số tiền đọc được = dòng chữ cao nhất có chữ số. Nhập số đúng bằng chữ số (ví dụ 1356780); 52k, 1tr2 chưa hiểu. Ngưỡng ở docs/11: từ 95% trên 50 ảnh thật (5 ngân hàng) thì đáng làm, dưới 90% thì hoãn. Kết quả mất khi chọn ảnh khác: ghi lại trước.")
                }
            }

            ForEach(runs) { run in
                Section {
                    if let error = run.error {
                        Text(error).foregroundStyle(.red)
                    } else {
                        LabeledContent("Số tiền đọc được") { Text(run.tallest ?? "(không có)").monospacedDigit() }
                        Picker("Ngân hàng / ví", selection: bankBinding(run.index)) {
                            Text("Chưa chọn").tag("")
                            ForEach(Self.bankChoices, id: \.self) { Text($0).tag($0) }
                        }
                        TextField("Số tiền đúng (chữ số)", text: truthBinding(run.index))
                            .keyboardType(.numbersAndPunctuation)
                        if let verdict = verdict(of: run) {
                            Label(verdict ? "Đúng" : "Sai", systemImage: verdict ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(verdict ? .green : .red)
                        }
                        // Không `.textSelection(.enabled)`: thao tác Copy mặc định ghi vào bảng nhớ chung, không `localOnly`, không hết hạn. Chỉ chép bằng nút dưới.
                        Text(run.rowsText).font(.caption.monospaced())
                        Button(copiedIndex == run.index ? "Đã sao chép" : "Sao chép chữ (theo hàng)") {
                            // Tên người nhận và số tài khoản: không để sang máy khác qua Universal Clipboard, tự hết hạn sau 2 phút.
                            UIPasteboard.general.setItems(
                                [[UTType.plainText.identifier: run.rowsText]],
                                options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
                            copiedIndex = run.index
                        }
                    }
                } header: {
                    Text(run.title)
                }
            }
        }
        .navigationTitle("Thử đọc biên lai")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: picked) {
            truths = [:]
            banks = [:]
            copiedIndex = nil
            Task { await readAll() }
        }
    }

    // MARK: - Kết quả

    private static let bankChoices = ["Vietcombank", "Techcombank", "MB Bank", "BIDV", "VietinBank", "ACB", "TPBank", "VPBank",
                                      "Sacombank", "MoMo", "ZaloPay", "Khác"]

    private func truthBinding(_ index: Int) -> Binding<String> {
        Binding(get: { truths[index] ?? "" }, set: { truths[index] = $0 })
    }

    private func bankBinding(_ index: Int) -> Binding<String> {
        Binding(get: { banks[index] ?? "" }, set: { banks[index] = $0 })
    }

    /// Đúng/tổng theo ngân hàng, chỉ tính ảnh đã nhập số đúng.
    private var bankRows: [(bank: String, correct: Int, total: Int)] {
        var table: [String: (correct: Int, total: Int)] = [:]
        for run in runs {
            guard let ok = verdict(of: run) else { continue }
            let chosen = banks[run.index] ?? ""
            let bank = chosen.isEmpty ? "Chưa chọn ngân hàng" : chosen
            var entry = table[bank] ?? (correct: 0, total: 0)
            entry.total += 1
            if ok { entry.correct += 1 }
            table[bank] = entry
        }
        return table.map { (bank: $0.key, correct: $0.value.correct, total: $0.value.total) }.sorted { $0.bank < $1.bank }
    }

    /// Danh sách ngôn ngữ theo **chế độ đang chọn**: chế độ nhanh không có vi-VT/ja-JP (docs/11), đặt mã không hỗ trợ có thể làm Vision báo lỗi.
    private var supportedLanguages: [String] { accurate ? environment.accurate : environment.fast }

    private var effectiveLanguageChoice: LanguageChoice {
        languageChoice.isSupported(in: supportedLanguages) ? languageChoice : .automatic
    }

    private var languageNotice: String? {
        languageChoice.isSupported(in: supportedLanguages)
            ? nil
            : "Chế độ \(accurate ? "chính xác" : "nhanh") của máy này không hỗ trợ \(languageChoice.title): sẽ đọc bằng ngôn ngữ mặc định."
    }

    /// nil nếu chưa nhập số đúng hoặc ảnh lỗi.
    private func verdict(of run: OCRRun) -> Bool? {
        let truth = (truths[run.index] ?? "").filter(\.isNumber)
        guard run.error == nil, !truth.isEmpty else { return nil }
        return (run.tallest ?? "").filter(\.isNumber) == truth
    }

    private var checkedCount: Int { runs.filter { verdict(of: $0) != nil }.count }
    private var correctCount: Int { runs.filter { verdict(of: $0) == true }.count }
    private var averageMilliseconds: Int {
        let timed = runs.filter { $0.error == nil }
        guard !timed.isEmpty else { return 0 }
        return Int(timed.map(\.milliseconds).reduce(0, +) / Double(timed.count))
    }

    // MARK: - Đọc

    private func readAll() async {
        running = true
        defer { running = false }
        let options = ReadOptions(accurate: accurate, correction: correction,
                                  languages: effectiveLanguageChoice.codes(supported: supportedLanguages))
        var collected: [OCRRun] = []
        runs = []
        for (offset, item) in picked.enumerated() {
            collected.append(await Self.read(item: item, index: offset + 1, options: options))
            runs = collected
        }
    }

    private static func read(item: PhotosPickerItem, index: Int, options: ReadOptions) async -> OCRRun {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let cgImage = image.cgImage
        else { return OCRRun(index: index, error: "Không mở được ảnh này") }
        let orientation = cgOrientation(image.imageOrientation)
        return await Task.detached(priority: .userInitiated) { () -> OCRRun in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = options.accurate ? .accurate : .fast
            request.usesLanguageCorrection = options.correction
            if !options.languages.isEmpty { request.recognitionLanguages = options.languages }
            let started = Date()
            do {
                try VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:]).perform([request])
            } catch {
                return OCRRun(index: index, error: "Vision báo lỗi: \(error.localizedDescription)")
            }
            let milliseconds = Date().timeIntervalSince(started) * 1000
            let lines = (request.results ?? []).compactMap { observation in
                observation.topCandidates(1).first.map { OCRLine(text: $0.string, box: observation.boundingBox) }
            }
            let tallest = lines.filter { $0.text.contains(where: \.isNumber) }.max { $0.box.height < $1.box.height }
            let rowsText = groupRows(lines).map { $0.map(\.text).joined(separator: " | ") }.joined(separator: "\n")
            return OCRRun(index: index, summary: "\(cgImage.width)×\(cgImage.height) · \(Int(milliseconds)) ms",
                          milliseconds: milliseconds, rowsText: rowsText, tallest: tallest?.text, error: nil)
        }.value
    }

    /// Gom các ô chữ cùng một hàng (khoảng cách dọc giữa tâm nhỏ hơn 0,6 chiều cao chữ), trong hàng sắp từ trái sang phải. Thứ tự dòng Vision
    /// trả về không đáng tin để ghép nhãn với giá trị (docs/11), nên ghép theo toạ độ.
    private static func groupRows(_ lines: [OCRLine]) -> [[OCRLine]] {
        var groups: [[OCRLine]] = []
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

    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

// MARK: - Kiểu dữ liệu của màn hình thử

private struct OCRLine {
    let text: String
    let box: CGRect   // toạ độ chuẩn hoá của Vision, gốc ở góc dưới trái
}

private struct OCRRun: Identifiable {
    let id = UUID()
    var index: Int
    var summary = ""
    var milliseconds = 0.0
    var rowsText = ""
    var tallest: String?
    var error: String?

    var title: String { summary.isEmpty ? "Ảnh \(index)" : "Ảnh \(index) · \(summary)" }
}

private struct ReadOptions {
    let accurate: Bool
    let correction: Bool
    let languages: [String]   // rỗng = mặc định của hệ thống
}

private enum LanguageChoice: String, CaseIterable, Identifiable {
    case automatic, vietnamese, japanese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Mặc định của hệ thống"
        case .vietnamese: return "Việt + Anh (vi-VT, en-US)"
        case .japanese: return "Nhật + Anh (ja-JP, en-US)"
        }
    }

    func isSupported(in supported: [String]) -> Bool {
        switch self {
        case .automatic: return true
        case .vietnamese: return supported.contains { $0.lowercased().hasPrefix("vi") }
        case .japanese: return supported.contains { $0.lowercased().hasPrefix("ja") }
        }
    }

    /// Chỉ trả mã máy này hỗ trợ: đặt mã không hỗ trợ có thể làm Vision báo lỗi.
    func codes(supported: [String]) -> [String] {
        func pick(_ prefix: String) -> String? { supported.first { $0.lowercased().hasPrefix(prefix) } }
        switch self {
        case .automatic: return []
        case .vietnamese: return [pick("vi"), pick("en")].compactMap { $0 }
        case .japanese: return [pick("ja"), pick("en")].compactMap { $0 }
        }
    }
}

private struct LabEnvironment {
    let system: String
    let machine: String
    let accurate: [String]
    let fast: [String]

    var vietnamese: String? { accurate.first { $0.lowercased().hasPrefix("vi") } }
    var japanese: String? { accurate.first { $0.lowercased().hasPrefix("ja") } }

    static func read() -> LabEnvironment {
        var info = utsname()
        uname(&info)
        let machine = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        let probe = VNRecognizeTextRequest()
        probe.recognitionLevel = .accurate
        let accurate = (try? probe.supportedRecognitionLanguages()) ?? []
        probe.recognitionLevel = .fast
        let fast = (try? probe.supportedRecognitionLanguages()) ?? []
        return LabEnvironment(system: ProcessInfo.processInfo.operatingSystemVersionString, machine: machine,
                              accurate: accurate, fast: fast)
    }
}
#endif
