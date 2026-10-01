import WidgetKit
import SwiftData
import XuCore

struct ChipSnapshot: Identifiable, Hashable {
    let id: UUID
    let title: String
    let emoji: String
    let amount: Int64
}

struct XuEntry: TimelineEntry {
    let date: Date
    let spentToday: Int64
    let chips: [ChipSnapshot]

    static let placeholder = XuEntry(date: .now, spentToday: 125_000, chips: [
        ChipSnapshot(id: UUID(), title: "Cà phê", emoji: "☕", amount: 35_000),
        ChipSnapshot(id: UUID(), title: "Ăn trưa", emoji: "🍜", amount: 50_000),
        ChipSnapshot(id: UUID(), title: "Gửi xe", emoji: "🛵", amount: 5_000),
        ChipSnapshot(id: UUID(), title: "Trà sữa", emoji: "🧋", amount: 45_000)
    ])
}

struct XuTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> XuEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (XuEntry) -> Void) {
        completion(context.isPreview ? .placeholder : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<XuEntry>) -> Void) {
        // App gọi WidgetCenter.reloadAllTimelines() sau mỗi lần ghi.
        // Ngoài ra làm mới lúc nửa đêm để "hôm nay" về 0.
        let midnight = Calendar.current.nextDate(after: .now, matching: DateComponents(hour: 0), matchingPolicy: .nextTime) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [loadEntry()], policy: .after(midnight)))
    }

    private func loadEntry() -> XuEntry {
        let context = ModelContext(SharedStore.container)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        // Cận trên: khoản ghi cho ngày tương lai (ví dụ "1/1/2030") không tính vào hôm nay, giống TodayCard.
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let todayDescriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.occurredAt >= start && $0.occurredAt < end && $0.isIncome == false })
        let spent = ((try? context.fetch(todayDescriptor)) ?? []).reduce(0) { $0 + $1.amount }

        var chipDescriptor = FetchDescriptor<QuickChip>(sortBy: [SortDescriptor(\.sortOrder)])
        chipDescriptor.fetchLimit = 4
        let chips = ((try? context.fetch(chipDescriptor)) ?? []).map {
            ChipSnapshot(id: $0.id, title: $0.title, emoji: $0.emoji, amount: $0.amount)
        }
        return XuEntry(date: .now, spentToday: spent, chips: chips)
    }
}
