import Foundation

public enum CategoryKind: String, Codable, Sendable {
    case expense
    case income
}

public struct CategoryDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let emoji: String
    public let kind: CategoryKind
    /// Khoản "tiêu vặt" — dùng cho thói quen "Ngày không tiêu vặt".
    public let isDiscretionary: Bool
    /// Từ khóa đã gấp (chữ thường, không dấu). Có thể nhiều âm tiết.
    public let keywords: [String]

    public init(id: String, name: String, emoji: String, kind: CategoryKind = .expense,
                isDiscretionary: Bool = false, keywords: [String]) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.kind = kind
        self.isDiscretionary = isDiscretionary
        self.keywords = keywords.map { TextFolding.fold($0) }
    }
}

public enum CategoryCatalog {
    public static let otherExpenseID = "other"
    public static let otherIncomeID = "income.other"

    /// Danh mục mặc định. Lưu ý khi thêm từ khóa: tránh từ một âm tiết dễ trùng nghĩa
    /// sau khi bỏ dấu (bé/be, chợ/cho, bạn/bán, trà/trả). Xem docs/04.
    public static let defaults: [CategoryDefinition] = [
        CategoryDefinition(id: "food", name: "Ăn uống", emoji: "🍜", keywords: [
            "an", "an sang", "an trua", "an toi", "an vat", "com", "com tam", "pho", "bun", "bun bo",
            "mi", "mien", "hu tieu", "banh mi", "banh cuon", "chao", "xoi", "lau", "nuong", "do an",
            "quan an", "nha hang", "kfc", "lotteria", "pizza", "grabfood", "shopeefood"
        ]),
        CategoryDefinition(id: "groceries", name: "Đi chợ", emoji: "🛒", keywords: [
            "di cho", "sieu thi", "rau", "thit", "ca", "trung", "gao", "trai cay", "winmart",
            "bach hoa xanh", "coopmart", "lotte mart", "aeon", "circle k", "gs25", "7-eleven"
        ]),
        CategoryDefinition(id: "drinks", name: "Cà phê & đồ uống", emoji: "☕", isDiscretionary: true, keywords: [
            "ca phe", "cafe", "cf", "cafe sua", "bac xiu", "tra sua", "ts", "tra da", "tra chanh",
            "tra dao", "sinh to", "nuoc ep", "nuoc", "bia", "highlands", "phuc long", "starbucks",
            "katinat", "the coffee house", "trung nguyen", "cong ca phe", "gong cha", "tocotoco"
        ]),
        CategoryDefinition(id: "transport", name: "Di chuyển", emoji: "🛵", keywords: [
            "grab", "grabbike", "grabcar", "xanh sm", "taxi", "xang", "do xang", "gui xe", "ve xe",
            "bus", "xe buyt", "xe om", "gojek", "sua xe", "rua xe", "ve tau", "ve may bay", "metro", "cau duong"
        ]),
        CategoryDefinition(id: "bills", name: "Hóa đơn & nhà", emoji: "🧾", keywords: [
            "hoa don", "tien dien", "dien", "tien nuoc", "internet", "wifi", "tien mang", "tien nha",
            "thue nha", "tien phong", "dien thoai", "nap the", "nap tien dien thoai", "4g", "phi chung cu", "gas"
        ]),
        CategoryDefinition(id: "shopping", name: "Mua sắm", emoji: "🛍️", isDiscretionary: true, keywords: [
            "shopee", "lazada", "tiki", "tiktok shop", "quan ao", "ao", "quan jean", "giay", "dep", "tui",
            "my pham", "son", "mua sam", "uniqlo", "zara", "do gia dung"
        ]),
        CategoryDefinition(id: "entertainment", name: "Giải trí", emoji: "🎬", isDiscretionary: true, keywords: [
            "phim", "xem phim", "cgv", "lotte cinema", "game", "karaoke", "netflix", "spotify",
            "youtube", "concert", "du lich", "khach san", "bida", "choi"
        ]),
        CategoryDefinition(id: "health", name: "Sức khỏe", emoji: "💊", keywords: [
            "thuoc", "nha thuoc", "kham", "kham benh", "bac si", "benh vien", "nha khoa", "gym", "yoga", "bao hiem"
        ]),
        CategoryDefinition(id: "family", name: "Gia đình & quà", emoji: "🎁", keywords: [
            "qua", "sinh nhat", "dam cuoi", "dam gio", "bieu", "li xi", "lixi", "mung", "gui ve nha", "gui me", "gui bo"
        ]),
        CategoryDefinition(id: "education", name: "Học tập", emoji: "📚", keywords: [
            "hoc phi", "sach", "khoa hoc", "hoc", "udemy", "ielts", "toeic"
        ]),
        CategoryDefinition(id: otherExpenseID, name: "Khác", emoji: "📦", keywords: []),

        CategoryDefinition(id: "income.salary", name: "Lương", emoji: "💰", kind: .income, keywords: [
            "luong", "tien luong", "nhan luong"
        ]),
        CategoryDefinition(id: "income.bonus", name: "Thưởng", emoji: "🎉", kind: .income, keywords: [
            "thuong", "tien thuong", "bonus"
        ]),
        CategoryDefinition(id: otherIncomeID, name: "Thu nhập khác", emoji: "💵", kind: .income, keywords: [
            "thu nhap", "nhan tien", "hoan tien", "duoc cho", "duoc tang", "tien lai", "freelance"
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
        guard let hit = longestMatch(in: padded, candidates: defaults) else { return nil }
        return catalog.first(where: { $0.id == hit })
    }

    private func longestMatch(in padded: String, candidates: [(String, String)]) -> String? {
        var best: (length: Int, id: String)?
        for (keyword, id) in candidates where !keyword.isEmpty {
            if padded.contains(" " + keyword + " "), keyword.count > (best?.length ?? 0) {
                best = (keyword.count, id)
            }
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
