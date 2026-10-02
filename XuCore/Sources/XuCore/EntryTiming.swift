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

    /// Ô nhập vừa chuyển sang một câu mới, cần đo lại từ đầu (và bỏ danh mục đã chọn tay cho câu cũ):
    /// - từ rỗng sang có chữ;
    /// - câu cũ bị thay gần hết (chọn hết rồi gõ hay dán câu khác) — phần đầu và phần cuối còn giữ lại chưa tới một nửa;
    /// - một phần câu bị thay và ghi chú đổi hẳn: không còn từ nào chung, và đầu + cuối ghi chú giữ lại chưa tới một nửa
    ///   ("phở 45k" → "grab 45k").
    /// Sửa số tiền, sửa lỗi gõ ("grba" → "grab"), sửa hay thêm một từ ("cơm gà" → "cơm vịt"), thêm, xoá ở đầu hay cuối
    /// câu thì vẫn là câu đang đo.
    /// `parser` là parser của ô nhập (cùng nơi chi tiêu), để tách ghi chú và đọc số tiền.
    /// Bộ gõ tiếng Nhật (IME) đổi chữ đang soạn sang chữ Hán/katakana cũng thay cả cụm ("きのう" → "昨日"). Thay đổi chỉ
    /// được coi là IME chuyển đổi (không phải câu mới) khi:
    /// - phần bị thay chỉ gồm chữ đang soạn (hiragana, "ー", chữ/số Latin khi gõ romaji), phần mới có chữ Nhật/Hán;
    /// - phần mới chỉ gồm chữ Nhật/Hán, chữ/số Latin và khoảng trắng — không thêm dấu "+", "¥"…;
    /// - chữ Latin không tự xuất hiện thêm ("k");
    /// - số tiền parser đọc được không đổi, sau khi đổi cách đọc số trong phần bị thay sang chữ Hán
    ///   ("せんえん" → "千円" vẫn là ¥1.000; "せんえん" → "百円", "やちん980" → "家賃980万" là đổi số tiền).
    /// Ví dụ câu mới: "ラーメン980" → "寿司1200", "でんしゃ980" → "家賃1200", "でんしゃ980" → "給料+980".
    /// Vẫn là câu đang đo: "やちん8まん" → "家賃8万", "いちまんえん" → "1万円".
    ///
    /// Giới hạn đã biết (cố ý): chỉ nhìn chuỗi văn bản thì không phân biệt được IME chuyển đổi với việc chọn hết rồi
    /// dán một cụm chữ Nhật/Hán khác có cùng số tiền ("らーめん980" → "寿司980" trông giống "すし980" → "寿司980").
    /// Muốn phân biệt phải có từ điển cách đọc kanji, hoặc biết vùng đang soạn (marked text) của IME — SwiftUI
    /// `TextField` không cho biết, còn thay ô nhập nhanh bằng UIKit là đổi lớn ở đúng chỗ phải giữ quy tắc 2 giây.
    /// Chọn không đo lại trong trường hợp hiếm này để mọi câu tiếng Nhật gõ bằng IME không bị đo thiếu. Danh mục chọn
    /// tay vẫn hiện trên thẻ xem trước nên người dùng thấy trước khi lưu, và trung vị ít bị lệch bởi vài lần đo.
    public static func startsNewSentence(from old: String, to new: String, parser: QuickEntryParser) -> Bool {
        guard !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let a = Array(old), b = Array(new)
        guard !a.isEmpty else { return true }
        let (prefix, suffix) = sharedEnds(a, b)
        let replaced = a[prefix..<(a.count - suffix)]
        let inserted = b[prefix..<(b.count - suffix)]
        if !replaced.isEmpty, replaced.allSatisfy(isBeingComposed),
           inserted.contains(where: isJapanese),
           inserted.allSatisfy({ isJapanese($0) || isBeingComposed($0) || $0.isWhitespace }),
           isSubsequence(asciiLetters(inserted), of: asciiLetters(replaced)) {
            let before = String(a[..<prefix]) + numeralReadingsAsKanji(String(replaced)) + String(a[(a.count - suffix)...])
            let parsedBefore = parser.parse(before), parsedAfter = parser.parse(new)
            if parsedBefore.amount == parsedAfter.amount, parsedBefore.currency == parsedAfter.currency { return false }
        }
        if (prefix + suffix) * 2 < a.count { return true }
        // Giữ phần lớn ký tự nhưng thay hẳn ghi chú: khoản khác. Chỉ xét khi có thay (không phải gõ thêm hay xoá),
        // nên gõ từng chữ không phải đọc lại câu.
        guard !replaced.isEmpty, !inserted.isEmpty else { return false }
        // Ghi chú so sau khi gấp (bỏ dấu, chữ thường): "Cà phê" và "ca phe" là như nhau.
        let noteBefore = Array(TextFolding.fold(parser.parse(old).note))
        let noteAfter = Array(TextFolding.fold(parser.parse(new).note))
        let wordsBefore = words(noteBefore), wordsAfter = words(noteAfter)
        guard !wordsBefore.isEmpty, !wordsAfter.isEmpty, wordsBefore.isDisjoint(with: wordsAfter) else { return false }
        // Sửa lỗi gõ trong từ ("grba" → "grab") vẫn giữ phần lớn chữ của ghi chú.
        let kept = sharedEnds(noteBefore, noteAfter)
        return (kept.prefix + kept.suffix) * 2 < noteBefore.count
    }

    /// Số ký tự giống nhau ở đầu và ở cuối (không chồng lên nhau) của hai chuỗi.
    private static func sharedEnds(_ a: [Character], _ b: [Character]) -> (prefix: Int, suffix: Int) {
        var prefix = 0
        while prefix < min(a.count, b.count), a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(a.count, b.count) - prefix, a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }
        return (prefix, suffix)
    }

    /// Các từ chữ/số của ghi chú, tách ở mọi ký tự khác ("cơm, gà" → cơm, gà; kana, kanji, "ー" là chữ), để emoji chung
    /// không che việc đổi chữ ("💳 phở" → "💳 taxi"). Ghi chú không có chữ/số thì so các emoji/ký hiệu ("🍔" → "🚕").
    private static func words(_ text: [Character]) -> Set<String> {
        let alphanumeric = Set(text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { String($0) })
        guard alphanumeric.isEmpty else { return alphanumeric }
        return Set(text.filter { !$0.isWhitespace && !$0.isPunctuation }.map { String($0) })
    }

    /// Cách đọc hiragana của chữ số/đơn vị Hán mà IME đổi ra, dài trước ngắn sau ("ろっぴゃく" → "六百").
    /// Không có các cách đọc một chữ dễ trùng như "し", "く", "よ".
    private static let numeralReadings: [(reading: String, kanji: String)] = [
        ("ひゃく", "百"), ("びゃく", "百"), ("ぴゃく", "百"), ("きゅう", "九"), ("じゅう", "十"), ("じゅっ", "十"),
        ("まん", "万"), ("せん", "千"), ("ぜん", "千"), ("おく", "億"), ("えん", "円"),
        ("いち", "一"), ("いっ", "一"), ("さん", "三"), ("よん", "四"), ("ろく", "六"), ("ろっ", "六"),
        ("なな", "七"), ("しち", "七"), ("はち", "八"), ("はっ", "八"), ("に", "二"), ("ご", "五"),
    ]

    private static func numeralReadingsAsKanji(_ text: String) -> String {
        numeralReadings.reduce(text) { $0.replacingOccurrences(of: $1.reading, with: $1.kanji) }
    }

    /// Chữ Nhật/Hán (kana, kanji, "々", "〇").
    private static func isJapanese(_ character: Character) -> Bool {
        character == "〇" || TextFolding.containsCJK(String(character))
    }

    /// Các chữ cái ASCII (sau khi gấp về chữ thường, nửa khổ), theo thứ tự.
    private static func asciiLetters(_ characters: ArraySlice<Character>) -> [Character] {
        characters.map { TextFolding.fold($0) }.filter { $0.isASCII && $0.isLetter }
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
