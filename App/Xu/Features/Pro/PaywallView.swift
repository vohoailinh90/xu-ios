import SwiftUI
import XuCore

/// Màn Xu Pro. Chỉ mở khi người dùng chạm vào tính năng Pro hoặc vào Cài đặt — không bao giờ lúc đang ghi (docs/07).
/// Không đếm ngược, không giảm giá giả, không làm người dùng thấy có lỗi (docs/05).
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    private let store = ProStore.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(language.t(.proTitle)).font(.largeTitle.bold())
                        Text(language.t(.proSubtitle)).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Label(language.t(.proBenefitHabits, "\(ProPlan.freeHabitLimit)"), systemImage: "leaf")
                    Label(language.t(.proBenefitWidget, "\(ProPlan.widgetChipCapacity)", "\(ProPlan.freeWidgetChipLimit)"),
                          systemImage: "square.grid.2x2")
                } footer: {
                    Text(language.t(.proAlwaysFree))
                }
                Section {
                    if store.isPro {
                        Label(language.t(.proOwned), systemImage: "checkmark.seal.fill")
                    } else if let product = store.product {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            Text(language.t(.proBuy, product.displayPrice)).frame(maxWidth: .infinity).bold()
                        }
                        .disabled(store.isWorking)
                    } else if store.loadFailed {
                        Button(language.t(.proPriceUnavailable)) { Task { await store.loadProduct() } }
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                    if !store.isPro {
                        Button(language.t(.proRestore)) { Task { await store.restore() } }
                            .disabled(store.isWorking)
                    }
                } footer: {
                    if let notice = store.notice {
                        Text(language.t(Self.text(for: notice)))
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.t(.done)) { dismiss() }
                }
            }
            .task { if store.product == nil { await store.loadProduct() } }
            .onDisappear { store.clearNotice() }
        }
    }

    private static func text(for notice: ProStore.Notice) -> L10n {
        switch notice {
        case .purchaseFailed: .proPurchaseFailed
        case .purchasePending: .proPurchasePending
        case .restoreFailed: .proRestoreFailed
        case .nothingToRestore: .proNothingToRestore
        }
    }
}
