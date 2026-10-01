import WidgetKit
import SwiftData
import XuCore

struct ChipSnapshot: Identifiable, Hashable {
    let id: UUID
    let title: String
    let emoji: String
    let amount: Int64
    let currency: Currency
}

struct XuEntry: TimelineEntry {
    let date: Date
    /// Chỉ tính tiền của nơi chi tiêu (`currency`); khoản bằng tiền khác không cộng lẫn vào.
    let spentToday: Int64
    let currency: Currency
    let language: AppLanguage
    let chips: [ChipSnapshot]

    /// Mẫu cho thư viện widget, theo ngôn ngữ và nơi chi tiêu đang chọn.
    static var placeholder: XuEntry {
        let market = AppSettings.market
        let language = AppSettings.language
        let chips = ChipSeeds.seeds(for: market).map {
            ChipSnapshot(id: UUID(), title: $0.title[language], emoji: $0.emoji, amount: $0.amount, currency: market.currency)
        }
        let spent: Int64 = market == .japan ? 1_850 : 125_000
        return XuEntry(date: .now, spentToday: spent, currency: market.currency, language: language, chips: chips)
    }
}

struct XuTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> XuEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (XuEntry) -> Void) {
        completion(context.isPreview ? .placeholder : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<XuEntry>) -> Void) {
        // App gọi WidgetCenter.reloadAllTimelines() sau mỗi lần ghi và khi đổi ngôn ngữ/nơi chi tiêu.
        // Ngoài ra làm mới lúc nửa đêm để "hôm nay" về 0.
        let midnight = Calendar.current.nextDate(after: .now, matching: DateComponents(hour: 0), matchingPolicy: .nextTime) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [loadEntry()], policy: .after(midnight)))
    }

    private func loadEntry() -> XuEntry {
        let context = ModelContext(SharedStore.container)
        let calendar = Calendar.current
        let currency = AppSettings.market.currency
        let currencyCode = currency.code
        let start = calendar.startOfDay(for: .now)
        // Cận trên: khoản ghi cho ngày tương lai (ví dụ "1/1/2030") không tính vào hôm nay, giống TodayCard.
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let todayDescriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate {
                $0.occurredAt >= start && $0.occurredAt < end && $0.isIncome == false && $0.currencyCode == currencyCode
            })
        let spent = ((try? context.fetch(todayDescriptor)) ?? []).reduce(0) { $0 + $1.amount }

        var chipDescriptor = FetchDescriptor<QuickChip>(sortBy: [SortDescriptor(\.sortOrder)])
        chipDescriptor.fetchLimit = 4
        let chips = ((try? context.fetch(chipDescriptor)) ?? []).map {
            ChipSnapshot(id: $0.id, title: $0.title, emoji: $0.emoji, amount: $0.amount, currency: $0.currency)
        }
        return XuEntry(date: .now, spentToday: spent, currency: currency, language: AppSettings.language, chips: chips)
    }
}
