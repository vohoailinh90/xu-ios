import SwiftUI
import SwiftData
import XuCore

@main
struct XuApp: App {
    init() {
        SampleData.seedQuickChipsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(SharedStore.container)
    }
}

/// Khoản quen mặc định để widget có nội dung ngay lần đầu.
/// TODO (M2): thay bằng đề xuất tự động từ các khoản lặp lại + màn hình ghim/bỏ ghim.
@MainActor
enum SampleData {
    static func seedQuickChipsIfNeeded() {
        let context = SharedStore.container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<QuickChip>())) ?? 0
        guard count == 0 else { return }
        let defaults: [(String, String, Int64, String)] = [
            ("Cà phê", "☕", 35_000, "drinks"),
            ("Grab", "🛵", 25_000, "transport"),
            ("Ăn trưa", "🍜", 45_000, "food"),
            ("Trà sữa", "🧋", 50_000, "drinks")
        ]
        for (index, item) in defaults.enumerated() {
            context.insert(QuickChip(title: item.0, emoji: item.1, amount: item.2,
                                     categoryID: item.3, sortOrder: index))
        }
        try? context.save()
    }
}
