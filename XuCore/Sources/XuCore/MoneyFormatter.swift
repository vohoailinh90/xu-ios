import Foundation

public enum MoneyFormatter {
    /// Dạng gọn cho widget/chip: 35000 → "35k", 1_250_000 → "1,25tr", 999 → "999đ".
    /// Dùng số nguyên để tránh sai số dấu phẩy động.
    public static func compact(_ amount: Int64) -> String {
        let sign = amount < 0 ? "-" : ""
        let value = amount.magnitude
        if value >= 1_000_000 { return sign + scaled(value, unit: 1_000_000) + "tr" }
        if value >= 1_000 { return sign + scaled(value, unit: 1_000) + "k" }
        return sign + "\(value)đ"
    }

    /// Dạng đầy đủ: 1250000 → "1.250.000đ"
    public static func full(_ amount: Int64) -> String {
        let digits = String(amount.magnitude)
        var grouped = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { grouped.append(".") }
            grouped.append(ch)
        }
        return (amount < 0 ? "-" : "") + grouped + "đ"
    }

    private static func scaled(_ value: UInt64, unit: UInt64) -> String {
        let whole = value / unit
        let hundredths = (value % unit) * 100 / unit
        if hundredths == 0 { return "\(whole)" }
        let fraction = hundredths % 10 == 0 ? "\(hundredths / 10)" : (hundredths < 10 ? "0\(hundredths)" : "\(hundredths)")
        return "\(whole),\(fraction)"
    }
}
