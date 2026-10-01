import Foundation

/// Gấp chuỗi tiếng Việt về dạng thường, không dấu (`đ` → `d`) để so khớp.
///
/// Quan trọng: việc gấp được làm **từng ký tự một** và luôn trả về đúng một `Character`
/// cho mỗi ký tự gốc. Nhờ vậy vị trí trong chuỗi đã gấp khớp 1:1 với chuỗi gốc,
/// và ta có thể cắt ghi chú từ chuỗi gốc mà vẫn giữ nguyên dấu.
public enum TextFolding {
    private static let vietnamese = Locale(identifier: "vi_VN")

    public static func fold(_ character: Character) -> Character {
        if character == "đ" || character == "Đ" { return "d" }
        let lower = String(character).lowercased()
        let folded = lower.folding(options: [.diacriticInsensitive], locale: vietnamese)
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
}
