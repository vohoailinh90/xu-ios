import SwiftUI
import SwiftData
import XuCore

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TransactionRecord.occurredAt, order: .reverse) private var records: [TransactionRecord]
    @Query(sort: \QuickChip.sortOrder) private var chips: [QuickChip]
    @AppStorage("flexibleMonthlyBudget") private var flexibleBudget: Int = 0

    @State private var focusTrigger = 0
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TodayCard(records: records, flexibleBudget: Int64(flexibleBudget))
                }
                if !chips.isEmpty {
                    Section("Khoản quen") { ChipRow(chips: chips) }
                }
                ForEach(groupedByDay, id: \.day) { group in
                    Section {
                        ForEach(group.items) { TransactionRow(record: $0) }
                            .onDelete { offsets in
                                for i in offsets { try? Ledger.delete(group.items[i], in: context) }
                            }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Text(MoneyFormatter.compact(group.spent))
                        }
                    }
                }
            }
            .navigationTitle("Xu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: CSVFile(records: records), preview: SharePreview("Xu — giao dịch.csv")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
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

    private struct DayGroup { let day: DayKey; let title: String; let items: [TransactionRecord]; let spent: Int64 }

    private var groupedByDay: [DayGroup] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: records) { DayKey($0.occurredAt, calendar: cal) }
        return groups.keys.sorted(by: >).map { day in
            let items = groups[day] ?? []
            let date = day.date(in: cal)
            let title = cal.isDateInToday(date) ? "Hôm nay"
                : cal.isDateInYesterday(date) ? "Hôm qua"
                : date.formatted(.dateTime.weekday(.wide).day().month())
            let spent = items.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
            return DayGroup(day: day, title: title, items: items, spent: spent)
        }
    }
}

// MARK: - Thẻ "Hôm nay"

private struct TodayCard: View {
    let records: [TransactionRecord]
    let flexibleBudget: Int64

    var body: some View {
        let cal = Calendar.current
        let today = DayKey(Date(), calendar: cal)
        let expenses = records.filter { !$0.isIncome }
        let spentToday = expenses.filter { cal.isDateInToday($0.occurredAt) }.reduce(0) { $0 + $1.amount }

        VStack(alignment: .leading, spacing: 8) {
            Text("Hôm nay đã tiêu").font(.subheadline).foregroundStyle(.secondary)
            Text(MoneyFormatter.full(spentToday)).font(.largeTitle.bold()).contentTransition(.numericText())

            if flexibleBudget > 0 {
                let safe = safeToSpend(expenses: expenses, today: today, calendar: cal)
                // Không dùng màu đỏ trừng phạt — xem docs/05-thoi-quen-tai-chinh.md
                if safe.isOverToday, let adjusted = safe.adjustedAllowanceForComingDays {
                    Text("Hôm nay hơi quá tay một chút. Những ngày tới mỗi ngày khoảng \(MoneyFormatter.compact(adjusted)) là cân lại được 🌱")
                        .font(.callout)
                } else {
                    Text("Còn được tiêu hôm nay: **\(MoneyFormatter.compact(safe.remainingToday))**")
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
    @State private var taps = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(chips) { chip in
                    Button {
                        try? Ledger.save(chip: chip, in: context)
                        taps += 1
                    } label: {
                        Text("\(chip.emoji) \(chip.title) \(MoneyFormatter.compact(chip.amount))")
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

    var body: some View {
        HStack {
            Text(record.category.emoji).font(.title3)
            VStack(alignment: .leading) {
                Text(record.note.isEmpty ? record.category.name : record.note)
                Text(record.category.name).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text((record.isIncome ? "+" : "") + MoneyFormatter.full(record.amount))
                .monospacedDigit()
                .foregroundStyle(record.isIncome ? .green : .primary)
        }
    }
}
