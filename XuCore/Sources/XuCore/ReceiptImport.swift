import Foundation

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
    /// - `quota`: cập nhật tại chỗ (hạn mức `ProPlan.freeReceiptReadsPerMonth` mỗi tháng); người dùng Pro không bị đếm.
    ///   Cách đếm: chỉ ảnh OCR đã đọc ra số tiền mới bị trừ lượt (docs/11).
    /// Trả về đúng `count` kết quả, theo thứ tự ảnh.
    public static func run(count: Int, isPro: Bool, month: MonthKey, quota: inout MonthlyQuota,
                           fingerprint: (Int) async -> String?,
                           recognize: (Int) async -> String?) async -> [ReceiptReadOutcome] {
        var outcomes: [ReceiptReadOutcome] = []
        var firstIndexByFingerprint: [String: Int] = [:]
        for index in 0..<max(0, count) {
            guard quota.canUse(limit: ProPlan.freeReceiptReadsPerMonth, isPro: isPro, in: month) else {
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
            if result.consumesQuota, !isPro { quota.recordUse(in: month) }
            outcomes.append(result)
        }
        return outcomes
    }
}
