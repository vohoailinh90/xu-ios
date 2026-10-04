import SwiftUI
import XuCore

/// Thẻ trên Home: có khoản Apple Pay chưa được tự ghi vì bản Free hết lượt trong tháng (docs/02). Không phải đường ghi, và nằm sau khoá Face ID
/// như các thẻ xem khác (có số tiền).
struct PendingPaymentsCard: View {
    let count: Int
    let language: AppLanguage
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.t(.pendingPaymentsCard, "\(count)")).font(.headline)
            Button(language.t(.pendingPaymentsOpen), action: onOpen).buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }
}

/// Các khoản Apple Pay Xu không tự ghi vì hết lượt miễn phí, giữ trên máy (`PendingPayments`) để người dùng tự ghi sau.
/// Danh sách chỉ để **xem**: người dùng ghi tay như thường ở ô ghi, rồi bỏ khỏi danh sách. Không có nút ghi một chạm (chủ dự án bỏ nút đó
/// ngày 2026-10-04, docs/02: nó làm bản Free ghi được mọi khoản Apple Pay bằng một chạm, Xu Pro bớt lý do để mua).
/// Xoá chỉ đụng khoá của đúng khoản đó (`AppSettings`), nên tác vụ nền thêm khoản lúc danh sách đang mở không bị đè.
struct PendingPaymentsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    /// Đổi mỗi khi danh sách đổi (kể cả do tác vụ nền thêm khoản): danh sách đọc lại.
    @AppStorage(AppSettings.Key.pendingPaymentsRevision, store: AppSettings.defaults) private var revision = ""

    private var currentPending: PendingPayments {
        _ = revision   // phụ thuộc rõ vào mã đổi, để danh sách đọc lại khi có thay đổi
        return AppSettings.pendingPayments
    }

    var body: some View {
        let pending = currentPending
        NavigationStack {
            List {
                Section {
                    Text(language.t(.pendingPaymentsIntro)).font(.callout).foregroundStyle(.secondary)
                }
                if pending.isEmpty {
                    Section {
                        Text(language.t(.pendingEmpty)).foregroundStyle(.secondary)
                    }
                }
                ForEach(pending.items) { item in
                    Section {
                        row(item)
                    }
                }
            }
            .navigationTitle(language.t(.pendingPaymentsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.t(.done)) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: PendingPayment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(MoneyFormatter.full(item.amount, currency: Currency(code: item.currencyCode), language: language))
                .font(.headline)
                .monospacedDigit()
            if !item.merchant.isEmpty { Text(item.merchant) }
            Text(item.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(language.t(.pendingDismiss)) { AppSettings.removePendingPayment(item) }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
