import SwiftUI
import SwiftData
import Charts
import XuCore

/// Chi tiêu theo danh mục trong một tháng (docs/02, O4). Chỉ kể lại: không màu đỏ, không "vượt ngân sách" (docs/05).
/// Bản Free xem tháng này; xem lại các tháng trước là Xu Pro (bảng Free/Pro trong docs/02) — chạm "tháng trước" mới
/// mở paywall. Danh sách giao dịch và CSV vẫn đủ mọi tháng cho tất cả mọi người.
struct MonthView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var records: [TransactionRecord]
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    @AppStorage(AppSettings.Key.market, store: AppSettings.defaults) private var market: Market = .vietnam
    @State private var month = MonthKey(DayKey(Date(), calendar: .current))
    @State private var showPaywall = false
    private let store = ProStore.shared

    var body: some View {
        let calendar = Calendar.current
        let current = MonthKey(DayKey(Date(), calendar: calendar))
        let entries = records.map {
            LedgerEntry(amount: $0.amount, isIncome: $0.isIncome, categoryID: $0.categoryID,
                        day: $0.day(in: calendar), currency: $0.currency)
        }
        // Tháng xa nhất có ghi chép: không lùi về những tháng trống trước khi dùng app.
        let earliest = entries.map(\.day).min().map { MonthKey($0) } ?? current
        let summary = MonthlySummary.compute(entries: entries, month: month, primary: market.currency)

        NavigationStack {
            List {
                Section {
                    HStack {
                        Button { showPrevious(current: current) } label: { Image(systemName: "chevron.left") }
                            .disabled(month <= earliest)
                            .accessibilityLabel(language.t(.monthPrevious))
                        Spacer()
                        Text(title(of: month, calendar: calendar)).font(.headline)
                        Spacer()
                        Button { month = month.adding(months: 1) } label: { Image(systemName: "chevron.right") }
                            .disabled(month >= current)
                            .accessibilityLabel(language.t(.monthNext))
                    }
                    .buttonStyle(.borderless)
                } footer: {
                    if !store.isPro && earliest < current {
                        Text(language.t(.monthProHistory))
                    }
                }

                Section {
                    if summary.isEmpty {
                        Text(language.t(.monthEmpty)).foregroundStyle(.secondary)
                    } else {
                        Text(language.t(.monthSpent, SpendingSummary.text(for: summary.spent, primary: market.currency,
                                                                         language: language)))
                            .font(.headline)
                        if !summary.byCategory.isEmpty {
                            CategoryChart(slices: summary.byCategory, currency: market.currency, language: language)
                        }
                    }
                }
            }
            .navigationTitle(language.t(.monthTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(language.t(.done)) { dismiss() } }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func showPrevious(current: MonthKey) {
        let previous = month.adding(months: -1)
        if ProPlan.canViewMonth(previous, current: current, isPro: store.isPro) {
            month = previous
        } else {
            showPaywall = true
        }
    }

    private func title(of month: MonthKey, calendar: Calendar) -> String {
        DayKey(year: month.year, month: month.month, day: 1).date(in: calendar)
            .formatted(.dateTime.month(.wide).year().locale(language.locale))
    }
}

/// Thanh ngang theo danh mục, nhiều nhất ở trên. Màu nhấn của app, không bao giờ đỏ (docs/05).
private struct CategoryChart: View {
    let slices: [MonthlySummary.Slice]
    let currency: Currency
    let language: AppLanguage

    var body: some View {
        Chart(slices, id: \.categoryID) { slice in
            let category = CategoryCatalog.resolve(id: slice.categoryID)
            // Nhãn trục theo ngôn ngữ đang chọn: VoiceOver và biểu đồ trợ năng đọc chúng.
            BarMark(x: .value(language.t(.amountField), Double(slice.amount)),
                    y: .value(language.t(.categoryField), category.emoji + " " + category.name(in: language)))
                .foregroundStyle(.tint)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(MoneyFormatter.compact(slice.amount, currency: currency, language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(slices.count) * 34 + 8)
        .padding(.vertical, 4)
    }
}
