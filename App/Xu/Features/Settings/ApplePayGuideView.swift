import SwiftUI
import XuCore

/// Hướng dẫn tạo automation "Giao dịch" trong app Phím tắt để tự ghi khi trả bằng Apple Pay (E11).
/// Xu chỉ cung cấp tác vụ `LogPaymentIntent`; người dùng tự tạo automation — iOS không cho app tự tạo.
struct ApplePayGuideView: View {
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi
    @AppStorage(AppSettings.Key.market, store: AppSettings.defaults) private var market: Market = .vietnam

    private let store = ProStore.shared

    private var steps: [L10n] { [.applePayStep1, .applePayStep2, .applePayStep3, .applePayStep4, .applePayStep5] }

    var body: some View {
        List {
            Section {
                Text(language.t(.applePayGuideIntro))
                // Nói rõ hạn mức Free ngay từ đầu (docs/02), không để người dùng bất ngờ khi hết lượt.
                if !store.isPro {
                    Text(language.t(.applePayLimitNote, "\(ProPlan.freeApplePayLogsPerMonth)"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)").font(.headline).monospacedDigit().foregroundStyle(.tint)
                        Text(language.t(step))
                    }
                }
            } footer: {
                Text(language.t(.applePayNotes, market.currency.name(in: language)))
            }
            Section {
                if let url = URL(string: "shortcuts://") {
                    Link(destination: url) {
                        Label(language.t(.openShortcuts), systemImage: "square.2.layers.3d")
                    }
                }
            }
        }
        .navigationTitle(language.t(.applePayGuideTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
