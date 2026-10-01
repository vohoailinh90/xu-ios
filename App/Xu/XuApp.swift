import SwiftUI
import SwiftData
import XuCore

@main
struct XuApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppSettings.registerDefaults()
        SampleData.seedQuickChipsIfNeeded()
        SampleData.seedHabitsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .onChange(of: scenePhase) {
                    // Mỗi lần quay lại app: nạp thêm lịch nhắc chốt ngày cho các ngày tới.
                    if scenePhase == .active { ReminderScheduler.refresh() }
                }
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
        insertSeeds(in: context)
    }

    /// "Ghi chép mỗi ngày" là thói quen mặc định, bật sẵn (docs/05).
    static func seedHabitsIfNeeded() {
        let context = SharedStore.container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<MoneyHabit>())) ?? 0
        guard count == 0 else { return }
        context.insert(MoneyHabit(template: .logDaily))
        try? context.save()
    }

    /// Đổi ngôn ngữ hoặc nơi chi tiêu: thay khoản quen mặc định cho hợp (tên, loại tiền),
    /// nhưng chỉ khi người dùng chưa đụng tới chúng — khoản quen người dùng tự sửa (M2) không bao giờ bị ghi đè.
    static func refreshSeedsIfUntouched() {
        let context = SharedStore.container.mainContext
        let chips = (try? context.fetch(FetchDescriptor<QuickChip>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        guard isUntouchedSeed(chips) else { return }
        for chip in chips { context.delete(chip) }
        insertSeeds(in: context)
    }

    private static func isUntouchedSeed(_ chips: [QuickChip]) -> Bool {
        if chips.isEmpty { return true }
        return Market.allCases.contains { market in
            let expected = ChipSeeds.seeds(for: market)
            return chips.count == expected.count && zip(chips, expected).allSatisfy { chip, seed in
                chip.emoji == seed.emoji && chip.amount == seed.amount && chip.categoryID == seed.categoryID
                    && chip.currency == market.currency
                    && AppLanguage.allCases.contains { seed.title[$0] == chip.title }
            }
        }
    }

    private static func insertSeeds(in context: ModelContext) {
        let market = AppSettings.market
        let language = AppSettings.language
        for (index, seed) in ChipSeeds.seeds(for: market).enumerated() {
            context.insert(QuickChip(title: seed.title[language], emoji: seed.emoji, amount: seed.amount,
                                     currency: market.currency, categoryID: seed.categoryID, sortOrder: index))
        }
        try? context.save()
    }
}
