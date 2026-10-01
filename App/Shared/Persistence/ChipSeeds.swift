import Foundation
import XuCore

/// Khoản quen mặc định theo nơi chi tiêu, để widget có nội dung ngay lần đầu.
/// Số tiền chỉ là gợi ý ban đầu, không phải giá thật.
enum ChipSeeds {
    struct Seed {
        let title: LocalizedText
        let emoji: String
        let amount: Int64
        let categoryID: String
    }

    static func seeds(for market: Market) -> [Seed] {
        switch market {
        case .vietnam:
            return [
                Seed(title: LocalizedText(vi: "Cà phê", en: "Coffee", ja: "コーヒー"), emoji: "☕", amount: 35_000, categoryID: "drinks"),
                Seed(title: LocalizedText(vi: "Grab", en: "Grab", ja: "Grab"), emoji: "🛵", amount: 25_000, categoryID: "transport"),
                Seed(title: LocalizedText(vi: "Ăn trưa", en: "Lunch", ja: "ランチ"), emoji: "🍜", amount: 45_000, categoryID: "food"),
                Seed(title: LocalizedText(vi: "Trà sữa", en: "Bubble tea", ja: "タピオカ"), emoji: "🧋", amount: 50_000, categoryID: "drinks")
            ]
        case .japan:
            return [
                Seed(title: LocalizedText(vi: "Konbini", en: "Konbini", ja: "コンビニ"), emoji: "🏪", amount: 500, categoryID: "groceries"),
                Seed(title: LocalizedText(vi: "Tàu điện", en: "Train", ja: "電車"), emoji: "🚃", amount: 200, categoryID: "transport"),
                Seed(title: LocalizedText(vi: "Ăn trưa", en: "Lunch", ja: "ランチ"), emoji: "🍱", amount: 1_000, categoryID: "food"),
                Seed(title: LocalizedText(vi: "Cà phê", en: "Coffee", ja: "コーヒー"), emoji: "☕", amount: 150, categoryID: "drinks")
            ]
        }
    }
}
