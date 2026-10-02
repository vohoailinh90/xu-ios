import Foundation

public enum CategoryKind: String, Codable, Sendable {
    case expense
    case income
}

public struct CategoryDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let names: LocalizedText
    public let emoji: String
    public let kind: CategoryKind
    /// Khoản "tiêu vặt" — dùng cho thói quen "Ngày không tiêu vặt".
    public let isDiscretionary: Bool
    /// Từ khóa đã gấp (chữ thường, không dấu, nửa khổ). Có thể nhiều âm tiết.
    public let keywords: [String]
    /// Từ khóa so khớp **có dấu** (chữ thường), cho âm tiết mà bỏ dấu thì trùng nghĩa:
    /// "cá" ≠ "cả", "trứng" ≠ "trung tâm", "túi" ≠ "tui". Chỉ dùng khi không có từ khoá đã gấp nào khớp.
    /// Gõ không dấu thì không khớp — thà để "Khác" còn hơn xếp nhầm.
    public let accentedKeywords: [String]

    public init(id: String, names: LocalizedText, emoji: String, kind: CategoryKind = .expense,
                isDiscretionary: Bool = false, keywords: [String], accentedKeywords: [String] = []) {
        self.id = id
        self.names = names
        self.emoji = emoji
        self.kind = kind
        self.isDiscretionary = isDiscretionary
        self.keywords = keywords.map { TextFolding.fold($0) }
        self.accentedKeywords = accentedKeywords.map { $0.precomposedStringWithCanonicalMapping.lowercased() }
    }

    public func name(in language: AppLanguage) -> String { names[language] }
}

public enum CategoryCatalog {
    public static let otherExpenseID = "other"
    public static let otherIncomeID = "income.other"

    /// Danh mục mặc định. Lưu ý khi thêm từ khóa (xem docs/04):
    /// - Tiếng Việt: tránh từ một âm tiết dễ trùng nghĩa sau khi bỏ dấu (bé/be, chợ/cho, bạn/bán, trà/trả,
    ///   túi/tui, cá/cả, trứng/trung tâm, mừng/mùng, son/Sơn). Dùng cụm hai âm tiết ("tui xach", "son moi"),
    ///   hoặc đưa từ có dấu vào `accentedKeywords` ("cá", "trứng"). Cụm đã gấp cũng có thể trùng: "mua ca" khớp
    ///   cả "mua cà phê" lẫn "mua cả sách". Test `testAmbiguousSyllablesAreNotKeywords` giữ danh sách này.
    /// - Tiếng Nhật được so khớp **chuỗi con** (không có khoảng trắng giữa từ), nên tránh từ một chữ Hán
    ///   nằm trong từ khác: "本" có trong "日本", "パン" có trong "パンツ". Dùng từ dài hơn: "本屋", "パン屋".
    public static let defaults: [CategoryDefinition] = [
        CategoryDefinition(id: "food", names: LocalizedText(vi: "Ăn uống", en: "Food", ja: "食事"), emoji: "🍜", keywords: [
            "an", "an sang", "an trua", "an toi", "an vat", "com", "com tam", "pho", "bun", "bun bo",
            "mi", "mien", "hu tieu", "banh mi", "banh cuon", "chao", "xoi", "lau", "nuong", "do an",
            "quan an", "nha hang", "kfc", "lotteria", "pizza", "grabfood", "shopeefood",
            // English
            "lunch", "dinner", "breakfast", "meal", "food", "restaurant", "ramen", "sushi", "burger",
            "mcdonald", "uber eats", "snack", "pasta",
            // 日本語
            "ラーメン", "うどん", "そば", "寿司", "すし", "牛丼", "定食", "弁当", "ランチ", "昼ごはん", "昼食",
            "夕食", "晩ごはん", "夜ごはん", "朝ごはん", "朝食", "外食", "居酒屋", "焼肉", "カレー", "パン屋",
            "マクドナルド", "マック", "ケンタッキー", "すき家", "吉野家", "松屋", "サイゼリヤ", "ガスト",
            "餃子", "ピザ", "パスタ", "から揚げ", "唐揚げ", "ご飯", "ごはん", "飲み会", "おにぎり", "のり弁", "出前館"
        ]),
        CategoryDefinition(id: "groceries", names: LocalizedText(vi: "Đi chợ", en: "Groceries", ja: "食料品・日用品"),
                           emoji: "🛒", keywords: [
            "di cho", "sieu thi", "rau", "thit", "trung ga", "trung vit",
            "gao", "trai cay", "nuoc mam", "nuoc tuong", "dau an", "giay ve sinh", "bot giat", "winmart",
            "bach hoa xanh", "coopmart", "lotte mart", "aeon", "circle k", "gs25", "7-eleven",
            // Người Việt ở Nhật hay gõ chữ Latin
            "konbini", "combini", "lawson", "familymart", "family mart", "seven eleven",
            // English
            "groceries", "grocery", "supermarket", "convenience store",
            // 日本語
            "コンビニ", "セブン", "ローソン", "ファミマ", "ファミリーマート", "ミニストップ", "スーパー",
            "イオン", "業務スーパー", "西友", "イトーヨーカドー", "マックスバリュ", "八百屋", "食料品", "食材", "野菜",
            "お米", "日用品"
        ], accentedKeywords: ["cá", "trứng"]),
        CategoryDefinition(id: "drinks", names: LocalizedText(vi: "Cà phê & đồ uống", en: "Coffee & drinks", ja: "カフェ・飲み物"),
                           emoji: "☕", isDiscretionary: true, keywords: [
            "ca phe", "cafe", "cf", "cafe sua", "bac xiu", "tra sua", "ts", "tra da", "tra chanh",
            "tra dao", "sinh to", "nuoc ep", "nuoc", "bia", "highlands", "phuc long", "starbucks",
            "katinat", "the coffee house", "trung nguyen", "cong ca phe", "gong cha", "tocotoco",
            // English
            "coffee", "latte", "tea", "bubble tea", "boba", "juice", "beer", "drinks",
            // 日本語
            "コーヒー", "カフェ", "スタバ", "スターバックス", "ドトール", "タリーズ", "コメダ", "お茶", "紅茶",
            "タピオカ", "ジュース", "飲み物", "ビール", "お酒"
        ]),
        CategoryDefinition(id: "transport", names: LocalizedText(vi: "Di chuyển", en: "Transport", ja: "交通"),
                           emoji: "🛵", keywords: [
            "grab", "grabbike", "grabcar", "xanh sm", "taxi", "xang", "do xang", "gui xe", "ve xe",
            "bus", "xe buyt", "xe om", "gojek", "sua xe", "rua xe", "ve tau", "ve may bay", "metro", "cau duong",
            "tau dien", "shinkansen", "suica", "pasmo", "icoca",
            // English
            "train", "subway", "uber", "parking", "flight", "fuel",
            // 日本語
            "電車", "地下鉄", "バス", "タクシー", "新幹線", "定期券", "乗車券", "交通費", "切符", "ガソリン", "駐車場",
            "駐輪場", "高速代", "飛行機", "航空券", "レンタカー"
        ]),
        CategoryDefinition(id: "bills", names: LocalizedText(vi: "Hóa đơn & nhà", en: "Bills & home", ja: "住まい・光熱費"),
                           emoji: "🧾", keywords: [
            "hoa don", "tien dien", "dien", "tien nuoc", "internet", "wifi", "tien mang", "tien nha",
            "thue nha", "tien phong", "dien thoai", "nap the", "nap tien dien thoai", "4g", "phi chung cu", "gas",
            // English
            "rent", "electricity", "electric bill", "water bill", "phone bill", "utilities",
            // 日本語
            "家賃", "電気代", "電気料金", "ガス代", "水道代", "光熱費", "携帯代", "スマホ代", "ネット代",
            "通信費", "管理費", "税金"
        ]),
        CategoryDefinition(id: "shopping", names: LocalizedText(vi: "Mua sắm", en: "Shopping", ja: "買い物"),
                           emoji: "🛍️", isDiscretionary: true, keywords: [
            "shopee", "lazada", "tiki", "tiktok shop", "quan ao", "ao", "quan jean", "giay", "dep", "tui xach",
            "balo", "my pham", "son moi", "mua sam", "uniqlo", "zara", "do gia dung", "daiso", "donki", "don quijote",
            // English
            "amazon", "rakuten", "clothes", "shoes", "shopping", "ikea", "mercari",
            // 日本語
            "楽天", "ユニクロ", "ダイソー", "100均", "百均", "100円ショップ", "セリア", "無印", "ニトリ",
            "ドンキ", "キホーテ", "メルカリ", "百貨店", "デパート", "洋服", "服", "靴", "パンツ", "化粧品", "買い物"
        ], accentedKeywords: ["túi"]),
        CategoryDefinition(id: "entertainment", names: LocalizedText(vi: "Giải trí", en: "Entertainment", ja: "娯楽"),
                           emoji: "🎬", isDiscretionary: true, keywords: [
            "phim", "xem phim", "cgv", "lotte cinema", "game", "karaoke", "netflix", "spotify",
            "youtube", "concert", "du lich", "khach san", "bida", "choi",
            // English
            "movie", "cinema", "travel", "hotel",
            // 日本語
            "映画", "カラオケ", "ゲーム", "旅行", "ホテル", "温泉", "ライブ", "コンサート", "遊園地", "ディズニー"
        ]),
        CategoryDefinition(id: "health", names: LocalizedText(vi: "Sức khỏe", en: "Health", ja: "医療・健康"),
                           emoji: "💊", keywords: [
            "thuoc", "nha thuoc", "kham", "kham benh", "bac si", "benh vien", "nha khoa", "gym", "yoga", "bao hiem",
            // English
            "medicine", "pharmacy", "doctor", "dentist", "hospital", "insurance",
            // 日本語
            "薬", "薬局", "病院", "歯医者", "クリニック", "ドラッグストア", "マツキヨ", "整骨院", "保険", "ジム"
        ]),
        CategoryDefinition(id: "family", names: LocalizedText(vi: "Gia đình & quà", en: "Family & gifts", ja: "家族・贈り物"),
                           emoji: "🎁", keywords: [
            "qua", "sinh nhat", "dam cuoi", "dam gio", "bieu", "li xi", "lixi", "mung cuoi", "tien mung", "mung tuoi",
            "gui ve nha", "gui me", "gui bo",
            "gui tien ve", "gui tien ve nha", "chuyen tien ve", "chuyen tien ve nha",
            // English
            "gift", "present", "birthday", "wedding", "send home", "remittance",
            // 日本語
            "仕送り", "送金", "実家", "プレゼント", "お土産", "誕生日", "結婚式", "お祝い", "ご祝儀"
        ], accentedKeywords: ["mừng"]),
        CategoryDefinition(id: "education", names: LocalizedText(vi: "Học tập", en: "Learning", ja: "学び"),
                           emoji: "📚", keywords: [
            "hoc phi", "sach", "khoa hoc", "hoc", "udemy", "ielts", "toeic", "jlpt", "tieng anh", "tieng nhat",
            "hoc tieng", "trung tam ngoai ngu",
            // English
            "tuition", "books", "course", "textbook",
            // 日本語
            "学費", "授業料", "教科書", "参考書", "本屋", "書籍", "塾", "日本語学校", "習い事"
        ]),
        CategoryDefinition(id: otherExpenseID, names: LocalizedText(vi: "Khác", en: "Other", ja: "その他"),
                           emoji: "📦", keywords: []),

        CategoryDefinition(id: "income.salary", names: LocalizedText(vi: "Lương", en: "Salary", ja: "給料"),
                           emoji: "💰", kind: .income, keywords: [
            "luong", "tien luong", "nhan luong", "salary", "paycheck", "wage", "wages",
            "給料", "給与", "バイト代"
        ]),
        CategoryDefinition(id: "income.bonus", names: LocalizedText(vi: "Thưởng", en: "Bonus", ja: "ボーナス"),
                           emoji: "🎉", kind: .income, keywords: [
            "thuong", "tien thuong", "bonus", "ボーナス", "賞与"
        ]),
        CategoryDefinition(id: otherIncomeID, names: LocalizedText(vi: "Thu nhập khác", en: "Other income", ja: "その他の収入"),
                           emoji: "💵", kind: .income, keywords: [
            "thu nhap", "nhan tien", "hoan tien", "duoc cho", "duoc tang", "tien lai", "freelance",
            "income", "refund", "cashback", "収入", "臨時収入", "返金"
        ])
    ]

    private static let byID: [String: CategoryDefinition] =
        Dictionary(uniqueKeysWithValues: defaults.map { ($0.id, $0) })

    public static func category(id: String) -> CategoryDefinition? { byID[id] }

    public static func resolve(id: String?, fallback: String = otherExpenseID) -> CategoryDefinition {
        (id.flatMap { byID[$0] }) ?? byID[fallback]!
    }
}

/// So khớp danh mục theo cụm từ nguyên vẹn, cụm dài nhất thắng.
/// Từ khóa người dùng đã dạy (`learned`) được ưu tiên hơn từ khóa mặc định.
/// Từ khóa có chữ Nhật được so khớp chuỗi con, vì tiếng Nhật không có khoảng trắng giữa các từ.
public struct CategoryMatcher: Sendable {
    public var catalog: [CategoryDefinition]
    /// cụm từ đã gấp → categoryID
    public var learned: [String: String]

    public init(catalog: [CategoryDefinition] = CategoryCatalog.defaults, learned: [String: String] = [:]) {
        self.catalog = catalog
        self.learned = learned
    }

    /// Khóa để lưu khi người dùng sửa danh mục: ghi chú đã gấp, chuẩn hóa khoảng trắng.
    public static func learningKey(for note: String) -> String {
        normalize(TextFolding.fold(note)).trimmingCharacters(in: .whitespaces)
    }

    public func match(note: String) -> CategoryDefinition? {
        let padded = " " + Self.normalize(TextFolding.fold(note)) + " "
        guard padded.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }

        if let hit = longestMatch(in: padded, candidates: learned.map { ($0.key, $0.value) }),
           let category = catalog.first(where: { $0.id == hit }) {
            return category
        }
        let defaults = catalog.flatMap { category in category.keywords.map { ($0, category.id) } }
        let accented = catalog.flatMap { category in category.accentedKeywords.map { ($0, category.id) } }
        let accentedPadded = " " + Self.normalize(note.precomposedStringWithCanonicalMapping.lowercased()) + " "
        // Từ có dấu chỉ là phương án cuối, khi không có từ khoá nào khác khớp: "cá 50k", "trứng 30k" → đi chợ.
        // Có từ khác thì từ đó quyết, kể cả ngắn hơn: "ăn trứng", "ăn cá" là ăn uống; "mua cà phê" là đồ uống.
        guard let hit = longestMatch(in: padded, candidates: defaults)
                ?? longestMatch(in: accentedPadded, candidates: accented) else { return nil }
        return catalog.first(where: { $0.id == hit })
    }

    private func longestMatch(in padded: String, candidates: [(String, String)]) -> String? {
        var best: (length: Int, id: String)?
        for (keyword, id) in candidates where !keyword.isEmpty && keyword.count > (best?.length ?? 0) {
            let hit = TextFolding.containsCJK(keyword) ? padded.contains(keyword) : padded.contains(" " + keyword + " ")
            if hit { best = (keyword.count, id) }
        }
        return best?.id
    }

    /// Thay dấu câu bằng khoảng trắng và gộp khoảng trắng liên tiếp.
    static func normalize(_ folded: String) -> String {
        let mapped = folded.map { ch -> Character in
            (ch.isLetter || ch.isNumber || ch == "-") ? ch : " "
        }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }
}
