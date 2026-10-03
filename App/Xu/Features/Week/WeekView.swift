import SwiftUI
import SwiftData
import XuCore

/// Nhìn lại từng tuần (docs/02, O3). Bản Free xem tuần này; xem lại các tuần cũ là Xu Pro (bảng Free/Pro trong docs/02)
/// — chạm "tuần trước" mới mở paywall, không bao giờ lúc đang ghi. Danh sách giao dịch và CSV vẫn đủ mọi tuần cho
/// tất cả mọi người. Cùng kiểu với `MonthView`.
struct WeekView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var records: [TransactionRecord]
    @Query private var closures: [DayClosure]
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    @AppStorage(AppSettings.Key.market, store: AppSettings.defaults) private var market: Market = .vietnam
    /// Số tuần lùi lại so với tuần này (0 = tuần này).
    @State private var weeksBack = 0
    @State private var showPaywall = false
    private let store = ProStore.shared

    var body: some View {
        let calendar = Calendar.current
        let today = DayKey(Date(), calendar: calendar)
        let currentStart = WeeklySummary.weekStart(of: today, calendar: calendar)
        let start = currentStart.adding(days: -7 * weeksBack, calendar: calendar)
        let entries = records.map {
            LedgerEntry(amount: $0.amount, isIncome: $0.isIncome, categoryID: $0.categoryID,
                        day: $0.day(in: calendar), currency: $0.currency)
        }
        let closedDays = Set(closures.map(\.dayKey))
        // Tuần xa nhất có ghi chép hoặc chốt ngày: không lùi về những tuần trống trước khi dùng app.
        let loggedDays: [DayKey] = entries.map(\.day) + Array(closedDays)
        let earliestStart = loggedDays.min().map { WeeklySummary.weekStart(of: $0, calendar: calendar) } ?? currentStart
        let summary = WeeklySummary.compute(weekStarting: start, entries: entries, closedDays: closedDays,
                                            today: today, primary: market.currency, calendar: calendar)

        NavigationStack {
            List {
                Section {
                    HStack {
                        Button {
                            showPrevious(from: start, current: currentStart, calendar: calendar)
                        } label: { Image(systemName: "chevron.left") }
                            .disabled(start <= earliestStart)
                            .accessibilityLabel(language.t(.weekPrevious))
                        Spacer()
                        Text(rangeTitle(from: start, calendar: calendar)).font(.headline)
                        Spacer()
                        Button { weeksBack -= 1 } label: { Image(systemName: "chevron.right") }
                            .disabled(weeksBack == 0)
                            .accessibilityLabel(language.t(.weekNext))
                    }
                    .buttonStyle(.borderless)
                } footer: {
                    if !store.isPro && earliestStart < currentStart {
                        Text(language.t(.weekProHistory))
                    }
                }

                Section {
                    if summary.isEmpty {
                        Text(language.t(.weekEmpty)).foregroundStyle(.secondary)
                    } else {
                        WeekCard(summary: summary, primary: market.currency, language: language,
                                 spentKey: .weekRangeSpent)
                    }
                }
            }
            .navigationTitle(language.t(.weekHistoryTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(language.t(.done)) { dismiss() } }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func showPrevious(from start: DayKey, current: DayKey, calendar: Calendar) {
        let previous = start.adding(days: -7, calendar: calendar)
        if ProPlan.canViewWeek(startingOn: previous, currentWeekStart: current, isPro: store.isPro) {
            weeksBack += 1
        } else {
            showPaywall = true
        }
    }

    /// "28 thg 9 – 4 thg 10": thứ Hai tới Chủ nhật của tuần.
    private func rangeTitle(from start: DayKey, calendar: Calendar) -> String {
        let style = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(language.locale)
        let first = start.date(in: calendar).formatted(style)
        let last = start.adding(days: 6, calendar: calendar).date(in: calendar).formatted(style)
        return "\(first) – \(last)"
    }
}
