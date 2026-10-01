import Foundation

public struct QuickEntryResult: Equatable, Sendable {
    /// Số tiền theo đơn vị nhỏ nhất của `currency` (đồng, yên). `nil` nếu chưa tìm thấy số tiền.
    public var amount: Int64?
    public var currency: Currency
    public var isIncome: Bool
    public var date: Date
    public var categoryID: String
    public var note: String
    /// Câu có nhiều số tiền tường minh — UI nên gợi ý tách khoản.
    public var hasMultipleAmounts: Bool

    public init(amount: Int64?, currency: Currency = .vnd, isIncome: Bool, date: Date, categoryID: String,
                note: String, hasMultipleAmounts: Bool = false) {
        self.amount = amount
        self.currency = currency
        self.isIncome = isIncome
        self.date = date
        self.categoryID = categoryID
        self.note = note
        self.hasMultipleAmounts = hasMultipleAmounts
    }

    public var isComplete: Bool { amount != nil }
    public var category: CategoryDefinition { CategoryCatalog.resolve(id: categoryID) }
}

/// Phân tích câu nhập tự nhiên: "grab 52k hôm qua", "1tr2 tiền nhà", "lương +15tr",
/// "コーヒー 350円", "昨日 電車 220", "cơm 1 man 2", "lunch 1200 yesterday".
/// Đặc tả đầy đủ: docs/04-bo-phan-tich-nhap-nhanh.md
public struct QuickEntryParser: Sendable {
    public struct Options: Sendable {
        /// "phở 45" → 45.000đ. Chỉ áp dụng cho tiền đồng.
        public var smallNumbersAreThousands: Bool
        /// Nơi tiêu tiền: tiền mặc định, thứ tự ngày/tháng, từ lóng "man"/"sen".
        public var market: Market

        public init(smallNumbersAreThousands: Bool = true, market: Market = .vietnam) {
            self.smallNumbersAreThousands = smallNumbersAreThousands
            self.market = market
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
            removed.append(Self.includingParticle(hit.range, in: foldedChars))
        }

        // 2. Số tiền (trên chuỗi đã che vùng ngày và tên cửa hàng có số như "100均")
        let masked = Self.mask(foldedChars, ranges: removed + Self.ranges(of: Self.numericNameRegex, in: folded))
        let candidates = findAmounts(in: masked)
        let explicit = candidates.filter(\.hasUnit)
        let pool = explicit.isEmpty ? candidates : explicit
        var amount: Int64?
        var currency = options.market.currency
        var signedIncome = false
        if let pick = explicit.isEmpty ? pool.max(by: { $0.value < $1.value }) : pool.first {
            amount = pick.value
            currency = pick.currency
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

        return QuickEntryResult(amount: amount, currency: currency, isIncome: isIncome, date: date,
                                categoryID: categoryID, note: note,
                                hasMultipleAmounts: pool.count > 1)
    }

    // MARK: - Số tiền

    struct AmountCandidate {
        let value: Int64
        let currency: Currency
        let hasUnit: Bool
        let isPlus: Bool
        let range: Range<Int>
    }

    /// Ranh giới từ chỉ xét chữ Latin và số: chữ Nhật đứng sát số vẫn là ranh giới ("コーヒー350円").
    /// Chuỗi đã gấp nên chữ Latin luôn là chữ thường không dấu.
    static let wordStart = #"(?<![a-z0-9_])"#
    static let wordEnd = #"(?![a-z0-9_])"#

    /// Đơn vị sau số. "man" (vạn yên) và "sen" (nghìn yên) là từ lóng của người Việt ở Nhật,
    /// chỉ bật khi chọn thị trường Nhật để không nhầm với "mận", "sen" trong câu tiếng Việt.
    static let vietnamUnits = "trieu|nghin|ngan|dong|vnd|yen|tr|cu|k|d|円"
    static let japanUnits = "trieu|nghin|ngan|dong|vnd|yen|man|sen|tr|cu|k|d|円"

    static let multipliers: [String: Decimal] = [
        "k": 1_000, "nghin": 1_000, "ngan": 1_000,
        "tr": 1_000_000, "trieu": 1_000_000, "cu": 1_000_000,
        "d": 1, "dong": 1, "vnd": 1,
        "yen": 1, "円": 1, "man": 10_000, "sen": 1_000
    ]

    /// Đơn vị chỉ thuộc về một loại tiền. "k", "nghìn", "ngàn" không có ở đây: chúng nhân 1.000
    /// với tiền mặc định của thị trường ("35k" ở Nhật là 35.000 yên).
    static let unitCurrency: [String: Currency] = [
        "tr": .vnd, "trieu": .vnd, "cu": .vnd, "d": .vnd, "dong": .vnd, "vnd": .vnd,
        "yen": .jpy, "円": .jpy, "man": .jpy, "sen": .jpy
    ]

    static func amountRegex(units: String) -> NSRegularExpression {
        try! NSRegularExpression(
            pattern: #"(?<![a-z0-9_/])([+-]?)(¥\s?)?(\d+(?:[.,]\d+)*)\s?(?:("# + units + #")(\d{1,3})?)?(?![a-z0-9_/])"#
        )
    }

    static let amountRegexVietnam = QuickEntryParser.amountRegex(units: QuickEntryParser.vietnamUnits)
    static let amountRegexJapan = QuickEntryParser.amountRegex(units: QuickEntryParser.japanUnits)

    /// Số kiểu Nhật: "1万2千円", "1万2000", "1.5万", "3千円", "千円". Luôn là yên.
    /// Chữ 千/百 đứng một mình chỉ là số tiền khi ngay sau là 円, để "千葉", "百貨店" không thành 1.000, 100.
    static let kanjiAmountRegex = try! NSRegularExpression(
        pattern: #"(?<![a-z0-9_/.,])([+-]?)(¥\s?)?(?:(\d+(?:[.,]\d+)*[万千百](?:\d+[万千百]?|[千百])*)|([千百])(?=\s?円))\s?(円|yen)?(?![a-z0-9_/])"#
    )

    /// Tên có số không phải số tiền: "100均 330" là 330 yên, không phải 100.
    static let numericNameRegex = try! NSRegularExpression(
        pattern: #"(?:100|百)(?:円ショップ|均)|100[ -]?yen shop"#
    )

    func findAmounts(in text: String) -> [AmountCandidate] {
        var found: [AmountCandidate] = []
        var kanjiRanges: [Range<Int>] = []
        let ns = NSRange(text.startIndex..., in: text)
        for m in Self.kanjiAmountRegex.matches(in: text, range: ns) {
            guard let range = Self.characterRange(m.range, in: text) else { continue }
            let value: Decimal?
            if let core = Self.group(m, 3, in: text) {
                value = Self.parseKanjiNumber(core)
            } else {
                value = Self.group(m, 4, in: text) == "千" ? Decimal(1_000) : Decimal(100)
            }
            guard let value, value > 0 else { continue }
            kanjiRanges.append(range)
            found.append(AmountCandidate(value: Self.int64(value), currency: .jpy, hasUnit: true,
                                         isPlus: Self.group(m, 1, in: text) == "+", range: range))
        }

        // Che số kiểu Nhật đã đọc để regex số thường không bắt nhầm "1" trong "1万".
        let rest = Self.mask(Array(text), ranges: kanjiRanges)
        let regex = options.market == .japan ? Self.amountRegexJapan : Self.amountRegexVietnam
        for m in regex.matches(in: rest, range: NSRange(rest.startIndex..., in: rest)) {
            guard let numberText = Self.group(m, 3, in: rest),
                  var value = Self.parseNumber(numberText),
                  let range = Self.characterRange(m.range, in: rest) else { continue }
            let hasYenSign = Self.group(m, 2, in: rest) != nil
            let unit = Self.group(m, 4, in: rest)
            var currency = hasYenSign ? Currency.jpy : options.market.currency
            if let unit, let multiplier = Self.multipliers[unit] {
                if let suffix = Self.group(m, 5, in: rest), let fraction = Decimal(string: "0." + suffix) {
                    value += fraction
                }
                value *= multiplier
                if !hasYenSign, let unitCurrency = Self.unitCurrency[unit] { currency = unitCurrency }
            } else if !hasYenSign && currency == .vnd && options.smallNumbersAreThousands && value < 1000 {
                value *= 1000
            }
            guard value > 0 else { continue }
            found.append(AmountCandidate(value: Self.int64(value), currency: currency,
                                         hasUnit: unit != nil || hasYenSign,
                                         isPlus: Self.group(m, 1, in: rest) == "+", range: range))
        }
        return found.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// "35.000" → 35000 (phân cách nghìn) · "1.5" / "1,5" → 1.5 (thập phân)
    static func parseNumber(_ s: String) -> Decimal? {
        let parts = s.split(whereSeparator: { $0 == "." || $0 == "," }).map(String.init)
        guard let last = parts.last else { return nil }
        if parts.count == 1 { return Decimal(string: s) }
        if parts.dropFirst().allSatisfy({ $0.count == 3 }) { return Decimal(string: parts.joined()) }
        return Decimal(string: parts.dropLast().joined() + "." + last)
    }

    /// "1万2千" → 12000 · "1万2000" → 12000 · "1万500" → 10500 · "1.5万" → 15000 · "2千5百" → 2500.
    /// Một chữ số đứng cuối sau 万/千 là cách nói tắt: "1万2" → 12000, "2千5" → 2500.
    static func parseKanjiNumber(_ text: String) -> Decimal? {
        let units: [Character: Decimal] = ["万": 10_000, "千": 1_000, "百": 100]
        var total: Decimal = 0      // phần đã nhân 万
        var section: Decimal = 0    // phần dưới 万
        var digits = ""
        var lastUnit: Decimal?
        for ch in text {
            guard let unit = units[ch] else { digits.append(ch); continue }
            var count: Decimal?
            if !digits.isEmpty {
                guard let number = parseNumber(digits) else { return nil }
                count = number
            }
            digits = ""
            if unit == 10_000 {
                let head = section + (count ?? 0)
                guard head > 0 else { return nil }
                total += head * unit
                section = 0
            } else {
                section += (count ?? 1) * unit
            }
            lastUnit = unit
        }
        if !digits.isEmpty {
            guard let tail = parseNumber(digits) else { return nil }
            if digits.count == 1, let lastUnit, lastUnit >= 1_000 {
                section += tail * lastUnit / 10
            } else {
                section += tail
            }
        }
        return total + section
    }

    static func int64(_ value: Decimal) -> Int64 {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    // MARK: - Ngày

    /// "2026/9/30", "2026-09-30" — năm đứng trước, cách ghi của Nhật và ISO.
    static let yearFirstDateRegex = try! NSRegularExpression(
        pattern: #"(?<![0-9/-])(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?![0-9/-])"#
    )

    /// "12/9", "12/9/2026" — ngày/tháng ở Việt Nam, tháng/ngày ở Nhật (`Market.dayFirst`).
    static let explicitDateRegex = try! NSRegularExpression(
        pattern: #"(?<![a-z0-9_/])(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?(?![a-z0-9_/])"#
    )

    /// "9月30日", "2026年9月30日", "30日". Không khớp "3日間", "3日分", "2日目" (số ngày, không phải ngày).
    /// "30日" thiếu tháng còn phải qua `isStandaloneDay`, vì hay nằm trong từ ghép: "1日乗車券", "2日酔い".
    static let japaneseDateRegex = try! NSRegularExpression(
        pattern: #"(?<![0-9])(?:(\d{4})年)?(?:(\d{1,2})月)?(\d{1,2})日(?![間分目])"#
    )

    /// Thứ tự quan trọng: cụm dài/cụ thể trước ("一昨日" trước "昨日").
    static let relativeDays: [(NSRegularExpression, Int)] = {
        let latin: [(String, Int)] = [
            ("hom kia", -2), ("toi qua", -1), ("dem qua", -1), ("sang qua", -1), ("hom qua", -1),
            ("hom nay", 0), ("sang nay", 0), ("trua nay", 0), ("chieu nay", 0), ("toi nay", 0),
            ("day before yesterday", -2), ("yesterday", -1), ("last night", -1),
            ("today", 0), ("tonight", 0), ("this morning", 0)
        ]
        // Tiếng Nhật không có khoảng trắng giữa các từ nên không xét ranh giới từ.
        let japanese: [(String, Int)] = [
            ("一昨日", -2), ("おととい", -2), ("おとつい", -2),
            ("昨日", -1), ("きのう", -1), ("昨夜", -1), ("昨晩", -1), ("ゆうべ", -1),
            ("今日", 0), ("きょう", 0), ("今朝", 0), ("けさ", 0), ("今夜", 0), ("今晩", 0)
        ]
        return latin.map { (try! NSRegularExpression(pattern: QuickEntryParser.wordStart + $0.0 + QuickEntryParser.wordEnd), $0.1) }
            + japanese.map { (try! NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: $0.0)), $0.1) }
    }()

    /// "thu 2", "t2", "cn", "chu nhat" — nhưng KHÔNG khớp "thu 5 trieu" (thu tiền).
    static let weekdayRegex = try! NSRegularExpression(
        pattern: QuickEntryParser.wordStart + #"(?:thu\s?([2-7])|t([2-7])|cn|chu nhat)"# + QuickEntryParser.wordEnd
            + #"(?!\s*(?:"# + QuickEntryParser.japanUnits + #"|\d)(?![a-z0-9_]))"#
    )

    /// "月曜", "月曜日"… Lịch Gregorian: 1 = 日 (Chủ nhật), 2 = 月 (thứ Hai) … 7 = 土 (thứ Bảy).
    static let japaneseWeekdayRegex = try! NSRegularExpression(pattern: #"([日月火水木金土])曜"#)
    static let japaneseWeekdays: [String: Int] = ["日": 1, "月": 2, "火": 3, "水": 4, "木": 5, "金": 6, "土": 7]

    /// Chỉ tên đầy đủ: viết tắt "mon", "sat" trùng "món", "sát" sau khi bỏ dấu.
    static let englishWeekdayRegex = try! NSRegularExpression(
        pattern: QuickEntryParser.wordStart + #"(sunday|monday|tuesday|wednesday|thursday|friday|saturday)"# + QuickEntryParser.wordEnd
    )
    static let englishWeekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    func findDate(in text: String, today: Date) -> (date: Date, range: Range<Int>)? {
        let ns = NSRange(text.startIndex..., in: text)
        let currentYear = calendar.component(.year, from: today)

        if let m = Self.yearFirstDateRegex.firstMatch(in: text, range: ns),
           let year = Self.group(m, 1, in: text).flatMap(Int.init),
           let month = Self.group(m, 2, in: text).flatMap(Int.init),
           let day = Self.group(m, 3, in: text).flatMap(Int.init),
           let range = Self.characterRange(m.range, in: text),
           let date = makeDate(year: year, month: month, day: day) {
            return (date, range)
        }

        if let m = Self.explicitDateRegex.firstMatch(in: text, range: ns),
           let first = Self.group(m, 1, in: text).flatMap(Int.init),
           let second = Self.group(m, 2, in: text).flatMap(Int.init),
           let range = Self.characterRange(m.range, in: text) {
            let (day, month) = options.market.dayFirst ? (first, second) : (second, first)
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

        let chars = Array(text)
        for m in Self.japaneseDateRegex.matches(in: text, range: ns) {
            guard let day = Self.group(m, 3, in: text).flatMap(Int.init),
                  let range = Self.characterRange(m.range, in: text) else { continue }
            let year = Self.group(m, 1, in: text).flatMap(Int.init)
            let month = Self.group(m, 2, in: text).flatMap(Int.init)
            if year == nil, month == nil, !Self.isStandaloneDay(endingAt: range.upperBound, in: chars) { continue }
            if let date = japaneseDate(year: year, month: month, day: day, today: today) {
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

        if let hit = findWeekday(in: text, range: ns),
           let date = mostRecent(weekday: hit.weekday, onOrBefore: today) {
            return (date, hit.range)
        }
        return nil
    }

    /// Ngày kiểu Nhật thiếu năm/tháng: lấy năm/tháng hiện tại; nếu ra ngày tương lai thì lùi về năm/tháng trước.
    private func japaneseDate(year: Int?, month: Int?, day: Int, today: Date) -> Date? {
        if let year {
            guard let month else { return nil }
            return makeDate(year: year, month: month, day: day)
        }
        let current = calendar.dateComponents([.year, .month], from: today)
        guard let currentYear = current.year, let currentMonth = current.month else { return nil }
        if let month {
            if let date = makeDate(year: currentYear, month: month, day: day), date <= today { return date }
            return makeDate(year: currentYear - 1, month: month, day: day)
        }
        if let date = makeDate(year: currentYear, month: currentMonth, day: day), date <= today { return date }
        let previous = currentMonth == 1 ? (currentYear - 1, 12) : (currentYear, currentMonth - 1)
        return makeDate(year: previous.0, month: previous.1, day: day)
    }

    /// "20日" đứng một mình là ngày khi sau nó là hết câu, khoảng trắng, dấu câu, ký hiệu tiền hoặc trợ từ
    /// ("20日の", "20日に"); còn chữ khác thì là một phần của từ ghép ("1日乗車券", "2日酔い").
    static func isStandaloneDay(endingAt end: Int, in chars: [Character]) -> Bool {
        guard end < chars.count else { return true }
        let next = chars[end]
        return next.isWhitespace || next.isPunctuation || next.isCurrencySymbol || "のにはでも".contains(next)
    }

    private func findWeekday(in text: String, range ns: NSRange) -> (weekday: Int, range: Range<Int>)? {
        if let m = Self.weekdayRegex.firstMatch(in: text, range: ns),
           let range = Self.characterRange(m.range, in: text) {
            // Gregorian: 1 = Chủ nhật, 2 = thứ Hai … 7 = thứ Bảy — trùng cách gọi "thứ 2…7".
            let weekday = (Self.group(m, 1, in: text) ?? Self.group(m, 2, in: text)).flatMap(Int.init) ?? 1
            return (weekday, range)
        }
        if let m = Self.japaneseWeekdayRegex.firstMatch(in: text, range: ns),
           let name = Self.group(m, 1, in: text), let weekday = Self.japaneseWeekdays[name],
           let range = Self.characterRange(m.range, in: text) {
            // "月曜日" → bỏ luôn chữ 日 khỏi ghi chú
            let end = range.upperBound
            let chars = Array(text)
            let full = end < chars.count && chars[end] == "日" ? range.lowerBound..<(end + 1) : range
            return (weekday, full)
        }
        if let m = Self.englishWeekdayRegex.firstMatch(in: text, range: ns),
           let name = Self.group(m, 1, in: text), let index = Self.englishWeekdays.firstIndex(of: name),
           let range = Self.characterRange(m.range, in: text) {
            return (index + 1, range)
        }
        return nil
    }

    /// Ngày gần nhất (tính cả hôm nay) rơi vào `weekday`.
    private func mostRecent(weekday target: Int, onOrBefore today: Date) -> Date? {
        let current = calendar.component(.weekday, from: today)
        let back = (current - target + 7) % 7
        return calendar.date(byAdding: .day, value: -back, to: today)
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

    static func ranges(of regex: NSRegularExpression, in text: String) -> [Range<Int>] {
        regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { characterRange($0.range, in: text) }
    }

    /// "昨日のランチ" → bỏ cả trợ từ "の" sau ngày để ghi chú là "ランチ".
    /// Giữ lại nếu sau "の" là hiragana, vì có thể là đầu một từ: "昨日のり弁" → "のり弁".
    static func includingParticle(_ range: Range<Int>, in chars: [Character]) -> Range<Int> {
        let end = range.upperBound
        guard end < chars.count, chars[end] == "の" else { return range }
        if end + 1 < chars.count, let scalar = chars[end + 1].unicodeScalars.first,
           (0x3041...0x309F).contains(scalar.value) {
            return range
        }
        return range.lowerBound..<(end + 1)
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
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-+–、。・"))
    }
}
