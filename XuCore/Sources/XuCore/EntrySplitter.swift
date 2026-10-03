import Foundation

/// Tách một câu có nhiều số tiền thành nhiều khoản (issue E8, docs/04): "ăn trưa 45k tip 5k" → "ăn trưa" 45.000
/// và "tip" 5.000. Chỉ là gợi ý cho người dùng chạm vào; Enter vẫn lưu một khoản như `parse`.
extension QuickEntryParser {
    /// Từng khoản theo thứ tự trong câu. Câu có ít hơn hai số tiền tường minh (có đơn vị: k, tr, đ, 円…) thì trả về
    /// đúng một phần tử là `parse(text)`.
    ///
    /// - Ngày tìm một lần cho cả câu và dùng chung: "hôm qua cà phê 35k bánh 20k" → cả hai khoản là hôm qua.
    /// - Mỗi số tiền tường minh là một khoản. Số trần ("2 ly") ở lại trong ghi chú như ở `parse`.
    /// - Chữ nằm giữa hai số tiền thuộc về khoản nào:
    ///   - có dấu câu ngăn (`,` `;` `、` `。` `+` `&`) thì cắt ở đó, bỏ dấu ngăn: "ăn trưa 45k với bạn, grab 20k";
    ///   - không có dấu câu thì cắt ở chữ nối: `và` `and` `と` đứng riêng, hay `と` sát ngay sau số tiền mà sau nó là
    ///     katakana/chữ Hán ("350円とパン") hoặc một từ khoá danh mục ("350円とお茶");
    ///   - không có cả hai thì theo cách gõ của cả câu: có chữ trước số tiền đầu tiên ("cà phê 35k bánh 20k") thì chữ
    ///     đi với số đứng sau nó; câu mở đầu bằng số tiền ("35k cà phê 20k bánh") thì chữ đi với số đứng trước nó.
    /// - Khoản không nhận ra danh mục thì lấy danh mục khoản chi của cả câu — cái thẻ xem trước đang hiện, nên người
    ///   dùng đã chọn tay thì truyền vào `fallbackCategoryID`: "tip" trong "ăn trưa 45k tip 5k" vẫn là ăn uống.
    ///   Khoản thu chỉ khi khoản đó có "+" hoặc từ khoá thu nhập: danh mục thu nhập không lan sang khoản khác.
    public func split(_ text: String, now: Date = Date(), fallbackCategoryID: String? = nil) -> [QuickEntryResult] {
        let whole = parse(text, now: now)
        let analysis = analyze(text, now: now)
        let amounts = analysis.explicit
        guard amounts.count > 1 else { return [whole] }

        let chars = analysis.folded
        let outsideDate = { (i: Int) in
            analysis.dateRange?.contains(i) != true && analysis.time?.range.contains(i) != true
        }
        let notesFirst = (0..<amounts[0].range.lowerBound).contains { i in
            outsideDate(i) && (chars[i].isLetter || chars[i].isNumber)
        }

        // Khoản thứ i nằm trong starts[i]..<ends[i].
        var starts = [0]
        var ends: [Int] = []
        for (left, right) in zip(amounts, amounts.dropFirst()) {
            let gap = left.range.upperBound..<right.range.lowerBound
            let cut = separator(in: gap, original: analysis.original, folded: chars, last: !notesFirst)
                ?? (notesFirst ? gap.lowerBound..<gap.lowerBound : gap.upperBound..<gap.upperBound)
            ends.append(cut.lowerBound)
            starts.append(cut.upperBound)
        }
        ends.append(chars.count)

        let sentenceCategory = fallbackCategoryID.map { CategoryCatalog.resolve(id: $0) } ?? matcher.match(note: whole.note)
        let fallback = sentenceCategory?.kind == .expense ? sentenceCategory : nil
        return amounts.indices.map { i -> QuickEntryResult in
            let amount = amounts[i]
            var removed = [0..<starts[i], ends[i]..<chars.count, amount.range]
            if let dateRange = analysis.dateRange { removed.append(dateRange) }
            if let timeRange = analysis.time?.range { removed.append(timeRange) }
            let note = Self.trimConnectors(Self.buildNote(analysis.original, removing: removed))
            let (isIncome, categoryID) = Self.classify(matcher.match(note: note) ?? fallback,
                                                       signedIncome: amount.isPlus)
            return QuickEntryResult(amount: amount.value, currency: amount.currency, isIncome: isIncome,
                                    date: analysis.date, categoryID: categoryID, note: note,
                                    minutesOfDay: analysis.time?.minutes)
        }
    }

    /// Dấu câu ngăn hai khoản (trên bản đã gấp: "，" → ",", "＋" → "+").
    static let separatorCharacters: Set<Character> = [",", ";", "、", "。", "+", "&"]
    /// Chữ nối hai khoản, chỉ khi đứng riêng. So trên chữ thường **giữ dấu**: "và" là nối, còn "va" có thể là
    /// "vá" gõ không dấu ("vá xe 30k"), nên không cắt. "với" thường là "cùng với" ("ăn trưa với bạn"), không phải nối.
    static let connectorWords: Set<String> = ["và", "and", "と", "&", "+"]

    /// Chỗ cắt trong khoảng giữa hai số tiền: dấu câu trước, không có mới tới chữ nối. Lấy chỗ đầu tiên, hoặc chỗ cuối
    /// cùng nếu `last`.
    func separator(in gap: Range<Int>, original: [Character], folded: [Character], last: Bool) -> Range<Int>? {
        var marks: [Range<Int>] = []
        var words: [Range<Int>] = []
        var wordStart: Int?
        for i in gap.lowerBound...gap.upperBound {
            if i == gap.upperBound || folded[i].isWhitespace {
                if let start = wordStart, Self.connectorWords.contains(String(original[start..<i]).lowercased()) {
                    words.append(start..<i)
                }
                wordStart = nil
                if i < gap.upperBound, folded[i].isNewline { marks.append(i..<i + 1) }
            } else if Self.separatorCharacters.contains(folded[i]) {
                marks.append(i..<i + 1)
            } else if wordStart == nil {
                wordStart = i
            }
        }
        // と sát ngay sau số tiền là "và" khi sau nó là katakana/chữ Hán ("350円とパン") hoặc mở đầu một từ khoá danh mục
        // ("350円とお茶", "とうどん"). Còn lại thì thà để sót trợ từ còn hơn cắt mất chữ: "とんかつ", "とうふ".
        if !gap.isEmpty, folded[gap.lowerBound] == "と" {
            let rest = String(folded[(gap.lowerBound + 1)..<gap.upperBound])
            if !Self.isHiragana(folded[gap.lowerBound + 1])
                || (matcher.startsWithJapaneseKeyword(rest) && !matcher.startsWithJapaneseKeyword("と" + rest)) {
                words.append(gap.lowerBound..<gap.lowerBound + 1)
            }
        }
        let found = (marks.isEmpty ? words : marks).sorted { $0.lowerBound < $1.lowerBound }
        return last ? found.last : found.first
    }

    /// Bỏ chữ nối còn sót ở hai đầu ghi chú: "và bánh" → "bánh".
    static func trimConnectors(_ note: String) -> String {
        var words = note.split(separator: " ").map(String.init)
        let isConnector = { (word: String) in
            let bare = word.lowercased().trimmingCharacters(in: noteEdgePunctuation)
            return bare.isEmpty || connectorWords.contains(bare)
        }
        while let first = words.first, isConnector(first) { words.removeFirst() }
        while let last = words.last, isConnector(last) { words.removeLast() }
        return words.joined(separator: " ").trimmingCharacters(in: noteEdgePunctuation)
    }

    static func isHiragana(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return (0x3041...0x309F).contains(scalar.value)
    }
}
