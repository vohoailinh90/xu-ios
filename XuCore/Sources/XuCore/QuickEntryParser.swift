import Foundation

public struct QuickEntryResult: Equatable, Sendable {
    /// Số tiền theo đơn vị nhỏ nhất (VND). `nil` nếu chưa tìm thấy số tiền.
    public var amount: Int64?
    public var isIncome: Bool
    public var date: Date
    public var categoryID: String
    public var note: String
    /// Câu có nhiều số tiền tường minh — UI nên gợi ý tách khoản.
    public var hasMultipleAmounts: Bool

    public init(amount: Int64?, isIncome: Bool, date: Date, categoryID: String,
                note: String, hasMultipleAmounts: Bool = false) {
        self.amount = amount
        self.isIncome = isIncome
        self.date = date
        self.categoryID = categoryID
        self.note = note
        self.hasMultipleAmounts = hasMultipleAmounts
    }

    public var isComplete: Bool { amount != nil }
    public var category: CategoryDefinition { CategoryCatalog.resolve(id: categoryID) }
}

/// Phân tích câu nhập tự nhiên tiếng Việt: "grab 52k hôm qua", "1tr2 tiền nhà", "lương +15tr".
/// Đặc tả đầy đủ: docs/04-bo-phan-tich-nhap-nhanh.md
public struct QuickEntryParser: Sendable {
    public struct Options: Sendable {
        /// "phở 45" → 45.000đ
        public var smallNumbersAreThousands: Bool
        public init(smallNumbersAreThousands: Bool = true) {
            self.smallNumbersAreThousands = smallNumbersAreThousands
        }
    }

    public var options: Options
    public var calendar: Calendar
    public var matcher: CategoryMatcher

    public init(options: Options = Options(),
                calendar: Calendar = .current,
                matcher: CategoryMatcher = CategoryMatcher()) {
        self.options = options
        self.calendar = calendar
        self.matcher = matcher
    }

    public func parse(_ text: String, now: Date = Date()) -> QuickEntryResult {
        let (original, foldedChars) = TextFolding.foldAligned(text)
        let folded = String(foldedChars)
        var removed: [Range<Int>] = []

        // 1. Ngày
        let today = calendar.startOfDay(for: now)
        var date = today
        if let hit = findDate(in: folded, today: today) {
            date = hit.date
            removed.append(hit.range)
        }

        // 2. Số tiền (trên chuỗi đã che vùng ngày)
        let masked = Self.mask(foldedChars, ranges: removed)
        let candidates = findAmounts(in: masked)
        let explicit = candidates.filter(\.hasUnit)
        let pool = explicit.isEmpty ? candidates : explicit
        var amount: Int64?
        var signedIncome = false
        if let pick = explicit.isEmpty ? pool.max(by: { $0.value < $1.value }) : pool.first {
            amount = pick.value
            signedIncome = pick.isPlus
            removed.append(pick.range)
        }

        // 3. Ghi chú (giữ dấu từ chuỗi gốc)
        let note = Self.buildNote(original, removing: removed)

        // 4. Danh mục & thu/chi
        let matched = matcher.match(note: note)
        let isIncome = signedIncome || matched?.kind == .income
        let categoryID: String
        if isIncome {
            categoryID = (matched?.kind == .income ? matched?.id : nil) ?? CategoryCatalog.otherIncomeID
        } else {
            categoryID = matched?.id ?? CategoryCatalog.otherExpenseID
        }

        return QuickEntryResult(amount: amount, isIncome: isIncome, date: date,
                                categoryID: categoryID, note: note,
                                hasMultipleAmounts: pool.count > 1)
    }

    // MARK: - Số tiền

    struct AmountCandidate {
        let value: Int64
        let hasUnit: Bool
        let isPlus: Bool
        let range: Range<Int>
    }

    static let unitAlternation = "trieu|nghin|ngan|dong|vnd|tr|cu|k|d"
    static let multipliers: [String: Decimal] = [
        "k": 1_000, "nghin": 1_000, "ngan": 1_000,
        "tr": 1_000_000, "trieu": 1_000_000, "cu": 1_000_000,
        "d": 1, "dong": 1, "vnd": 1
    ]

    static let amountRegex = try! NSRegularExpression(
        pattern: #"(?<![\w/])([+-]?)(\d+(?:[.,]\d+)*)\s?(?:("# + QuickEntryParser.unitAlternation + #")(\d{1,3})?)?(?![\w/])"#
    )

    func findAmounts(in text: String) -> [AmountCandidate] {
        let ns = NSRange(text.startIndex..., in: text)
        return Self.amountRegex.matches(in: text, range: ns).compactMap { m in
            guard let numberText = Self.group(m, 2, in: text),
                  var value = Self.parseNumber(numberText),
                  let range = Self.characterRange(m.range, in: text) else { return nil }
            let unit = Self.group(m, 3, in: text)
            if let unit, let multiplier = Self.multipliers[unit] {
                if let suffix = Self.group(m, 4, in: text), let fraction = Decimal(string: "0." + suffix) {
                    value += fraction
                }
                value *= multiplier
            } else if options.smallNumbersAreThousands && value < 1000 {
                value *= 1000
            }
            guard value > 0 else { return nil }
            return AmountCandidate(value: Self.int64(value), hasUnit: unit != nil,
                                   isPlus: Self.group(m, 1, in: text) == "+", range: range)
        }
    }

    /// "35.000" → 35000 (phân cách nghìn) · "1.5" / "1,5" → 1.5 (thập phân)
    static func parseNumber(_ s: String) -> Decimal? {
        let parts = s.split(whereSeparator: { $0 == "." || $0 == "," }).map(String.init)
        guard let last = parts.last else { return nil }
        if parts.count == 1 { return Decimal(string: s) }
        if parts.dropFirst().allSatisfy({ $0.count == 3 }) { return Decimal(string: parts.joined()) }
        return Decimal(string: parts.dropLast().joined() + "." + last)
    }

    static func int64(_ value: Decimal) -> Int64 {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    // MARK: - Ngày

    static let explicitDateRegex = try! NSRegularExpression(
        pattern: #"(?<![\w/])(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?(?![\w/])"#
    )

    /// Thứ tự quan trọng: cụm dài/cụ thể trước.
    static let relativeDays: [(NSRegularExpression, Int)] = [
        ("hom kia", -2), ("toi qua", -1), ("dem qua", -1), ("sang qua", -1), ("hom qua", -1),
        ("hom nay", 0), ("sang nay", 0), ("trua nay", 0), ("chieu nay", 0), ("toi nay", 0)
    ].map { (try! NSRegularExpression(pattern: #"(?<!\w)"# + $0.0 + #"(?!\w)"#), $0.1) }

    /// "thu 2", "t2", "cn", "chu nhat" — nhưng KHÔNG khớp "thu 5 trieu" (thu tiền).
    static let weekdayRegex = try! NSRegularExpression(
        pattern: #"(?<!\w)(?:thu\s?([2-7])|t([2-7])|cn|chu nhat)(?!\w)(?!\s*(?:"# + QuickEntryParser.unitAlternation + #"|\d)(?!\w))"#
    )

    func findDate(in text: String, today: Date) -> (date: Date, range: Range<Int>)? {
        let ns = NSRange(text.startIndex..., in: text)

        if let m = Self.explicitDateRegex.firstMatch(in: text, range: ns),
           let dayText = Self.group(m, 1, in: text), let day = Int(dayText),
           let monthText = Self.group(m, 2, in: text), let month = Int(monthText),
           let range = Self.characterRange(m.range, in: text) {
            let currentYear = calendar.component(.year, from: today)
            var year = Self.group(m, 3, in: text).flatMap(Int.init) ?? currentYear
            if year < 100 { year += 2000 }
            if let date = makeDate(year: year, month: month, day: day) {
                if Self.group(m, 3, in: text) == nil, date > today,
                   let lastYear = makeDate(year: year - 1, month: month, day: day) {
                    return (lastYear, range)
                }
                return (date, range)
            }
        }

        for (regex, offset) in Self.relativeDays {
            if let m = regex.firstMatch(in: text, range: ns),
               let range = Self.characterRange(m.range, in: text),
               let date = calendar.date(byAdding: .day, value: offset, to: today) {
                return (date, range)
            }
        }

        if let m = Self.weekdayRegex.firstMatch(in: text, range: ns),
           let range = Self.characterRange(m.range, in: text) {
            // Gregorian: 1 = Chủ nhật, 2 = thứ Hai … 7 = thứ Bảy — trùng cách gọi "thứ 2…7".
            let target = (Self.group(m, 1, in: text) ?? Self.group(m, 2, in: text)).flatMap(Int.init) ?? 1
            let current = calendar.component(.weekday, from: today)
            let back = (current - target + 7) % 7
            if let date = calendar.date(byAdding: .day, value: -back, to: today) {
                return (date, range)
            }
        }
        return nil
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date? {
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else { return nil }
        return date
    }

    // MARK: - Tiện ích

    static func group(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        let r = match.range(at: index)
        guard r.location != NSNotFound, r.length > 0, let range = Range(r, in: text) else { return nil }
        return String(text[range])
    }

    /// NSRange (UTF-16) → khoảng theo số thứ tự Character.
    static func characterRange(_ nsRange: NSRange, in text: String) -> Range<Int>? {
        guard let range = Range(nsRange, in: text) else { return nil }
        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        let upper = text.distance(from: text.startIndex, to: range.upperBound)
        return lower..<upper
    }

    static func mask(_ chars: [Character], ranges: [Range<Int>]) -> String {
        var copy = chars
        for range in ranges {
            for i in range where copy.indices.contains(i) { copy[i] = " " }
        }
        return String(copy)
    }

    static func buildNote(_ original: [Character], removing ranges: [Range<Int>]) -> String {
        let kept = original.indices.filter { i in !ranges.contains(where: { $0.contains(i) }) }.map { original[$0] }
        let collapsed = String(kept).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-+–"))
    }
}
