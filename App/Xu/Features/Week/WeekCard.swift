import SwiftUI
import XuCore

/// "Nhìn lại tuần" (docs/02, O3): tổng chi, danh mục nhiều nhất, ngày không tiêu vặt, số ngày có ghi chép.
/// Dùng cho thẻ trên Home (tuần này) và màn `WeekView` (mọi tuần). Chỉ kể lại, không màu đỏ (docs/05).
struct WeekCard: View {
    let summary: WeeklySummary
    let primary: Currency
    let language: AppLanguage
    /// Câu mở đầu: "Tuần này đã tiêu {0}" trên Home, "Đã tiêu {0}" khi đang xem một tuần bất kỳ.
    var spentKey: L10n = .weekSpent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(language.t(spentKey, spentText)).font(.headline)
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
