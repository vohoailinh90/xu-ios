import Foundation

/// Thời gian ghi một khoản bằng ô nhập nhanh (giây), lưu **chỉ trên máy** để biết Xu có giữ được
/// quy tắc 2 giây không (docs/01: trung vị < 3 giây). Không gửi đi đâu.
///
/// Đo từ ký tự đầu tiên gõ vào ô đến lúc lưu: ô nhập tự focus khi mở app và giữ focus sau khi lưu,
/// nên thời điểm focus không cho biết người dùng bắt đầu ghi lúc nào.
public struct EntryTimingLog: Codable, Equatable, Sendable {
    /// Giữ bấy nhiêu lần gần nhất.
    public static let capacity = 200
    /// Lâu hơn thế là bỏ dở giữa chừng (gõ dở rồi làm việc khác), không tính.
    public static let abandonedAfter: Double = 60

    public private(set) var samples: [Double]

    public init(samples: [Double] = []) {
        self.samples = samples
    }

    /// Trả về số giây đã lưu (`nil` nếu bỏ qua), để gắn với lần lưu và xoá đi khi người dùng hoàn tác.
    @discardableResult
    public mutating func record(_ seconds: Double) -> Double? {
        guard seconds > 0, seconds <= Self.abandonedAfter else { return nil }
        samples.append(seconds)
        if samples.count > Self.capacity { samples.removeFirst(samples.count - Self.capacity) }
        return seconds
    }

    /// Hoàn tác khoản vừa lưu: bỏ lần đo của nó (lần gần nhất có đúng giá trị này).
    public mutating func remove(_ seconds: Double) {
        if let index = samples.lastIndex(of: seconds) { samples.remove(at: index) }
    }

    /// Ô nhập vừa chuyển sang một câu mới, cần đo lại từ đầu: từ rỗng sang có chữ, hoặc câu cũ bị thay gần hết
    /// (chọn hết rồi gõ hay dán câu khác) — phần đầu và phần cuối còn giữ lại chưa tới một nửa câu cũ.
    /// Sửa vài chữ, thêm, xoá ở đầu hay cuối câu thì vẫn là câu đang đo.
    /// Cả câu cũ lẫn câu mới đều có chữ Nhật/Hán thì không xét "thay cả câu": bộ gõ (IME) đổi "きのう" thành "昨日"
    /// cũng thay cả cụm đang soạn. Một bên không có chữ Nhật/Hán ("ラーメン980" → "cà phê 35k") thì không phải IME.
    public static func startsNewSentence(from old: String, to new: String) -> Bool {
        guard !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let a = Array(old), b = Array(new)
        guard !a.isEmpty else { return true }
        guard !(TextFolding.containsCJK(old) && TextFolding.containsCJK(new)) else { return false }
        var prefix = 0
        while prefix < min(a.count, b.count), a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(a.count, b.count) - prefix, a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }
        return (prefix + suffix) * 2 < a.count
    }

    public var count: Int { samples.count }

    public var median: Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
