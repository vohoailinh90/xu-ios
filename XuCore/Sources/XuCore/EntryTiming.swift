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
    /// Bộ gõ tiếng Nhật (IME) đổi chữ đang soạn sang chữ Hán/katakana cũng thay cả cụm ("きのう" → "昨日"). Thay đổi chỉ
    /// được coi là IME chuyển đổi (không phải câu mới) khi giữ nguyên mọi thứ làm đổi số tiền:
    /// - phần bị thay chỉ gồm chữ đang soạn (hiragana, "ー", chữ/số Latin khi gõ romaji), phần mới có chữ Nhật/Hán;
    /// - phần mới chỉ gồm chữ Nhật/Hán, chữ/số Latin và khoảng trắng — không thêm dấu "+", "¥"…;
    /// - chữ số giữ nguyên, chữ Latin không tự xuất hiện thêm ("k");
    /// - mỗi chữ đơn vị tiền mới (万 千 百 億 円) phải có cách đọc của nó trong phần bị thay ("まん" → "万").
    /// Ví dụ câu mới: "ラーメン980" → "寿司1200", "でんしゃ980" → "家賃1200", "やちん980" → "家賃980万",
    /// "でんしゃ980" → "給料+980". Vẫn là câu đang đo: "やちん8まん" → "家賃8万", "せんえん" → "千円".
    public static func startsNewSentence(from old: String, to new: String) -> Bool {
        guard !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let a = Array(old), b = Array(new)
        guard !a.isEmpty else { return true }
        var prefix = 0
        while prefix < min(a.count, b.count), a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(a.count, b.count) - prefix, a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }
        let replaced = a[prefix..<(a.count - suffix)]
        let inserted = b[prefix..<(b.count - suffix)]
        if !replaced.isEmpty, replaced.allSatisfy(isBeingComposed),
           inserted.contains(where: isJapanese),
           inserted.allSatisfy({ isJapanese($0) || isBeingComposed($0) || $0.isWhitespace }),
           ascii(replaced, where: \.isNumber) == ascii(inserted, where: \.isNumber),
           isSubsequence(ascii(inserted, where: \.isLetter), of: ascii(replaced, where: \.isLetter)),
           inserted.filter({ amountUnits.contains($0) }).count <= unitReadingCount(in: String(replaced)) {
            return false
        }
        return (prefix + suffix) * 2 < a.count
    }

    /// Chữ đơn vị làm đổi số tiền khi parser đọc ("980万", "千円"), và cách đọc hiragana mà IME đổi ra chúng.
    private static let amountUnits: Set<Character> = ["万", "千", "百", "億", "円"]
    private static let unitReadings = ["まん", "せん", "ぜん", "ひゃく", "びゃく", "ぴゃく", "おく", "えん"]

    private static func unitReadingCount(in text: String) -> Int {
        unitReadings.reduce(0) { $0 + text.components(separatedBy: $1).count - 1 }
    }

    /// Chữ Nhật/Hán (kana, kanji, "々", "〇").
    private static func isJapanese(_ character: Character) -> Bool {
        character == "〇" || TextFolding.containsCJK(String(character))
    }

    /// Các ký tự ASCII (sau khi gấp về chữ thường, nửa khổ) thoả `predicate`, theo thứ tự.
    /// Số viết bằng chữ Hán ("千") không phải ASCII nên không tính.
    private static func ascii(_ characters: ArraySlice<Character>, where predicate: (Character) -> Bool) -> [Character] {
        characters.map { TextFolding.fold($0) }.filter { $0.isASCII && predicate($0) }
    }

    /// `part` là dãy con (giữ thứ tự) của `whole`: romaji có thể biến mất khi thành kana, không thể tự thêm vào.
    private static func isSubsequence(_ part: [Character], of whole: [Character]) -> Bool {
        var remaining = whole[...]
        for character in part {
            guard let index = remaining.firstIndex(of: character) else { return false }
            remaining = remaining[(index + 1)...]
        }
        return true
    }

    /// Ký tự có thể đang nằm trong vùng soạn của IME tiếng Nhật: hiragana, "ー", chữ/số Latin (nửa hoặc toàn khổ).
    private static func isBeingComposed(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1, let value = character.unicodeScalars.first?.value else { return false }
        switch value {
        case 0x3040...0x309F, 0x30FC,                  // hiragana, ー
             0x30...0x39, 0x41...0x5A, 0x61...0x7A,     // 0-9, A-Z, a-z
             0xFF10...0xFF19, 0xFF21...0xFF3A, 0xFF41...0xFF5A: // toàn khổ
            return true
        default:
            return false
        }
    }

    public var count: Int { samples.count }

    public var median: Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
