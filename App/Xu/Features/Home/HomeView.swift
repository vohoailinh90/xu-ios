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
    @AppStorage(AppSettings.Key.proInviteDay, store: AppSettings.defaults) private var proInviteDay = ""
    @AppStorage(AppSettings.Key.proInviteDismissed, store: AppSettings.defaults) private var proInviteDismissed = false

    private let lock = AppLock.shared

    @State private var focusTrigger = 0
    @State private var showSettings = false
    @State private var showHabits = false
    @State private var showChips = false
    @State private var showMonth = false
    @State private var showWeek = false
    /// Tệp CSV đang chia sẻ; đóng ngay khi khoá Face ID.
    @State private var exportFile: ExportFile?
    @State private var editing: TransactionRecord?
    @State private var showPaywall = false
    /// Ô nhập nhanh còn chữ chưa lưu.
    @State private var hasDraft = false

    var body: some View {
        NavigationStack {
            List {
                // Khoá Face ID (nếu bật) chỉ thay các mục XEM bằng ổ khoá. Khoản quen (đường ghi một chạm) và ô ghi
                // (`QuickEntryBar`, bên dưới) không bao giờ bị che.
                let covered = lock.isCovered
                Section {
                    if covered {
                        FaceIDLockedContent().frame(maxWidth: .infinity).padding(.vertical, 8)
                    } else {
                        TodayCard(records: records,
                                  flexibleBudget: Int64(market == .japan ? budgetJapan : budgetVietnam),
                                  currency: market.currency, language: language)
                    }
                }
                if showProInvite {
                    Section {
                        ProInviteCard(language: language) {
                            proInviteDismissed = true
                            showPaywall = true
                        } onLater: {
                            proInviteDismissed = true
                        }
                        .onAppear {
                            // Ghi ngày hiện lần đầu: thẻ ở lại hết hôm nay, sang ngày khác là thôi (chỉ mời một lần).
                            if proInviteDay.isEmpty { proInviteDay = DayKey(Date(), calendar: .current).description }
                        }
                    }
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
                if !covered {
                    let week = weeklySummary
                    // Tuần này còn trống mà đã có tuần cũ (ví dụ sáng thứ Hai): vẫn có đường vào các tuần trước.
                    let hasEarlierWeeks = hasHistory(before: week.weekStart)
                    if !week.isEmpty || hasEarlierWeeks {
                        Section {
                            if !week.isEmpty {
                                WeekCard(summary: week, primary: market.currency, language: language)
                            }
                            if hasEarlierWeeks {
                                Button { showWeek = true } label: {
                                    Label(language.t(.weekEarlier), systemImage: "calendar")
                                }
                            }
                        } header: {
                            if !week.isEmpty { Text(language.t(.weekTitle)) }
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
            }
            .navigationTitle("Xu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { exportCSV() } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel(language.t(.exportCSV))
                        .disabled(lock.isCovered)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHabits = true } label: { Image(systemName: "leaf") }
                        .accessibilityLabel(language.t(.habitsTitle))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showMonth = true } label: { Image(systemName: "chart.bar.xaxis") }
                        .accessibilityLabel(language.t(.monthTitle))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(language.t(.settings))
                }
            }
            .safeAreaInset(edge: .bottom) {
                QuickEntryBar(focusTrigger: focusTrigger, hasDraft: $hasDraft)
            }
            .sheet(isPresented: $showSettings) { SettingsView().faceIDGate() }
            .sheet(isPresented: $showHabits) { HabitsView(canAskForReview: !hasDraft).faceIDGate() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showMonth) { MonthView().faceIDGate() }
            .sheet(isPresented: $showWeek) { WeekView().faceIDGate() }
            .sheet(isPresented: $showChips) {
                NavigationStack {
                    QuickChipsManager()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(language.t(.done)) { showChips = false }
                            }
                        }
                }
                .faceIDGate()
            }
            .fullScreenCover(isPresented: showOnboarding) {
                OnboardingView {
                    hasOnboarded = true
                    focusTrigger += 1
                }
            }
            .sheet(item: $editing) { TransactionEditor(record: $0).faceIDGate() }
            .sheet(item: $exportFile) { file in
                ActivityView(url: file.url) { exportFile = nil }
                    .presentationDetents([.medium, .large])
                    .onDisappear { try? FileManager.default.removeItem(at: file.url) }
            }
        }
        // Widget (`xu://new`) và "Ghi thêm" trên thông báo chốt ngày cùng một đường: đường ghi không bao giờ bị che.
        .onOpenURL { url in
            if url.host == "new" { startLogging() }
        }
        .onChange(of: focusRequest) { startLogging() }
        // Vừa khoá (xuống nền): đóng mọi sheet xem dữ liệu, kể cả bảng chia sẻ CSV và sheet con của chúng.
        .onChange(of: lock.isLocked) {
            if lock.isLocked { closeViewingSheets() }
        }
    }

    /// Đóng mọi sheet đang che ô nhập (cả paywall) rồi focus.
    private func startLogging() {
        closeViewingSheets()
        showPaywall = false
        focusTrigger += 1
    }

    /// Đóng các sheet xem dữ liệu. Sheet con (ví dụ sửa khoản quen) đóng cùng sheet cha. Thêm sheet xem dữ liệu mới
    /// thì phải thêm vào đây.
    private func closeViewingSheets() {
        showSettings = false
        showHabits = false
        editing = nil
        showChips = false
        showMonth = false
        showWeek = false
        exportFile = nil
    }

    /// Xuất CSV: ghi tệp tạm rồi mở bảng chia sẻ. Đang khoá thì không xuất; mở khoá một chạm là xuất được.
    private func exportCSV() {
        guard !lock.isCovered,
              let url = try? CSVFile(records: records, language: language).writeToTemporaryFile() else { return }
        exportFile = ExportFile(url: url)
    }

    /// Onboarding chỉ hiện lần mở đầu; xong hoặc bỏ qua thì không hiện lại.
    private var showOnboarding: Binding<Bool> {
        Binding(get: { !hasOnboarded }, set: { if !$0 { hasOnboarded = true } })
    }

    /// Lời mời Pro một lần sau 7 ngày ghi liền (docs/07). Chỉ xét các ngày trước hôm nay, nên ghi thêm hôm nay
    /// không làm thẻ bật ra giữa lúc đang ghi.
    private var showProInvite: Bool {
        let cal = Calendar.current
        return ProInvite.isVisible(
            usedDays: Set(records.map { $0.day(in: cal) }).union(closures.map(\.dayKey)),
            today: DayKey(Date(), calendar: cal), shownOn: DayKey(proInviteDay), dismissed: proInviteDismissed,
            isPro: ProStore.shared.isPro, calendar: cal)
    }

    private var weeklySummary: WeeklySummary {
        let cal = Calendar.current
        let entries = records.map {
            LedgerEntry(amount: $0.amount, isIncome: $0.isIncome, categoryID: $0.categoryID,
                        day: $0.day(in: cal), currency: $0.currency)
        }
        return WeeklySummary.compute(entries: entries, closedDays: Set(closures.map(\.dayKey)),
                                     today: DayKey(Date(), calendar: cal), primary: market.currency, calendar: cal)
    }

    /// Có ghi chép hoặc ngày đã chốt từ trước ngày `day` không. Tuần chỉ có ngày chốt cũng là lịch sử (`WeekView`).
    private func hasHistory(before day: DayKey) -> Bool {
        let cal = Calendar.current
        return records.contains { $0.day(in: cal) < day } || closures.contains { $0.dayKey < day }
    }

    private struct DayGroup { let day: DayKey; let title: String; let items: [TransactionRecord]; let spent: String }

    private var groupedByDay: [DayGroup] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: records) { $0.day(in: cal) }
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
        let spentToday = expenses.filter { $0.day(in: cal) == today }.reduce(0) { $0 + $1.amount }
        let otherToday = records.filter { $0.currency != currency && $0.day(in: cal) == today }

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
            let day = r.day(in: calendar)
            guard day.year == today.year, day.month == today.month else { continue }
            if day == today { todaySum += r.amount } else if day < today { before += r.amount }
        }
        return SafeToSpend.compute(flexibleBudget: flexibleBudget, spentBeforeToday: before, spentToday: todaySum,
                                   today: today, periodEnd: SafeToSpend.endOfMonth(containing: today, calendar: calendar),
                                   calendar: calendar)
    }
}

// MARK: - Lời mời Pro

private struct ProInviteCard: View {
    let language: AppLanguage
    let onOpen: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.t(.proInviteTitle, "\(ProInvite.streakDays)")).font(.headline)
            Text(language.t(.proInviteBody)).font(.callout).foregroundStyle(.secondary)
            HStack {
                Button(language.t(.proInviteOpen), action: onOpen).buttonStyle(.borderedProminent)
                Button(language.t(.proInviteLater), action: onLater).buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
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
