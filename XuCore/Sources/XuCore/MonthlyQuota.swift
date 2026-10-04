import Foundation

/// Bộ đếm lượt dùng một tính năng miễn phí trong **tháng dương lịch** (docs/02): đọc ảnh chuyển khoản, tự ghi Apple Pay. Chỉ nằm trên máy.
///
/// Giới hạn do nơi gọi truyền vào (`ProPlan.free…PerMonth`), không lưu cùng bộ đếm, nên đổi giới hạn không cần đổi dữ liệu đã lưu.
/// Sang tháng mới thì đếm lại từ 0 vào ngày 1; Xu Pro không bị đếm. **Không bao giờ** dùng cho việc ghi tay, ghi nhanh hay xuất dữ liệu.
///
/// Cách đếm lượt là diễn giải của tôi từ quyết định của chủ dự án (docs/11), chưa duyệt từng điểm.
public struct MonthlyQuota: Codable, Equatable, Sendable {
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
    public func remaining(limit: Int, isPro: Bool, in month: MonthKey) -> Int? {
        isPro ? nil : max(0, limit - used(in: month))
    }

    public func canUse(limit: Int, isPro: Bool, in month: MonthKey) -> Bool {
        remaining(limit: limit, isPro: isPro, in: month).map { $0 > 0 } ?? true
    }

    /// Ghi một lượt đã dùng; sang tháng mới thì bắt đầu đếm lại từ 1.
    public mutating func recordUse(in month: MonthKey) {
        if !isSameMonth(as: month) { self = MonthlyQuota(month: month) }
        used += 1
    }
}
