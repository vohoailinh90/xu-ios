import SwiftUI
import XuCore

/// Quyền riêng tư nói ngắn gọn, đọc được ngay trong app, không cần mạng (docs/09).
/// Bản đầy đủ để đăng lên App Store Connect: docs/privacy-policy.md — sửa một bên thì sửa cả bên kia.
struct PrivacyView: View {
    @AppStorage(AppSettings.Key.language, store: AppSettings.defaults) private var language: AppLanguage = .vi

    private let rows: [L10n] = [
        .privacyOnDevice, .privacyNoTracking, .privacyPurchases, .privacyShortcuts,
        .privacyNotifications, .privacyExport, .privacyDelete,
    ]

    private func icon(for key: L10n) -> String {
        switch key {
        case .privacyOnDevice: "iphone"
        case .privacyNoTracking: "eye.slash"
        case .privacyPurchases: "creditcard"
        case .privacyShortcuts: "square.2.layers.3d"
        case .privacyNotifications: "bell"
        case .privacyExport: "square.and.arrow.up"
        default: "trash"
        }
    }

    var body: some View {
        List {
            Section {
                Text(language.t(.privacyHeadline)).font(.headline)
            }
            Section {
                ForEach(rows, id: \.self) { key in
                    Label {
                        Text(language.t(key))
                    } icon: {
                        Image(systemName: icon(for: key)).foregroundStyle(.tint)
                    }
                }
            } footer: {
                Text(language.t(.privacyUpdated))
            }
        }
        .navigationTitle(language.t(.privacyTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
