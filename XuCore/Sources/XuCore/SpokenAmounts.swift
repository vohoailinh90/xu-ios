import Foundation

/// Số tiền đọc bằng chữ, như câu đọc chính tả bằng giọng nói viết ra (issue E9, docs/04):
/// "ba mươi lăm nghìn", "một triệu hai", "một triệu rưỡi", "hai trăm năm mươi nghìn đồng", "ba trăm yên".
///
/// Chỉ nhận khi có đơn vị (nghìn/ngàn, triệu, yên; "đồng" sau nghìn/triệu) và chữ số **có dấu**: không dấu thì "bay"
/// có thể là bay, "nam" là năm hay nam — để nguyên cho người dùng gõ số. Không có đơn vị ("ba ly", "năm nay") thì không
/// phải số tiền. "củ" không nhận vì trùng "củ khoai", "đồng" đứng một mình không nhận vì trùng "đồng hồ".
enum SpokenAmounts {
    struct Hit {
        let value: Decimal
        let currency: Currency
        let range: Range<Int>
    }

    static let digits: [String: Int] = [
        "không": 0, "một": 1, "hai": 2, "ba": 3, "bốn": 4, "năm": 5, "sáu": 6, "bảy": 7, "bẩy": 7, "tám": 8, "chín": 9
    ]
    /// Hàng đơn vị chỉ đứng sau hàng chục: "hai mươi mốt", "ba lăm" (35), "hai tư" (24).
    static let unitsAfterTens: [String: Int] = ["mốt": 1, "tư": 4, "lăm": 5]
    /// Đơn vị: hệ số và loại tiền (nil = tiền của nơi chi tiêu, như "35k"). "đồng" chỉ là đơn vị cuối sau nghìn/triệu.
    static let units: [String: (multiplier: Decimal, currency: Currency?)] = [
        "nghìn": (1_000, nil), "ngàn": (1_000, nil), "triệu": (1_000_000, .vnd), "yên": (1, .jpy), "đồng": (1, .vnd)
    ]

    /// `original`: các ký tự gốc (NFC); `masked`: bản đã gấp và che (ngày, tên có số…), cùng độ dài.
    static func find(original: [Character], masked: [Character], marketCurrency: Currency) -> [Hit] {
        // Các chữ liền nhau (chỉ cách bởi khoảng trắng) thành một cụm; vùng đã che, số, dấu câu ngắt cụm.
        var runs: [[(word: String, range: Range<Int>)]] = []
        var current: [(word: String, range: Range<Int>)] = []
        var i = 0
        while i < masked.count {
            if masked[i].isLetter {
                var j = i
                while j < masked.count, masked[j].isLetter { j += 1 }
                current.append((String(original[i..<j]).lowercased(), i..<j))
                i = j
            } else {
                // Khoảng trắng thật nối các chữ; số, dấu câu và vùng đã che (ngày…) ngắt cụm.
                let isRealSpace = masked[i].isWhitespace && original[i].isWhitespace
                if !isRealSpace, !current.isEmpty {
                    runs.append(current)
                    current = []
                }
                i += 1
            }
        }
        if !current.isEmpty { runs.append(current) }

        var hits: [Hit] = []
        for run in runs {
            let words = run.map(\.word)
            var k = 0
            while k < words.count {
                if let found = phrase(words, from: k) {
                    hits.append(Hit(value: found.value, currency: found.currency ?? marketCurrency,
                                    range: run[k].range.lowerBound..<run[found.next - 1].range.upperBound))
                    k = found.next
                } else {
                    k += 1
                }
            }
        }
        return hits
    }

    /// Một số tiền bắt đầu ở `words[start]`: các nhóm "số + đơn vị" nhỏ dần ("một triệu hai trăm nghìn"),
    /// "rưỡi" sau đơn vị, và cách nói tắt "một triệu hai" (= 1tr2, như chữ số) khi đó là chữ cuối của cụm.
    static func phrase(_ words: [String], from start: Int) -> (value: Decimal, currency: Currency?, next: Int)? {
        var total: Decimal = 0
        var j = start
        var last: Decimal?
        var currency: Currency?
        while let number = belowThousand(words, j), number.next < words.count, let unit = units[words[number.next]] {
            if let last, unit.multiplier >= last { break }
            if words[number.next] == "đồng", last == nil { break }   // "hai đồng hồ" không phải tiền
            total += Decimal(number.value) * unit.multiplier
            last = unit.multiplier
            currency = currency ?? unit.currency
            j = number.next + 1
            if j < words.count, words[j] == "rưỡi" {
                total += unit.multiplier / 2
                j += 1
                break
            }
        }
        guard let last else { return nil }
        if last == 1_000_000, let tail = belowThousand(words, j), tail.next == words.count, tail.value > 0 {
            // Phần sau "triệu" là phần thập phân của triệu: hai → 0,2 · hai lăm → 0,25 · hai trăm năm mươi → 0,250.
            var divisor: Decimal = 1
            for _ in String(tail.value) { divisor *= 10 }
            total += Decimal(tail.value) / divisor * last
            j = tail.next
        }
        // "năm mươi nghìn đồng", "ba nghìn yên": chữ chỉ loại tiền đứng cuối.
        if j < words.count, let marker = units[words[j]], marker.multiplier == 1, last > 1 {
            currency = marker.currency
            j += 1
        }
        return (total, currency, j)
    }

    /// 0…999 bắt đầu ở `words[i]`: "hai trăm năm mươi", "một trăm linh năm", "không trăm năm mươi", rồi tới `tens`.
    static func belowThousand(_ words: [String], _ i: Int) -> (value: Int, next: Int)? {
        guard i < words.count else { return nil }
        if let hundreds = digits[words[i]], i + 1 < words.count, words[i + 1] == "trăm" {
            let j = i + 2
            if j + 1 < words.count, words[j] == "linh" || words[j] == "lẻ", let unit = digits[words[j + 1]], unit > 0 {
                return (hundreds * 100 + unit, j + 2)
            }
            if let rest = tens(words, j) { return (hundreds * 100 + rest.value, rest.next) }
            return (hundreds * 100, j)
        }
        return tens(words, i)
    }

    /// 0…99: "mười", "mười lăm", "hai mươi", "hai mươi mốt", "năm chục", "ba lăm" (35), "bảy".
    static func tens(_ words: [String], _ i: Int) -> (value: Int, next: Int)? {
        guard i < words.count else { return nil }
        if words[i] == "mười" {
            if i + 1 < words.count, let unit = unitDigit(words[i + 1], afterMười: true) { return (10 + unit, i + 2) }
            return (10, i + 1)
        }
        guard let digit = digits[words[i]] else { return nil }
        if i + 1 < words.count {
            if words[i + 1] == "mươi", digit >= 2 {
                if i + 2 < words.count, let unit = unitDigit(words[i + 2], afterMười: false) {
                    return (digit * 10 + unit, i + 3)
                }
                return (digit * 10, i + 2)
            }
            if words[i + 1] == "chục", digit >= 1 { return (digit * 10, i + 2) }
            if digit >= 2, let unit = unitsAfterTens[words[i + 1]] { return (digit * 10 + unit, i + 2) }
        }
        return (digit, i + 1)
    }

    /// Hàng đơn vị sau "mười"/"mươi": một…chín, tư, lăm; "mốt" chỉ sau "mươi" ("mười một", không nói "mười mốt").
    static func unitDigit(_ word: String, afterMười: Bool) -> Int? {
        if let unit = unitsAfterTens[word] { return afterMười && word == "mốt" ? nil : unit }
        guard let digit = digits[word], digit > 0 else { return nil }
        return digit
    }
}
