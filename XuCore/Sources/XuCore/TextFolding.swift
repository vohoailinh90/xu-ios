import Foundation

/// Gấp chuỗi về dạng thường để so khớp: chữ thường, bỏ dấu tiếng Việt (`đ` → `d`),
/// chữ/số toàn khổ của bàn phím Nhật về nửa khổ (`３５０円` → `350円`, `￥` → `¥`).
///
/// Quan trọng: việc gấp được làm **từng ký tự một** và luôn trả về đúng một `Character`
/// cho mỗi ký tự gốc. Nhờ vậy vị trí trong chuỗi đã gấp khớp 1:1 với chuỗi gốc,
/// và ta có thể cắt ghi chú từ chuỗi gốc mà vẫn giữ nguyên dấu.
public enum TextFolding {
    private static let vietnamese = Locale(identifier: "vi_VN")

    public static func fold(_ character: Character) -> Character {
        if character == "đ" || character == "Đ" { return "d" }
        var options: String.CompareOptions = [.widthInsensitive]
        // Chỉ bỏ dấu cho chữ Latin. Với kana, "dấu" là ゛゜: bỏ đi thì バス (xe buýt) thành ハス,
        // trùng với パス, và パスタ bị hiểu là đi lại.
        if isLatin(character) { options.insert(.diacriticInsensitive) }
        let lower = String(character).lowercased()
        let folded = lower.folding(options: options, locale: vietnamese)
        if folded.count == 1, let first = folded.first { return first }
        if lower.count == 1, let first = lower.first { return first }
        return character
    }

    /// Trả về (các ký tự gốc đã chuẩn hóa NFC, các ký tự đã gấp) có cùng độ dài.
    public static func foldAligned(_ text: String) -> (original: [Character], folded: [Character]) {
        let original = Array(text.precomposedStringWithCanonicalMapping)
        return (original, original.map(fold))
    }

    public static func fold(_ text: String) -> String {
        String(foldAligned(text).folded)
    }

    /// Chỉ chữ thường và nửa khổ, **giữ dấu**: "ＴＵＩ Túi" → "tui túi". Dùng để biết người dùng có gõ dấu
    /// tiếng Việt hay không mà không nhầm chữ toàn khổ của bàn phím Nhật là dấu.
    public static func foldWidth(_ text: String) -> String {
        String(text.precomposedStringWithCanonicalMapping.map { character -> Character in
            let lower = String(character).lowercased()
            let folded = lower.folding(options: [.widthInsensitive], locale: vietnamese)
            if folded.count == 1, let first = folded.first { return first }
            if lower.count == 1, let first = lower.first { return first }
            return character
        })
    }

    /// Chữ có chữ Nhật/Hán (kana, kanji) — không có khoảng trắng giữa các từ nên phải so khớp chuỗi con.
    public static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3005, 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0xFF66...0xFF9F: true
            default: false
            }
        }
    }

    /// Latin cơ bản, Latin-1, Latin mở rộng A/B và "Latin mở rộng thêm" (nơi có ạ, ấ, ữ… của tiếng Việt).
    private static func isLatin(_ character: Character) -> Bool {
        guard let value = character.unicodeScalars.first?.value else { return false }
        return value < 0x0250 || (0x1E00...0x1EFF).contains(value)
    }
}
