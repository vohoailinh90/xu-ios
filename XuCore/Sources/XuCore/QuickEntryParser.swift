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
    /// Giờ trong câu ("7h sáng", "19h30", "7:30"), tính bằng số phút từ 0:00; `nil` nếu câu không có giờ. `date` vẫn
    /// chỉ là ngày: ngày của khoản không bao giờ đổi vì giờ.
    public var minutesOfDay: Int?

    public init(amount: Int64?, currency: Currency = .vnd, isIncome: Bool, date: Date, categoryID: String,
                note: String, hasMultipleAmounts: Bool = false, minutesOfDay: Int? = nil) {
        self.amount = amount
        self.currency = currency
        self.isIncome = isIncome
        self.date = date
        self.categoryID = categoryID
        self.note = note
        self.hasMultipleAmounts = hasMultipleAmounts
        self.minutesOfDay = minutesOfDay
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
    /// Luôn là Gregorian (giữ múi giờ): "9/12", "2026年" là ngày Gregorian dù máy đặt lịch Nhật.
    public var calendar: Calendar {
        didSet { calendar = calendar.gregorianSameTimeZone }
    }
    public var matcher: CategoryMatcher

    public init(options: Options = Options(),
                calendar: Calendar = .current,
                matcher: CategoryMatcher = CategoryMatcher()) {
        self.options = options
        self.calendar = calendar.gregorianSameTimeZone
        self.matcher = matcher
    }

    public func parse(_ text: String, now: Date = Date()) -> QuickEntryResult {
        let analysis = analyze(text, now: now)
        var removed = (analysis.dateRange.map { [$0] } ?? []) + (analysis.time.map { [$0.range] } ?? [])
        let explicit = analysis.explicit

        // Ưu tiên số có đơn vị: nhiều số có đơn vị thì lấy số đầu tiên; chỉ có số trần thì lấy số lớn nhất.
        var amount: Int64?
        var currency = options.market.currency
        var signedIncome = false
        if let pick = Self.chosenAmount(analysis.candidates) {
            amount = pick.value
            currency = pick.currency
            signedIncome = pick.isPlus
            removed.append(pick.range)
        }

        // Ghi chú (giữ dấu từ chuỗi gốc)
        let note = Self.buildNote(analysis.original, removing: removed)

        // Danh mục & thu/chi
        let (isIncome, categoryID) = Self.classify(matcher.match(note: note), signedIncome: signedIncome)

        return QuickEntryResult(amount: amount, currency: currency, isIncome: isIncome, date: analysis.date,
                                categoryID: categoryID, note: note,
                                hasMultipleAmounts: explicit.count > 1, minutesOfDay: analysis.time?.minutes)
    }

    /// Bước 1–2, dùng chung cho `parse` và `split`.
    struct Analysis {
        /// Các ký tự gốc (NFC) và bản đã gấp, cùng độ dài.
        let original: [Character]
        let folded: [Character]
        let date: Date
        /// Vùng ngày (kèm thứ trong ngoặc, trợ từ) để bỏ khỏi ghi chú.
        let dateRange: Range<Int>?
        /// Giờ trong câu ("7h sáng"); `nil` nếu không có.
        let time: TimeHit?
        /// Mọi số tìm thấy, theo thứ tự trong câu.
        let candidates: [AmountCandidate]
        /// Số có đơn vị tường minh (k, tr, đ, 円…).
        var explicit: [AmountCandidate] { candidates.filter(\.hasUnit) }
    }

    func analyze(_ text: String, now: Date) -> Analysis {
        let (original, foldedChars) = TextFolding.foldAligned(text)
        let folded = String(foldedChars)

        // 1. Ngày
        let today = calendar.startOfDay(for: now)
        var date = today
        var dateRange: Range<Int>?
        if let hit = findDate(in: folded, original: original, today: today) {
            date = hit.date
            dateRange = Self.extendDateRange(hit.range, in: foldedChars)
        }

        // 2. Giờ ("cà phê 7h sáng 35k", "lúc 19h30")
        var time = findTime(in: folded, original: original)

        // 3. Số tiền, trên chuỗi đã che vùng ngày và tên cửa hàng có số như "100均".
        let dateRanges = dateRange.map { [$0] } ?? []
        // Không bao giờ là tiền: tên có số ("100均") và mọi token ngày hoá đơn kiểu "R8.9.20" — kể cả token không hợp lệ, ở tương lai hay
        // đứng sau token đã được dùng làm ngày ("R8.13.20 R8.9.20 ガム 5"): phần giữa các dấu chấm không được đọc thành số thập phân.
        let numericNames = Self.ranges(of: Self.numericNameRegex, in: folded)
            + Self.ranges(of: Self.reiwaShortDateRegex, in: folded)
        var candidates = findAmounts(in: Self.mask(foldedChars, ranges: dateRanges + numericNames), original: original)
        if let hit = time {
            // Giờ không bao giờ lấy mất tiền, theo đúng hai cách:
            // - số có đơn vị tiền (đ, k, nghìn, triệu…) chồng lên cụm giờ là tiền, không phải phút ("lúc 7 giờ 30.000đ"): bỏ giờ;
            // - che giờ đi mà không còn số nào, trong khi chưa che thì có: số duy nhất đó là tiền ("cà phê lúc 7:30"): bỏ giờ.
            // Còn có số tiền khác thì giờ là giờ, và số tiền xác định SAU khi loại cụm giờ — không so với số lớn nhất của chuỗi chưa
            // che giờ: "lúc 7:30 trà đá 5" là 5.000đ lúc 07:30, không phải 30.000đ.
            let stolen = candidates.contains { $0.hasUnit && $0.range.overlaps(hit.range) }
            let masked = stolen ? [] : findAmounts(in: Self.mask(foldedChars, ranges: dateRanges + [hit.range] + numericNames),
                                                   original: original)
            if stolen || (masked.isEmpty && !candidates.isEmpty) {
                time = nil
            } else {
                candidates = masked
            }
        }
        return Analysis(original: original, folded: foldedChars, date: date, dateRange: dateRange, time: time,
                        candidates: candidates)
    }

    /// Thu/chi và danh mục: dấu "+" hoặc danh mục thu nhập là khoản thu. Có "+" mà danh mục đoán được là khoản chi
    /// → "Thu nhập khác".
    static func classify(_ matched: CategoryDefinition?, signedIncome: Bool) -> (isIncome: Bool, categoryID: String) {
        if signedIncome || matched?.kind == .income {
            return (true, (matched?.kind == .income ? matched?.id : nil) ?? CategoryCatalog.otherIncomeID)
        }
        return (false, matched?.id ?? CategoryCatalog.otherExpenseID)
    }

    // MARK: - Số tiền

    struct AmountCandidate {
        let value: Int64
        let currency: Currency
        let hasUnit: Bool
        let isPlus: Bool
        let range: Range<Int>
    }

    /// Số tiền `parse` sẽ chọn: số có đơn vị đầu tiên; không có thì số trần lớn nhất.
    static func chosenAmount(_ candidates: [AmountCandidate]) -> AmountCandidate? {
        candidates.first(where: \.hasUnit) ?? candidates.max(by: { $0.value < $1.value })
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

    /// Số kiểu Nhật: "1万2千円", "1万2000", "1.5万", "3千円", "千円", "千五百円", "1万五千円". Luôn là yên.
    /// Số viết toàn chữ Hán chỉ là số tiền khi ngay sau là 円, để "千葉", "百貨店", "八百屋" không thành số tiền.
    /// Số trộn chữ số với chữ Hán ("1万五千円", "三万5千円") cũng vậy: phải có cả chữ số thường lẫn chữ số Hán (〇–九, 十) và đứng ngay
    /// trước 円; viết toàn chữ số thường ("1万5千") không cần 円, như trước. Nhóm: 1 dấu, 2 ¥, 3 số trộn, 4 số thường + 万千百,
    /// 5 toàn chữ Hán, 6 đơn vị.
    static let kanjiAmountRegex = try! NSRegularExpression(
        pattern: #"(?<![a-z0-9_/.,])([+-]?)(¥\s?)?(?:"#
            + #"(?=[0-9.,〇零一二三四五六七八九十百千万]*[〇零一二三四五六七八九十])(?=[0-9.,〇零一二三四五六七八九十百千万]*\d)"#
            + #"((?:\d+(?:[.,]\d+)*|[〇零一二三四五六七八九十百千万])+)(?=\s?円)"#
            + #"|(\d+(?:[.,]\d+)*[万千百](?:\d+[万千百]?|[千百])*)"#
            + #"|([〇零一二三四五六七八九十百千万]+)(?=\s?円))"#
            + #"\s?(円|yen)?(?![a-z0-9_/])"#
    )

    /// Tên có số không phải số tiền: "100均 330" là 330 yên, không phải 100.
    static let numericNameRegex = try! NSRegularExpression(
        pattern: #"(?:100|百)(?:円ショップ|均)|100[ -]?yen shop"#
    )

    /// `original`: ký tự gốc cùng độ dài với `text`, để đọc số bằng chữ có dấu ("ba mươi lăm nghìn"). Bỏ trống thì không đọc.
    func findAmounts(in text: String, original: [Character]? = nil) -> [AmountCandidate] {
        var found: [AmountCandidate] = []
        var kanjiRanges: [Range<Int>] = []
        let ns = NSRange(text.startIndex..., in: text)
        for m in Self.kanjiAmountRegex.matches(in: text, range: ns) {
            guard let range = Self.characterRange(m.range, in: text) else { continue }
            let value: Decimal?
            if let mixed = Self.group(m, 3, in: text) {
                value = Self.parseMixedKanjiNumber(mixed)
            } else if let core = Self.group(m, 4, in: text) {
                value = Self.parseKanjiNumber(core)
            } else {
                value = Self.group(m, 5, in: text).flatMap(Self.parseKanjiDigits)
            }
            // Cụm đã nhận là số kiểu Nhật nhưng không hợp lệ ("1五千円": chữ số thường dính chữ số Hán) thì cũng che đi: không đoán, và
            // regex số thường không được đọc lại "1" trong đó thành 1 yên rồi để "五千円" ở lại ghi chú.
            kanjiRanges.append(range)
            guard let value, value > 0 else { continue }
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

        // Số bằng chữ (đọc chính tả): chỉ chữ cái nên không chồng lên các số ở trên; luôn có đơn vị. Chỉ đọc khi câu chưa
        // có số tiền gõ bằng chữ số kèm đơn vị: câu gõ tay giữ nguyên kết quả cũ, và chữ như "một triệu phú",
        // "ba nghìn bước" trong ghi chú không thành số tiền thứ hai.
        let chars = Array(text)
        if let original, original.count == chars.count, !found.contains(where: \.hasUnit) {
            for hit in SpokenAmounts.find(original: original, masked: chars, marketCurrency: options.market.currency)
            where hit.value > 0 {
                found.append(AmountCandidate(value: Self.int64(hit.value), currency: hit.currency, hasUnit: true,
                                             isPlus: hit.isPlus, range: hit.range))
            }
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

    /// Số viết toàn chữ Hán: "千五百" → 1500 · "一万二千" → 12000 · "三十" → 30 · "二〇〇" → 200 · "百" → 100.
    static func parseKanjiDigits(_ text: String) -> Decimal? {
        let digits: [Character: Int] = ["〇": 0, "零": 0, "一": 1, "二": 2, "三": 3, "四": 4,
                                        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
        let units: [Character: Int] = ["十": 10, "百": 100, "千": 1_000]
        var total = 0, section = 0, current = 0
        for ch in text {
            if let digit = digits[ch] {
                current = current * 10 + digit
            } else if let unit = units[ch] {
                section += (current == 0 ? 1 : current) * unit
                current = 0
            } else if ch == "万" {
                let head = section + current
                guard head > 0 else { return nil }
                total += head * 10_000
                section = 0
                current = 0
            } else {
                return nil
            }
        }
        let value = total + section + current
        return value > 0 ? Decimal(value) : nil
    }

    /// Số trộn chữ số thường với chữ Hán: "1万五千" → 15000 · "三万5千" → 35000 · "2千五百" → 2500 · "1.5万三千" → 18000.
    /// Chữ số Hán liền nhau tạo thành số ("二〇〇"); chữ số thường và chữ số Hán không dính liền nhau ("1五" là không hợp lệ).
    /// Không có cách nói tắt như "1万2" (ở đây luôn đứng trước 円): chữ số lẻ ở cuối cộng thẳng.
    static func parseMixedKanjiNumber(_ text: String) -> Decimal? {
        let kanjiDigits: [Character: Int] = ["〇": 0, "零": 0, "一": 1, "二": 2, "三": 3, "四": 4,
                                             "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
        let units: [Character: Decimal] = ["十": 10, "百": 100, "千": 1_000, "万": 10_000]
        var total: Decimal = 0      // phần đã nhân 万
        var section: Decimal = 0    // phần dưới 万
        var pending: Decimal?       // số đang chờ đơn vị
        var pendingIsKanji = false
        var ascii = ""

        func takeAscii() -> Bool {
            guard !ascii.isEmpty else { return true }
            defer { ascii = "" }
            guard pending == nil, let number = parseNumber(ascii) else { return false }
            pending = number
            pendingIsKanji = false
            return true
        }

        for ch in text {
            if ch.isASCII, ch.isNumber || ch == "." || ch == "," {
                ascii.append(ch)
                continue
            }
            guard takeAscii() else { return nil }
            if let digit = kanjiDigits[ch] {
                if let current = pending {
                    guard pendingIsKanji else { return nil }
                    pending = current * 10 + Decimal(digit)
                } else {
                    pending = Decimal(digit)
                    pendingIsKanji = true
                }
            } else if let unit = units[ch] {
                let count = pending
                pending = nil
                if unit == 10_000 {
                    let head = section + (count ?? 0)
                    guard head > 0 else { return nil }
                    total += head * unit
                    section = 0
                } else {
                    section += (count ?? 1) * unit
                }
            } else {
                return nil
            }
        }
        guard takeAscii() else { return nil }
        let value = total + section + (pending ?? 0)
        return value > 0 ? value : nil
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

    /// "R8.9.30", "R08.09.30", "R8/9/30" — năm 令和 viết tắt kiểu hoá đơn (R = 令和; 令和元年 = 2019). Đã gấp nên "R" là "r".
    static let reiwaShortDateRegex = try! NSRegularExpression(
        pattern: #"(?<![a-z0-9_])r(\d{1,2})[./-](\d{1,2})[./-](\d{1,2})(?![0-9a-z_/-])(?!\.\d)"#
    )

    /// "12/9", "12/9/2026" — ngày/tháng ở Việt Nam, tháng/ngày ở Nhật (`Market.dayFirst`).
    static let explicitDateRegex = try! NSRegularExpression(
        pattern: #"(?<![a-z0-9_/])(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?(?![a-z0-9_/])"#
    )

    /// "9月30日", "2026年9月30日", "令和8年9月30日", "30日". Không khớp "3日間", "3日分", "2日目" (số ngày, không phải ngày).
    /// "30日" thiếu tháng còn phải qua `isStandaloneDay`, vì hay nằm trong từ ghép: "1日乗車券", "2日酔い".
    static let japaneseDateRegex = try! NSRegularExpression(
        pattern: #"(?<![0-9])(?:(?:(\d{4})|令和(\d{1,2}|元))年)?(?:(\d{1,2})月)?(\d{1,2})日(?![間分目])"#
    )

    /// Cụm ngày tương đối. `spelling` là cách viết đủ dấu của từng chữ (cụm tiếng Việt), `nil` cho tiếng Anh/Nhật.
    struct RelativeDay {
        let regex: NSRegularExpression
        let offset: Int
        let spelling: [String]?
    }

    /// Thứ tự quan trọng: cụm dài/cụ thể trước ("一昨日" trước "昨日").
    static let relativeDays: [RelativeDay] = {
        let latin: [(String, Int, [String]?)] = [
            ("hom kia", -2, ["hôm", "kia"]), ("toi qua", -1, ["tối", "qua"]), ("dem qua", -1, ["đêm", "qua"]),
            ("sang qua", -1, ["sáng", "qua"]), ("hom qua", -1, ["hôm", "qua"]),
            ("hom nay", 0, ["hôm", "nay"]), ("sang nay", 0, ["sáng", "nay"]), ("trua nay", 0, ["trưa", "nay"]),
            ("chieu nay", 0, ["chiều", "nay"]), ("toi nay", 0, ["tối", "nay"]),
            ("day before yesterday", -2, nil), ("yesterday", -1, nil), ("last night", -1, nil),
            ("today", 0, nil), ("tonight", 0, nil), ("this morning", 0, nil)
        ]
        // Tiếng Nhật không có khoảng trắng giữa các từ nên không xét ranh giới từ.
        let japanese: [(String, Int)] = [
            ("一昨日", -2), ("おととい", -2), ("おとつい", -2),
            ("昨日", -1), ("きのう", -1), ("昨夜", -1), ("昨晩", -1), ("ゆうべ", -1),
            ("今日", 0), ("きょう", 0), ("今朝", 0), ("けさ", 0), ("今夜", 0), ("今晩", 0)
        ]
        // Khoảng trắng giữa hai chữ là một hay nhiều (dấu cách, tab, NBSP…), cùng quy tắc với cụm giờ ("tối  qua  7h"): cụm ngày và
        // cụm giờ phải hiểu cùng một câu, không thì giờ ăn mất chữ của ngày mà ngày vẫn là hôm nay.
        var days: [RelativeDay] = []
        for (phrase, offset, spelling) in latin {
            let pattern = QuickEntryParser.wordStart + phrase.replacingOccurrences(of: " ", with: #"\s+"#) + QuickEntryParser.wordEnd
            days.append(RelativeDay(regex: try! NSRegularExpression(pattern: pattern), offset: offset, spelling: spelling))
        }
        for (phrase, offset) in japanese {
            let pattern = NSRegularExpression.escapedPattern(for: phrase)
            days.append(RelativeDay(regex: try! NSRegularExpression(pattern: pattern), offset: offset, spelling: nil))
        }
        return days
    }()

    /// Chuỗi đã bỏ dấu khớp cả những câu không phải cụm ngày: "tôi qua quán" (đại từ), "đem qua nhà" (mang sang) trông như
    /// "tối qua", "đêm qua" sau khi bỏ dấu. Nên mỗi chữ của cụm đối chiếu với chữ gốc: hoặc bỏ dấu hoàn toàn ("toi qua": người
    /// dùng gõ không dấu), hoặc đúng chữ đủ dấu ("tối qua"); dấu khác ("tôi", "đem") là một từ khác. Cùng nguyên tắc với chữ buổi
    /// trong cụm giờ.
    static func spellsDatePhrase(_ range: Range<Int>, in original: [Character], spelling: [String]?) -> Bool {
        guard let spelling else { return true }
        guard let words = originalWords(range, in: original), words.count == spelling.count else { return false }
        return zip(words, spelling).allSatisfy { pair in pair.0 == pair.1 || pair.0 == TextFolding.fold(pair.1) }
    }

    /// "thu 2", "t2", "cn", "chu nhat" — nhưng KHÔNG khớp "thu 5 trieu" (thu tiền).
    static let weekdayRegex = try! NSRegularExpression(
        pattern: QuickEntryParser.wordStart + #"(?:thu\s?([2-7])|t([2-7])|cn|chu nhat)"# + QuickEntryParser.wordEnd
            + #"(?!\s*(?:"# + QuickEntryParser.japanUnits + #"|\d)(?![a-z0-9_]))"#
    )

    /// "月曜", "月曜日", "(月)"… Lịch Gregorian: 1 = 日 (Chủ nhật), 2 = 月 (thứ Hai) … 7 = 土 (thứ Bảy).
    /// Ngoặc toàn khổ "（月）" đã được gấp về "(月)".
    static let japaneseWeekdayRegex = try! NSRegularExpression(
        pattern: #"\(([日月火水木金土])(?:曜日?)?\)|([日月火水木金土])曜日?"#
    )
    static let japaneseWeekdays: [String: Int] = ["日": 1, "月": 2, "火": 3, "水": 4, "木": 5, "金": 6, "土": 7]

    /// Chỉ tên đầy đủ: viết tắt "mon", "sat" trùng "món", "sát" sau khi bỏ dấu.
    static let englishWeekdayRegex = try! NSRegularExpression(
        pattern: QuickEntryParser.wordStart + #"(sunday|monday|tuesday|wednesday|thursday|friday|saturday)"# + QuickEntryParser.wordEnd
    )
    static let englishWeekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    func findDate(in text: String, original: [Character], today: Date) -> (date: Date, range: Range<Int>)? {
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

        // Hoá đơn Nhật in ngày kiểu "R8.9.20". Biên lai không có ngày tương lai, nên ngày sau hôm nay không phải ngày (tránh đọc nhầm một
        // mã kiểu phiên bản "R2.3.15"); thời Reiwa bắt đầu từ 01/05/2019 nên "R1.1.1" cũng vậy. Token không hợp lệ thì chữ ở lại trong
        // ghi chú và xét tiếp token sau: "R8.13.20 R8.9.20" lấy ngày thật.
        let reiwaStart = makeDate(year: 2019, month: 5, day: 1)
        for m in Self.reiwaShortDateRegex.matches(in: text, range: ns) {
            guard let era = Self.group(m, 1, in: text).flatMap(Int.init), era >= 1,
                  let month = Self.group(m, 2, in: text).flatMap(Int.init),
                  let day = Self.group(m, 3, in: text).flatMap(Int.init),
                  let range = Self.characterRange(m.range, in: text),
                  let date = makeDate(year: 2018 + era, month: month, day: day),
                  date <= today, let reiwaStart, date >= reiwaStart else { continue }
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
            guard let day = Self.group(m, 4, in: text).flatMap(Int.init),
                  let range = Self.characterRange(m.range, in: text) else { continue }
            let year = Self.group(m, 1, in: text).flatMap(Int.init) ?? Self.reiwaYear(Self.group(m, 2, in: text))
            let month = Self.group(m, 3, in: text).flatMap(Int.init)
            if year == nil, month == nil, !Self.isStandaloneDay(range, in: chars) { continue }
            if let date = japaneseDate(year: year, month: month, day: day, today: today) {
                return (date, range)
            }
        }

        for day in Self.relativeDays {
            for m in day.regex.matches(in: text, range: ns) {
                guard let range = Self.characterRange(m.range, in: text),
                      Self.spellsDatePhrase(range, in: original, spelling: day.spelling),
                      let date = calendar.date(byAdding: .day, value: day.offset, to: today) else { continue }
                return (date, range)
            }
        }

        if let hit = findWeekday(in: text, range: ns),
           let date = mostRecent(weekday: hit.weekday, onOrBefore: today) {
            return (date, hit.range)
        }
        return nil
    }

    /// "令和8年" → 2026 (令和元年 = 2019).
    static func reiwaYear(_ text: String?) -> Int? {
        guard let text else { return nil }
        if text == "元" { return 2019 }
        return Int(text).map { 2018 + $0 }
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

    /// Chữ đi sau "N日" cho biết chắc đó là ngày lịch: buổi trong ngày, "から", "ごろ/頃", "の"
    /// ("20日朝", "20日午後", "20日から", "20日の"). Cố ý không có trợ từ hay dùng cho thời lượng hoặc đơn giá:
    /// "最長3日まで" (tối đa 3 ngày), "3日で5000円" (3 ngày giá 5000), "1日につき500円" (mỗi ngày), "3日は無料".
    static let dayFollowers = ["午前", "午後", "から", "ごろ", "朝", "昼", "夕", "夜", "晩", "頃", "の"]

    /// "20日" thiếu tháng chỉ là ngày khi đứng riêng cả hai bên:
    /// - bên trái là đầu câu, khoảng trắng hoặc dấu câu — "3泊4日" (3 đêm 4 ngày), "最長3日", "レンタカー3日" là thời lượng;
    /// - bên phải là hết câu, khoảng trắng, dấu câu, ký hiệu tiền hoặc `dayFollowers` — "1日乗車券", "2日酔い" là từ ghép.
    /// Thà bỏ sót ngày (thấy ngay trên thẻ xem trước) còn hơn ghi nhầm khoản chi sang ngày khác.
    static func isStandaloneDay(_ range: Range<Int>, in chars: [Character]) -> Bool {
        if range.lowerBound > 0 {
            let previous = chars[range.lowerBound - 1]
            guard previous.isWhitespace || previous.isPunctuation else { return false }
            // "3泊 4日", "3泊・4日": số ngày đi sau số đêm là thời lượng, dù có cách bằng khoảng trắng.
            var k = range.lowerBound - 1
            while k >= 0, chars[k].isWhitespace || chars[k].isPunctuation { k -= 1 }
            if k >= 0, chars[k] == "泊" { return false }
        }
        let end = range.upperBound
        guard end < chars.count else { return true }
        let next = chars[end]
        if next.isWhitespace || next.isPunctuation || next.isCurrencySymbol { return true }
        let rest = String(chars[end...].prefix(2))
        return dayFollowers.contains { rest.hasPrefix($0) }
    }

    private func findWeekday(in text: String, range ns: NSRange) -> (weekday: Int, range: Range<Int>)? {
        if let m = Self.weekdayRegex.firstMatch(in: text, range: ns),
           let range = Self.characterRange(m.range, in: text) {
            // Gregorian: 1 = Chủ nhật, 2 = thứ Hai … 7 = thứ Bảy — trùng cách gọi "thứ 2…7".
            let weekday = (Self.group(m, 1, in: text) ?? Self.group(m, 2, in: text)).flatMap(Int.init) ?? 1
            return (weekday, range)
        }
        if let m = Self.japaneseWeekdayRegex.firstMatch(in: text, range: ns),
           let name = Self.group(m, 1, in: text) ?? Self.group(m, 2, in: text),
           let weekday = Self.japaneseWeekdays[name],
           let range = Self.characterRange(m.range, in: text) {
            return (weekday, range)
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

    // MARK: - Giờ

    /// Ứng viên giờ trên chuỗi đã gấp ("giờ" → "gio"). Nhóm: 1 "lúc"/"vào lúc", 2 buổi đứng trước, 3 "nay"/"qua" theo sau
    /// buổi đó, 4 giờ, 5 phút ("7h30"), 6 phút ("7 giờ 30"), 7 phút ("7:30"), 8 buổi đứng sau.
    /// Giờ và phút dính liền ("7h30"), trừ "giờ": "7 giờ 30". "7h 35k" là 7h và 30k, không phải 7h30.
    /// Regex chỉ *tìm* ứng viên; có nhận là giờ hay không do `findTime` quyết.
    static let timeRegex = try! NSRegularExpression(
        pattern: #"(?<![a-z0-9_/:.,])(?:((?:vao\s+)?luc)\s+)?(?:(sang|trua|chieu|toi|dem)(?:\s+(nay|qua))?\s+)?(\d{1,2})"#
            + #"(?:h(\d{2}"# + moneyUnitAhead + #")?|\s*gio(?:\s*(\d{2})(?![a-z0-9_])"# + moneyUnitAhead + #")?|:(\d{2}"#
            + moneyUnitAhead + #"))"#
            + #"(?:\s*(sang|trua|chieu|toi|dem)(?![a-z0-9_]))?(?![a-z0-9_/])"#
    )

    /// Sau hai chữ số phút không được tiếp tục cú pháp số tiền: không có dấu nhóm/thập phân ("30.000đ", "30,5 triệu") và không có đơn
    /// vị tiền sau bất kỳ khoảng trắng nào ("7 giờ 30 nghìn", "30  triệu", "30 yên"): đó là số tiền, không phải phút. Phút bị từ
    /// chối thì "lúc 7 giờ 30 nghìn" thành 7 giờ và 30 nghìn, như người viết định nói. Chốt chặn cuối là bất biến ở `analyze`.
    private static let moneyUnitAhead = #"(?![.,]\d)(?!\s*(?:"# + japanUnits + #")(?![a-z0-9_]))"#

    struct TimeHit {
        /// Số phút từ 0:00.
        let minutes: Int
        /// Cả cụm giờ, bỏ khỏi ghi chú: "lúc"/"vào lúc" và buổi đứng đầu câu cũng là một phần của cụm.
        let range: Range<Int>
    }

    /// Giờ đầu tiên trong câu. Chỉ nhận khi người dùng **nói rõ đó là một thời điểm**, bằng đúng một trong ba cách:
    /// - buổi đứng **ngay sau** giờ, mà sau buổi là hết câu, dấu câu hoặc con số ("cà phê 7h sáng 35k", "grab 7h tối");
    /// - buổi đứng **đầu câu** hoặc kèm "nay"/"qua" ("sáng 7h cà phê 35k", "chiều nay 3h", "tối qua 7h");
    /// - "lúc"/"vào lúc" ("lúc 19h30", "vào lúc 7:30", "lúc 7h tối qua").
    /// Dạng dấu hai chấm ("7:30") chỉ nhận khi có "lúc". Mọi dạng khác bị bỏ qua, kể cả buổi nằm giữa câu: "ăn tối 7h",
    /// "đèn sáng 20h", "tỷ lệ 1:20 sáng nay" — buổi ở đó là chữ của ghi chú, còn con số có thể là thời lượng ("thuê phòng
    /// 2h30"), tỷ lệ, hay số khác. Buổi theo sau mà lại mở đầu "nay"/"qua" thì thuộc về cụm ngày, không bổ nghĩa cho con số
    /// ("thuê phòng 2h30 sáng nay": thời lượng rồi ngày; "7h tối qua" cũng vậy, về chữ không phân biệt được) — trừ khi có "lúc".
    /// Chữ buổi và "lúc" phải viết **đủ dấu**: bản đã gấp dấu không phân biệt được "tôi" (đại từ) với "tối", "đem" với "đêm"
    /// ("lúc 7h tôi ăn phở" là 7 giờ, không phải 19 giờ), nên đối chiếu với chuỗi gốc — như `SpokenAmounts` chỉ nhận chữ số có dấu.
    /// Danh sách loại trừ thì không bao giờ đủ; nhầm giờ làm ghi chú mất chữ và `occurredAt` sai, còn bỏ sót giờ thì khoản
    /// vẫn đúng ngày như trước.
    func findTime(in text: String, original: [Character]) -> TimeHit? {
        let ns = NSRange(text.startIndex..., in: text)
        let chars = Array(text)
        for m in Self.timeRegex.matches(in: text, range: ns) {
            guard let hour = Self.group(m, 4, in: text).flatMap(Int.init),
                  let hourRange = Self.characterRange(m.range(at: 4), in: text),
                  let whole = Self.characterRange(m.range, in: text) else { continue }
            let minuteText = Self.group(m, 5, in: text) ?? Self.group(m, 6, in: text) ?? Self.group(m, 7, in: text)
            let minute = minuteText.flatMap(Int.init) ?? 0
            let isClockStyle = Self.group(m, 7, in: text) != nil
            let lead = Self.spelled(Self.characterRange(m.range(at: 1), in: text), in: original, as: Self.leadSpellings)
            // "nay"/"qua" theo sau buổi đứng trước phải đúng chữ gốc: "sáng quá 7h" (quá = too) không phải "sáng qua 7h".
            if let dateWord = Self.characterRange(m.range(at: 3), in: text),
               Self.spelled(dateWord, in: original, as: Self.dateWords) == nil { continue }
            let pre = Self.spelled(Self.characterRange(m.range(at: 2), in: text), in: original, as: Self.periodSpellings)
            // Buổi đứng trước chỉ là bằng chứng khi nó mở đầu câu, kèm "nay"/"qua", hoặc có "lúc"; còn lại là chữ của ghi chú.
            let usablePre = pre.map { range in
                lead != nil || Self.group(m, 3, in: text) != nil || chars[..<range.lowerBound].allSatisfy(\.isWhitespace)
            } ?? false
            let postRange = Self.characterRange(m.range(at: 8), in: text)
            var post: String?
            if let postRange, Self.spelled(postRange, in: original, as: Self.periodSpellings) != nil {
                // Chữ buổi đứng sau giờ chỉ nhận khi cấu trúc chứng minh nó không phải đầu một từ ghép: sau nó là hết câu, dấu
                // câu hoặc con số. Sau nó là một từ khác ("tối đa", "tối ưu", "sáng tạo", "tối ăn") thì mơ hồ: bỏ cả giờ,
                // không đoán AM/PM. Sau nó là "nay"/"qua" thì nó mở đầu cụm ngày ("2h30 sáng nay"): chỉ nhận khi có "lúc".
                switch Self.follower(of: chars, original: original, from: postRange.upperBound) {
                case .boundary:
                    post = Self.group(m, 8, in: text)
                case .dateWord:
                    guard lead != nil else { continue }
                    post = Self.group(m, 8, in: text)
                case .word:
                    continue
                }
            }
            let period = post ?? (usablePre ? Self.group(m, 2, in: text) : nil)
            guard hour <= 23, minute <= 59 else { continue }
            guard lead != nil || (period != nil && !isClockStyle) else { continue }
            guard let hour24 = Self.hour24(hour, period: period) else { continue }
            let lower = lead?.lowerBound ?? (usablePre ? pre?.lowerBound : nil) ?? hourRange.lowerBound
            var upper = whole.upperBound
            if post == nil, let postRange {   // chữ sau giờ không phải buổi của nó ("tôi", "sáng nay"): cụm giờ kết thúc trước nó
                upper = postRange.lowerBound
                while upper > hourRange.upperBound, chars[upper - 1].isWhitespace { upper -= 1 }
            }
            return TimeHit(minutes: hour24 * 60 + minute, range: lower..<upper)
        }
        return nil
    }

    /// Chữ buổi viết đủ dấu. Chuỗi đã gấp dấu coi "tôi" như "tối", "đem" như "đêm", "sang" như "sáng".
    static let periodSpellings: Set<String> = ["sáng", "trưa", "chiều", "tối", "đêm"]
    static let leadSpellings: Set<String> = ["lúc", "vào lúc"]
    static let dateWords: Set<String> = ["nay", "qua"]

    /// Các chữ gốc trong `range` (không phân biệt hoa thường, chữ Latin toàn khổ của bàn phím Nhật về nửa khổ), **giữ dấu**, cách nhau
    /// bằng đúng một dấu cách dù giữa chúng có nhiều khoảng trắng.
    static func originalWords(_ range: Range<Int>, in original: [Character]) -> [String]? {
        guard range.lowerBound >= 0, range.upperBound <= original.count else { return nil }
        return TextFolding.foldWidth(String(original[range])).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// `range` nếu chữ gốc ở đó đúng là một trong `allowed`, còn không thì `nil`.
    static func spelled(_ range: Range<Int>?, in original: [Character], as allowed: Set<String>) -> Range<Int>? {
        guard let range, let words = originalWords(range, in: original),
              allowed.contains(words.joined(separator: " ")) else { return nil }
        return range
    }

    /// Cái đứng sau một chữ buổi (bỏ qua mọi khoảng trắng).
    enum PeriodFollower {
        /// Hết câu, dấu câu, ký hiệu hoặc chữ số: chữ buổi không thể là đầu của một từ ghép.
        case boundary
        /// "nay"/"qua": chữ buổi mở đầu một cụm ngày ("sáng nay", "tối qua").
        case dateWord
        /// Một từ khác: chữ buổi có thể là đầu của từ ghép ("tối đa", "tối ưu", "sáng tạo").
        case word
    }

    static func follower(of chars: [Character], original: [Character], from index: Int) -> PeriodFollower {
        var start = index
        while start < chars.count, chars[start].isWhitespace { start += 1 }
        // Chuỗi dấu câu dính liền chữ buổi rồi tới ngay một chữ cái ("tối-đa", "sáng-tạo", "tối/đa", "tối'đa", "tối--đa") nối hai
        // chữ thành một từ ghép: dấu câu không chứng minh chữ buổi đã kết thúc, dù có một hay nhiều dấu. Có khoảng trắng quanh
        // dấu ("tối - đa", "tối, đa") thì dấu là dấu câu thật.
        if start == index {
            var symbols = start
            while symbols < chars.count, !chars[symbols].isLetter, !chars[symbols].isNumber, !chars[symbols].isWhitespace { symbols += 1 }
            if symbols > start, symbols < chars.count, chars[symbols].isLetter { return .word }
        }
        guard start < chars.count, chars[start].isLetter else { return .boundary }
        var end = start
        while end < chars.count, chars[end].isLetter || chars[end].isNumber { end += 1 }
        let word = String(chars[start..<end])
        // "quá" (quá đắt), "quà", "nảy" bỏ dấu cũng thành "qua"/"nay" nhưng không phải cụm ngày: chữ gốc cũng phải là "nay"/"qua".
        let isDateWord = (word == "nay" || word == "qua") && spelled(start..<end, in: original, as: dateWords) != nil
        return isDateWord ? .dateWord : .word
    }

    /// Giờ viết theo buổi → giờ 24h, chỉ trong khoảng người ta thật sự nói với buổi đó (giờ 12h hoặc 24h):
    /// sáng 1–11 · trưa 10–13 và 1–3 (→ 13–15) · chiều 1–7 (→ 13–19) và 13–18 · tối 5–11 (→ 17–23) và 17–23 ·
    /// đêm 9–11 (→ 21–23), 12 (→ 0), 1–5, 0 và 21–23. Ví dụ "7h tối" → 19, "19h tối" → 19, "12h đêm" → 0.
    /// Ngoài khoảng đó ("11h chiều", "1h tối", "12h sáng", "19h sáng") thì không phải giờ: không cộng 12 bừa.
    /// Không có buổi (chỉ khi có "lúc") thì giờ là số viết ra, 0–23.
    static func hour24(_ hour: Int, period: String?) -> Int? {
        guard let period else { return (0...23).contains(hour) ? hour : nil }
        switch period {
        case "sang":
            return (1...11).contains(hour) ? hour : nil
        case "trua":
            if (10...13).contains(hour) { return hour }
            return (1...3).contains(hour) ? hour + 12 : nil
        case "chieu":
            if (1...7).contains(hour) { return hour + 12 }
            return (13...18).contains(hour) ? hour : nil
        case "toi":
            if (5...11).contains(hour) { return hour + 12 }
            return (17...23).contains(hour) ? hour : nil
        case "dem":
            if hour == 12 { return 0 }
            if (9...11).contains(hour) { return hour + 12 }
            return (1...5).contains(hour) || hour == 0 || (21...23).contains(hour) ? hour : nil
        default:
            return nil
        }
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

    /// Trợ từ ngay sau ngày cũng bỏ khỏi ghi chú: "昨日のランチ" → "ランチ", "20日から 旅行" → "旅行".
    static let dateParticles = ["から", "の", "に", "は", "で"]

    /// Phần đi kèm ngày cũng bỏ khỏi ghi chú, nhưng thà để sót còn hơn cắt mất chữ của người dùng:
    /// - thứ trong ngoặc ngay sau ngày, cách in quen thuộc ở Nhật: "9/23(水)", "9/23 (水曜日)";
    /// - trợ từ một chữ: giữ nếu sau nó là hiragana, vì có thể là đầu một từ ("昨日のり弁" → "のり弁");
    /// - "から": chỉ bỏ khi đứng riêng (sau là khoảng trắng, dấu câu, hết câu), vì "昨日から揚げ" là món から揚げ.
    static func extendDateRange(_ range: Range<Int>, in chars: [Character]) -> Range<Int> {
        var end = range.upperBound
        var i = end
        if i < chars.count, chars[i] == " " { i += 1 }
        if i + 1 < chars.count, chars[i] == "(", japaneseWeekdays[String(chars[i + 1])] != nil {
            var j = i + 2
            if j < chars.count, chars[j] == "曜" {
                j += 1
                if j < chars.count, chars[j] == "日" { j += 1 }
            }
            if j < chars.count, chars[j] == ")" { end = j + 1 }
        }
        guard end < chars.count else { return range.lowerBound..<end }
        let rest = String(chars[end...].prefix(2))
        guard let particle = dateParticles.first(where: { rest.hasPrefix($0) }) else { return range.lowerBound..<end }
        let after = end + particle.count
        let next: Character? = after < chars.count ? chars[after] : nil
        if particle.count > 1 {
            if let next, !next.isWhitespace, !next.isPunctuation { return range.lowerBound..<end }
        } else if let scalar = next?.unicodeScalars.first, (0x3041...0x309F).contains(scalar.value) {
            return range.lowerBound..<end
        }
        return range.lowerBound..<after
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
        return collapsed.trimmingCharacters(in: noteEdgePunctuation)
    }

    /// Dấu câu thừa bỏ ở hai đầu ghi chú.
    static let noteEdgePunctuation = CharacterSet(charactersIn: " ,.;:-+–、。・")
}
