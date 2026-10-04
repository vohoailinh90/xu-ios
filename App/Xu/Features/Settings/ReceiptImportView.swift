#if DEBUG
import CryptoKit
import ImageIO
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import Vision
import XuCore

/// Nhập nhiều biên lai chuyển khoản một lượt (docs/11) — **chỉ có trong bản Debug** (`#if DEBUG`): chưa vào TestFlight/App Store, nên chữ ở đây
/// không qua `L10n`. Mở ra cho người dùng khi (1) Vision được kiểm trên iPhone thật với đủ 50 ảnh (docs/11), (2) chủ dự án duyệt các chi tiết
/// đếm lượt, (3) dịch chữ sang vi/en/ja.
///
/// Luồng: chọn nhiều ảnh → đọc lần lượt (Vision `.accurate` trên máy) → danh sách thẻ "số tiền · ngày" → một chạm "Lưu". Quy tắc nằm ở XuCore
/// (`ReceiptBatch`, `ReceiptQuota`, test được): bản Free đọc 5 ảnh mỗi tháng và dừng khi hết lượt, ảnh trùng/ảnh lỗi/ảnh không thấy số tiền không bị
/// trừ lượt, thẻ không chắc (hai số cùng điểm) không được chọn sẵn. Ghi tay không bao giờ bị ảnh hưởng.
///
/// Riêng tư (luật 6): ảnh và chữ OCR chỉ nằm trong bộ nhớ, không lưu, không gửi đi; không xin quyền thư viện ảnh. Khoản lưu chỉ có số tiền, ngày,
/// danh mục "Khác" và **ghi chú trống** (`rawInput` rỗng): không lưu tên người nhận, số tài khoản hay chữ OCR.
///
/// Chưa đọc: ngày giờ, tên người nhận, nội dung (docs/11) — ngày mặc định là hôm nay, chỉnh trên từng thẻ; chưa đối chiếu với khoản đã có.
struct ReceiptImportView: View {
    @Environment(\.modelContext) private var context
    @State private var picked: [PhotosPickerItem] = []
    @State private var cards: [ReceiptCard] = []
    @State private var isReading = false
    @State private var notice: String?
    @State private var quota = AppSettings.receiptQuota
    private let store = ProStore.shared

    private var month: MonthKey { MonthKey(DayKey(Date(), calendar: .current)) }

    private var allowanceText: String {
        if store.isPro { return "Xu Pro: đọc không giới hạn" }
        let left = (quota ?? ReceiptQuota(month: month)).remaining(isPro: false, in: month) ?? 0
        return "Bản Free: còn \(left)/\(ProPlan.freeReceiptReadsPerMonth) ảnh trong tháng này"
    }

    var body: some View {
        List {
            Section {
                PhotosPicker(selection: $picked, maxSelectionCount: ReceiptBatch.maxImagesPerBatch, matching: .images) {
                    Label(isReading ? "Đang đọc…" : "Chọn ảnh biên lai (tối đa \(ReceiptBatch.maxImagesPerBatch))",
                          systemImage: "photo.on.rectangle")
                }
                .disabled(isReading)
                Text(allowanceText).font(.callout).foregroundStyle(.secondary)
            } footer: {
                Text("Chỉ dùng biên lai của chính bạn. Ảnh và chữ đọc được chỉ nằm trong bộ nhớ lúc xem, không lưu, không gửi đi. Khoản lưu chỉ có số tiền, ngày và danh mục \"Khác\"; không lưu tên người nhận hay số tài khoản. Chưa đọc ngày: mặc định hôm nay, chỉnh trên từng thẻ.")
            }

            if let notice {
                Section { Text(notice) }
            }

            ForEach($cards) { $card in
                Section {
                    cardContent($card)
                } header: {
                    Text("Ảnh \(card.index + 1)")
                }
            }

            if !cards.isEmpty {
                Section {
                    Button("Lưu \(saveable.count) khoản") { save() }
                        .disabled(saveable.isEmpty || isReading)
                }
            }
        }
        .navigationTitle("Nhập nhiều biên lai")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: picked) {
            Task { await readBatch() }
        }
    }

    @ViewBuilder
    private func cardContent(_ card: Binding<ReceiptCard>) -> some View {
        switch card.wrappedValue.outcome {
        case let .amount(_, _, isAmbiguous):
            Toggle("Lưu khoản này", isOn: card.isSelected)
            if isAmbiguous {
                Label("Có hai số cùng điểm: kiểm lại số tiền trước khi lưu", systemImage: "questionmark.circle")
                    .foregroundStyle(.orange)
            }
            HStack {
                TextField("Số tiền", text: card.amountText)
                    .keyboardType(.numberPad)
                    .monospacedDigit()
                Text("đ").foregroundStyle(.secondary)
            }
            Toggle("Tiền vào (thu nhập)", isOn: card.isIncome)
            DatePicker("Ngày", selection: card.day, displayedComponents: .date)
        case .noAmount:
            Label("Không thấy số tiền trong ảnh này. Không bị trừ lượt; ghi tay nhé.", systemImage: "text.magnifyingglass")
        case .failed:
            Label("Không đọc được ảnh này. Không bị trừ lượt.", systemImage: "exclamationmark.triangle")
        case let .duplicate(of):
            Label("Giống ảnh \(of + 1): bỏ qua, không bị trừ lượt.", systemImage: "doc.on.doc")
        case .skippedNoQuota:
            Label("Hết lượt miễn phí tháng này nên chưa đọc ảnh này. Ghi tay, hoặc mở khoá Xu Pro.", systemImage: "lock")
        }
    }

    // MARK: - Lưu

    private func amount(of card: ReceiptCard) -> Int64? {
        Int64(card.amountText.filter(\.isNumber)).flatMap { $0 > 0 ? $0 : nil }
    }

    /// Thẻ được chọn và có số tiền hợp lệ.
    private var saveable: [ReceiptCard] {
        cards.filter { $0.isSelected && amount(of: $0) != nil }
    }

    @MainActor
    private func save() {
        let results = saveable.compactMap { card -> QuickEntryResult? in
            guard let value = amount(of: card) else { return nil }
            return QuickEntryResult(amount: value, currency: .vnd, isIncome: card.isIncome, date: card.day,
                                    categoryID: card.isIncome ? CategoryCatalog.otherIncomeID : CategoryCatalog.otherExpenseID,
                                    note: "")
        }
        guard !results.isEmpty else { return }
        do {
            // `rawInput` trống: không lưu chữ OCR (có tên người nhận, số tài khoản).
            try Ledger.save(results, rawInput: "", source: .screenshot, in: context)
            notice = "Đã lưu \(results.count) khoản (danh mục \"Khác\", ghi chú trống)."
            cards = []
            picked = []
        } catch {
            notice = "Không lưu được: \(error.localizedDescription)"
        }
    }

    // MARK: - Đọc

    @MainActor
    private func readBatch() async {
        guard !picked.isEmpty else {
            cards = []
            return
        }
        isReading = true
        defer { isReading = false }
        notice = nil
        cards = []
        let items = picked
        var current = quota ?? ReceiptQuota(month: month)
        let box = ImageBox()
        let outcomes = await ReceiptBatch.run(
            count: items.count, isPro: store.isPro, month: month, quota: &current,
            fingerprint: { index in
                guard let data = try? await items[index].loadTransferable(type: Data.self) else { return nil }
                box.data[index] = data
                // Dấu vân tay để phát hiện ảnh trùng byte; chỉ nằm trong bộ nhớ.
                return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            },
            recognize: { index in
                guard let data = box.data.removeValue(forKey: index) else { return nil }
                return await Self.recognizeText(in: data)
            })
        box.data.removeAll()
        quota = current
        AppSettings.receiptQuota = current
        cards = outcomes.enumerated().map { ReceiptCard(index: $0.offset, outcome: $0.element) }
    }

    /// Chữ của ảnh, mỗi hàng một dòng, các ô cùng hàng nối bằng " | " (ghép nhãn với giá trị theo toạ độ, docs/11). `nil` nếu không mở được ảnh
    /// hoặc Vision báo lỗi.
    private static func recognizeText(in data: Data) async -> String? {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return nil }
        let orientation = cgOrientation(image.imageOrientation)
        let languages = recognitionLanguages
        return await Task.detached(priority: .userInitiated) { () -> String? in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if !languages.isEmpty { request.recognitionLanguages = languages }
            do {
                try VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:]).perform([request])
            } catch {
                return nil
            }
            let lines = (request.results ?? []).compactMap { observation in
                observation.topCandidates(1).first.map { ReceiptTextLine(text: $0.string, box: observation.boundingBox) }
            }
            return groupRows(lines).map { $0.map(\.text).joined(separator: " | ") }.joined(separator: "\n")
        }.value
    }

    /// Việt + Anh nếu máy có `vi-VT` ở chế độ chính xác; không thì để Vision tự chọn (đặt mã không hỗ trợ có thể làm Vision báo lỗi).
    private static let recognitionLanguages: [String] = {
        let probe = VNRecognizeTextRequest()
        probe.recognitionLevel = .accurate
        let supported = (try? probe.supportedRecognitionLanguages()) ?? []
        func pick(_ prefix: String) -> String? { supported.first { $0.lowercased().hasPrefix(prefix) } }
        guard let vietnamese = pick("vi") else { return [] }
        return [vietnamese, pick("en")].compactMap { $0 }
    }()

    /// Gom các ô chữ cùng một hàng (khoảng cách dọc giữa tâm nhỏ hơn 0,6 chiều cao chữ), trong hàng sắp từ trái sang phải.
    private static func groupRows(_ lines: [ReceiptTextLine]) -> [[ReceiptTextLine]] {
        var groups: [[ReceiptTextLine]] = []
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

/// Dữ liệu ảnh đã mở, chờ bộ đọc; xoá ngay sau khi đọc để không giữ cả lượt ảnh trong bộ nhớ.
private final class ImageBox {
    var data: [Int: Data] = [:]
}

private struct ReceiptTextLine {
    let text: String
    let box: CGRect   // toạ độ chuẩn hoá của Vision, gốc ở góc dưới trái
}

/// Một thẻ trên màn hình: kết quả đọc và phần người dùng chỉnh được (chọn lưu, số tiền, thu/chi, ngày).
private struct ReceiptCard: Identifiable {
    let id = UUID()
    let index: Int
    let outcome: ReceiptReadOutcome
    var isSelected: Bool
    var amountText: String
    var isIncome: Bool
    var day = Date()

    init(index: Int, outcome: ReceiptReadOutcome) {
        self.index = index
        self.outcome = outcome
        self.isSelected = outcome.isPreselected
        if case let .amount(value, income, _) = outcome {
            self.amountText = String(value)
            self.isIncome = income
        } else {
            self.amountText = ""
            self.isIncome = false
        }
    }
}
#endif
