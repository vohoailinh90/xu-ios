import SwiftUI
import SwiftData
import XuCore

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TransactionRecord.occurredAt, order: .reverse) private var records: [TransactionRecord]
    @Query(sort: \QuickChip.sortOrder) private var chips: [QuickChip]
    // Ngân sách tính bằng tiền của nơi chi tiêu, nên mỗi nơi một con số (khóa cũ giữ cho Việt Nam).
    @AppStorage("flexibleMonthlyBudget") private var budgetVietnam: Int = 0
    @AppStorage("flexibleMonthlyBudget.japan") private var budgetJapan: Int = 0
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    @AppStorage(AppSettings.Key.market, store: AppSettings.defaults) private var market: Market = .vietnam

    @State private var focusTrigger = 0
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TodayCard(records: records,
                              flexibleBudget: Int64(market == .japan ? budgetJapan : budgetVietnam),
                              currency: market.currency, language: language)
                }
                if !chips.isEmpty {
                    Section(language.t(.quickChips)) { ChipRow(chips: chips, language: language) }
                }
                ForEach(groupedByDay, id: \.day) { group in
                    Section {
                        ForEach(group.items) { TransactionRow(record: $0, language: language) }
                            .onDelete { offsets in
                                for i in offsets { try? Ledger.delete(group.items[i], in: context) }
                            }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Text(group.spent)
                        }
                    }
                }
            }
            .navigationTitle("Xu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: CSVFile(records: records, language: language),
                              preview: SharePreview(language.t(.csvPreviewTitle))) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(language.t(.exportCSV))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(language.t(.settings))
                }
            }
            .safeAreaInset(edge: .bottom) {
                QuickEntryBar(focusTrigger: focusTrigger)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .onOpenURL { url in
            if url.host == "new" { focusTrigger += 1 }
        }
    }

    private struct DayGroup { let day: DayKey; let title: String; let items: [TransactionRecord]; let spent: String }

    private var groupedByDay: [DayGroup] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: records) { DayKey($0.occurredAt, calendar: cal) }
        return groups.keys.sorted(by: >).map { day in
            let items = groups[day] ?? []
            return DayGroup(day: day,
                            title: DayLabel.text(for: day.date(in: cal), language: language, calendar: cal),
                            items: items,
                            spent: SpendingSummary.text(for: items, primary: market.currency, language: language))
        }
    }
}

// MARK: - Thẻ "Hôm nay"

private struct TodayCard: View {
    let records: [TransactionRecord]
    let flexibleBudget: Int64
    /// Tiền của nơi chi tiêu. Khoản bằng tiền khác hiện riêng, không quy đổi.
    let currency: Currency
    let language: AppLanguage

    var body: some View {
        let cal = Calendar.current
        let today = DayKey(Date(), calendar: cal)
        let expenses = records.filter { !$0.isIncome && $0.currency == currency }
        let spentToday = expenses.filter { cal.isDateInToday($0.occurredAt) }.reduce(0) { $0 + $1.amount }
        let otherToday = records.filter { $0.currency != currency && cal.isDateInToday($0.occurredAt) }

        VStack(alignment: .leading, spacing: 8) {
            Text(language.t(.spentToday)).font(.subheadline).foregroundStyle(.secondary)
            Text(MoneyFormatter.full(spentToday, currency: currency, language: language))
                .font(.largeTitle.bold()).contentTransition(.numericText())

            if SpendingSummary.totals(of: otherToday).values.contains(where: { $0 > 0 }) {
                Text(language.t(.otherCurrencies, SpendingSummary.text(for: otherToday, primary: currency, language: language)))
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if flexibleBudget > 0 {
                let safe = safeToSpend(expenses: expenses, today: today, calendar: cal)
                // Không dùng màu đỏ trừng phạt — xem docs/05-thoi-quen-tai-chinh.md
                if safe.isOverToday, let adjusted = safe.adjustedAllowanceForComingDays {
                    Text(language.t(.overToday, MoneyFormatter.compact(adjusted, currency: currency, language: language)))
                        .font(.callout)
                } else {
                    (Text(language.t(.remainingToday) + " ")
                        + Text(MoneyFormatter.compact(safe.remainingToday, currency: currency, language: language)).bold())
                        .font(.callout)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Chỉ tính các danh mục chi tiêu linh hoạt (cà phê, mua sắm, giải trí…).
    private func safeToSpend(expenses: [TransactionRecord], today: DayKey, calendar: Calendar) -> SafeToSpend {
        let flexible = Set(CategoryCatalog.defaults.filter(\.isDiscretionary).map(\.id))
        var before: Int64 = 0, todaySum: Int64 = 0
        for r in expenses where flexible.contains(r.categoryID) {
            let day = DayKey(r.occurredAt, calendar: calendar)
            guard day.year == today.year, day.month == today.month else { continue }
            if day == today { todaySum += r.amount } else if day < today { before += r.amount }
        }
        return SafeToSpend.compute(flexibleBudget: flexibleBudget, spentBeforeToday: before, spentToday: todaySum,
                                   today: today, periodEnd: SafeToSpend.endOfMonth(containing: today, calendar: calendar),
                                   calendar: calendar)
    }
}

// MARK: - Khoản quen (chạm là ghi)

private struct ChipRow: View {
    @Environment(\.modelContext) private var context
    let chips: [QuickChip]
    let language: AppLanguage
    @State private var taps = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(chips) { chip in
                    Button {
                        try? Ledger.save(chip: chip, in: context)
                        taps += 1
                    } label: {
                        Text(chip.emoji + " " + chip.title + " "
                             + MoneyFormatter.compact(chip.amount, currency: chip.currency, language: language))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .sensoryFeedback(.success, trigger: taps)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

private struct TransactionRow: View {
    let record: TransactionRecord
    let language: AppLanguage

    var body: some View {
        HStack {
            Text(record.category.emoji).font(.title3)
            VStack(alignment: .leading) {
                Text(record.note.isEmpty ? record.category.name(in: language) : record.note)
                Text(record.category.name(in: language)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(MoneyFormatter.signed(record.amount, isIncome: record.isIncome,
                                       currency: record.currency, language: language))
                .monospacedDigit()
                .foregroundStyle(record.isIncome ? .green : .primary)
        }
    }
}
