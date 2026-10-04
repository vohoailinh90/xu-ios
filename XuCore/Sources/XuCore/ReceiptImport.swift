import Foundation

/// Hạn mức đọc ảnh chuyển khoản của bản Free (`ProPlan.freeReceiptReadsPerMonth`, docs/02 và docs/11). Chỉ nằm trên máy.
///
/// Cách đếm là diễn giải của tôi từ câu "5 ảnh miễn phí 1 tháng", chủ dự án chưa duyệt từng điểm (docs/11): tháng dương lịch, đặt lại vào ngày 1;
/// chỉ trừ lượt khi OCR **đã đọc thành công** (tìm được số tiền), dù người dùng có lưu hay không. Ảnh lỗi, không thấy số tiền, ảnh trùng
/// và ảnh chưa đọc vì hết lượt không bị trừ.
public struct ReceiptQuota: Codable, Equatable, Sendable {
    public private(set) var year: Int
    public private(set) var month: Int
    public private(set) var used: Int

    public init(month: MonthKey, used: Int = 0) {
        self.year = month.year
        self.month = month.month
        self.used = max(0, used)
    }

    private func isSameMonth(as other: MonthKey) -> Bool { year == other.year && month == other.month }

    /// Lượt đã dùng trong tháng `month`: sang tháng khác thì là 0.
    public func used(in month: MonthKey) -> Int { isSameMonth(as: month) ? used : 0 }

    /// Số lượt còn lại trong tháng `month`; `nil` = không giới hạn (Xu Pro).
    public func remaining(isPro: Bool, in month: MonthKey) -> Int? {
        isPro ? nil : max(0, ProPlan.freeReceiptReadsPerMonth - used(in: month))
    }

    public func canRead(isPro: Bool, in month: MonthKey) -> Bool {
        remaining(isPro: isPro, in: month).map { $0 > 0 } ?? true
    }

    /// Ghi một lượt đã dùng; sang tháng mới thì bắt đầu đếm lại từ 1.
    public mutating func recordRead(in month: MonthKey) {
        if !isSameMonth(as: month) { self = ReceiptQuota(month: month) }
        used += 1
    }
}

/// Kết quả đọc một ảnh trong lượt chọn nhiều ảnh.
public enum ReceiptReadOutcome: Equatable, Sendable {
    /// Đọc được số tiền. `isAmbiguous`: có số khác cùng điểm, người dùng nên xem lại (`ReceiptAmountReader.Reading`).
    case amount(Int64, isIncome: Bool, isAmbiguous: Bool)
    /// Đọc xong nhưng không thấy số tiền nào có dạng số tiền.
    case noAmount
    /// Không mở được ảnh hoặc bộ đọc báo lỗi.
    case failed
    /// Giống hệt ảnh có thứ tự `of` (đếm từ 0) đã chọn trước đó.
    case duplicate(of: Int)
    /// Chưa đọc vì bản Free hết lượt tháng này.
    case skippedNoQuota

    /// Chỉ ảnh đọc ra số tiền mới trừ lượt.
    public var consumesQuota: Bool {
        if case .amount = self { return true }
        return false
    }

    /// Thẻ được chọn sẵn để lưu: có số tiền và không nhập nhằng. Thẻ không chắc không bao giờ tự chọn sẵn.
    public var isPreselected: Bool {
        if case let .amount(_, _, isAmbiguous) = self { return !isAmbiguous }
        return false
    }
}

/// Đọc nhiều ảnh chuyển khoản một lượt (docs/11): đọc lần lượt từng ảnh, dừng đọc khi bản Free hết lượt, bỏ ảnh trùng.
/// Thuần quy tắc: việc mở ảnh và chạy Vision do app truyền vào, nên test được bằng `swift test`.
public enum ReceiptBatch {
    /// Giới hạn số ảnh mỗi lượt chọn trong app (đọc lần lượt để không tốn bộ nhớ).
    public static let maxImagesPerBatch = 20

    /// Chữ đọc được từ một ảnh (`nil` = không đọc được) → kết quả. Chỉ chọn số tiền, chưa đọc tên người nhận, nội dung, ngày giờ.
    public static func outcome(forRecognizedText text: String?) -> ReceiptReadOutcome {
        guard let text else { return .failed }
        guard let reading = ReceiptAmountReader.read(text) else { return .noAmount }
        return .amount(reading.best.value, isIncome: reading.best.hasPlusSign, isAmbiguous: reading.isAmbiguous)
    }

    /// - `fingerprint(i)`: dấu vân tay của ảnh thứ `i` (ví dụ SHA-256 dữ liệu ảnh), `nil` nếu không mở được ảnh.
    /// - `recognize(i)`: chữ OCR của ảnh thứ `i`, `nil` nếu bộ đọc lỗi. Chỉ gọi cho ảnh duy nhất, khi còn lượt.
    /// - `quota`: cập nhật tại chỗ; người dùng Pro không bị đếm.
    /// Trả về đúng `count` kết quả, theo thứ tự ảnh.
    public static func run(count: Int, isPro: Bool, month: MonthKey, quota: inout ReceiptQuota,
                           fingerprint: (Int) async -> String?,
                           recognize: (Int) async -> String?) async -> [ReceiptReadOutcome] {
        var outcomes: [ReceiptReadOutcome] = []
        var firstIndexByFingerprint: [String: Int] = [:]
        for index in 0..<max(0, count) {
            guard quota.canRead(isPro: isPro, in: month) else {
                outcomes.append(.skippedNoQuota)
                continue
            }
            guard let signature = await fingerprint(index) else {
                outcomes.append(.failed)
                continue
            }
            if let first = firstIndexByFingerprint[signature] {
                outcomes.append(.duplicate(of: first))
                continue
            }
            firstIndexByFingerprint[signature] = index
            let text = await recognize(index)
            let result = outcome(forRecognizedText: text)
            if result.consumesQuota, !isPro { quota.recordRead(in: month) }
            outcomes.append(result)
        }
        return outcomes
    }
}
