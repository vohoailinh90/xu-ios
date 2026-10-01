import Foundation

/// Định dạng tiền bằng số nguyên (không qua `Double`, không phụ thuộc `Locale` của máy).
///
/// | | Tiếng Việt | English | 日本語 |
/// |---|---|---|---|
/// | VND đầy đủ | 1.250.000đ | 1,250,000₫ | 1,250,000₫ |
/// | VND gọn | 1,25tr · 35k | 1.25M₫ · 35K₫ | 1.25M₫ · 35K₫ |
/// | JPY (đầy đủ = gọn) | ¥1.250 | ¥1,250 | 1,250円 |
public enum MoneyFormatter {
    /// Dạng gọn cho widget/chip: 35000 → "35k", 1_250_000 → "1,25tr", 999 → "999đ".
    public static func compact(_ amount: Int64, currency: Currency = .vnd, language: AppLanguage = .vi) -> String {
        guard currency == .vnd else { return full(amount, currency: currency, language: language) }
        let sign = amount < 0 ? "-" : ""
        let value = amount.magnitude
        if language == .vi {
            if value >= 1_000_000 { return sign + scaled(value, unit: 1_000_000, decimal: ",") + "tr" }
            if value >= 1_000 { return sign + scaled(value, unit: 1_000, decimal: ",") + "k" }
            return sign + "\(value)đ"
        }
        if value >= 1_000_000 { return sign + scaled(value, unit: 1_000_000, decimal: ".") + "M₫" }
        if value >= 1_000 { return sign + scaled(value, unit: 1_000, decimal: ".") + "K₫" }
        return sign + "\(value)₫"
    }

    /// Dạng đầy đủ: 1250000 → "1.250.000đ"
    public static func full(_ amount: Int64, currency: Currency = .vnd, language: AppLanguage = .vi) -> String {
        let sign = amount < 0 ? "-" : ""
        let digits = grouped(amount.magnitude, separator: language == .vi ? "." : ",")
        switch (currency, language) {
        case (.vnd, .vi): return sign + digits + "đ"
        case (.vnd, _): return sign + digits + "₫"
        case (.jpy, .ja): return sign + digits + "円"
        case (.jpy, _): return sign + "¥" + digits
        }
    }

    /// Có dấu "+" cho khoản thu, dùng ở danh sách và thẻ xem trước.
    public static func signed(_ amount: Int64, isIncome: Bool, currency: Currency = .vnd,
                              language: AppLanguage = .vi, compact useCompact: Bool = false) -> String {
        let text = useCompact ? compact(amount, currency: currency, language: language)
                              : full(amount, currency: currency, language: language)
        return (isIncome ? "+" : "") + text
    }

    private static func grouped(_ value: UInt64, separator: String) -> String {
        let digits = String(value)
        var result = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { result += separator }
            result.append(ch)
        }
        return result
    }

    private static func scaled(_ value: UInt64, unit: UInt64, decimal: String) -> String {
        let whole = value / unit
        let hundredths = (value % unit) * 100 / unit
        if hundredths == 0 { return "\(whole)" }
        let fraction = hundredths % 10 == 0 ? "\(hundredths / 10)" : (hundredths < 10 ? "0\(hundredths)" : "\(hundredths)")
        return "\(whole)\(decimal)\(fraction)"
    }
}
