import SwiftUI
import SwiftData
import XuCore

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TransactionRecord.occurredAt, order: .reverse) private var records: [TransactionRecord]
    @Query(sort: \QuickChip.sortOrder) private var chips: [QuickChip]
    @Query private var closures: [DayClosure]
    // Ngân sách tính bằng tiền của nơi chi tiêu, nên mỗi nơi một con số (khóa cũ giữ cho Việt Nam).
    @AppStorage("flexibleMonthlyBudget") private var budgetVietnam: Int = 0
    @AppStorage("flexibleMonthlyBudget.japan") private var budgetJapan: Int = 0
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    @AppStorage(AppSettings.Key.market, store: AppSettings.defaults) private var market: Market = .vietnam
    @AppStorage(AppSettings.Key.focusRequest, store: AppSettings.defaults) private var focusRequest: Double = 0
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    @State private var focusTrigger = 0
    @State private var showSettings = false
    @State private var showHabits = false
    @State private var showChips = false
    @State private var editing: TransactionRecord?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TodayCard(records: records,
                              flexibleBudget: Int64(market == .japan ? budgetJapan : budgetVietnam),
                              currency: market.currency, language: language)
                }
                if !chips.isEmpty {
                    Section {
                        ChipRow(chips: chips, language: language)
                    } header: {
                        HStack {
                            Text(language.t(.quickChips))
                            Spacer()
                            Button(language.t(.editChips)) { showChips = true }
                                .font(.footnote)
                                .textCase(nil)
                        }
                    }
                }
                let week = weeklySummary
                if !week.isEmpty {
                    Section(language.t(.weekTitle)) {
                        WeekCard(summary: week, primary: market.currency, language: language)
                    }
                }
                ForEach(groupedByDay, id: \.day) { group in
                    Section {
                        ForEach(group.items) { record in
                            Button { editing = record } label: {
                                TransactionRow(record: record, language: language)
                            }
                            .buttonStyle(.plain)
                        }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHabits = true } label: { Image(systemName: "leaf") }
                        .accessibilityLabel(language.t(.habitsTitle))
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
            .sheet(isPresented: $showHabits) { HabitsView() }
            .sheet(isPresented: $showChips) {
                NavigationStack {
                    QuickChipsManager()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(language.t(.done)) { showChips = false }
                            }
                        }
                }
            }
            .fullScreenCover(isPresented: showOnboarding) {
                OnboardingView {
                    hasOnboarded = true
                    focusTrigger += 1
                }
            }
            .sheet(item: $editing) { TransactionEditor(record: $0) }
        }
        .onOpenURL { url in
            if url.host == "new" { focusTrigger += 1 }
        }
        .onChange(of: focusRequest) {
            // "Ghi thêm" trên thông báo chốt ngày: đóng mọi sheet đang che ô nhập rồi focus.
            showSettings = false
            showHabits = false
            editing = nil
            showChips = false
            focusTrigger += 1
        }
    }

    /// Onboarding chỉ hiện lần mở đầu; xong hoặc bỏ qua thì không hiện lại.
    private var showOnboarding: Binding<Bool> {
        Binding(get: { !hasOnboarded }, set: { if !$0 { hasOnboarded = true } })
    }

    private var weeklySummary: WeeklySummary {
        let cal = Calendar.current
        let entries = records.map {
            LedgerEntry(amount: $0.amount, isIncome: $0.isIncome, categoryID: $0.categoryID,
                        day: DayKey($0.occurredAt, calendar: cal), currency: $0.currency)
        }
        return WeeklySummary.compute(entries: entries, closedDays: Set(closures.map(\.dayKey)),
                                     today: DayKey(Date(), calendar: cal), primary: market.currency, calendar: cal)
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
                if safe.isBudgetUsedUp {
                    Text(language.t(.budgetUsedUp)).font(.callout)
                } else if safe.isOverToday, let adjusted = safe.adjustedAllowanceForComingDays {
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

// MARK: - Nhìn lại tuần này

private struct WeekCard: View {
    let summary: WeeklySummary
    let primary: Currency
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(language.t(.weekSpent, spentText)).font(.headline)
            if let id = summary.topCategoryID {
                let category = CategoryCatalog.resolve(id: id)
                Text(language.t(.weekTop, category.emoji + " " + category.name(in: language)))
            }
            if summary.noSpendDays > 0 {
                Text(language.t(.weekNoSpend, "\(summary.noSpendDays)"))
            }
            Text(language.t(.weekLogged, "\(summary.loggedDays)", "\(summary.elapsedDays)"))
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.vertical, 4)
    }

    /// Tiền của nơi chi tiêu trước, tiền khác sau, không quy đổi.
    private var spentText: String {
        let order = [primary] + Currency.allCases.filter { $0 != primary }
        let parts = order.compactMap { currency -> String? in
            guard let sum = summary.spent[currency], sum > 0 else { return nil }
            return MoneyFormatter.compact(sum, currency: currency, language: language)
        }
        return parts.isEmpty ? MoneyFormatter.compact(0, currency: primary, language: language) : parts.joined(separator: " · ")
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
        .contentShape(Rectangle())
    }
}
