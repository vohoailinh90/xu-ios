import Foundation
import XuCore

/// Cài đặt mà app, widget và App Intents cùng đọc: ngôn ngữ giao diện và nơi chi tiêu.
/// Nằm trong UserDefaults của App Group vì widget chạy ở tiến trình riêng.
enum AppSettings {
    static let defaults: UserDefaults = UserDefaults(suiteName: SharedStore.appGroupID) ?? .standard

    enum Key {
        static let language = "appLanguage"
        static let market = "market"
    }

    static var language: AppLanguage {
        defaults.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:))
            ?? AppLanguage.preferred(from: Locale.preferredLanguages)
    }

    static var market: Market {
        defaults.string(forKey: Key.market).flatMap(Market.init(rawValue:))
            ?? Market.guess(regionCode: Locale.current.region?.identifier)
    }

    /// Lần mở đầu tiên: ghi lại giá trị đoán từ máy, để app và widget luôn thấy cùng một lựa chọn.
    static func registerDefaults() {
        if defaults.string(forKey: Key.language) == nil { defaults.set(language.rawValue, forKey: Key.language) }
        if defaults.string(forKey: Key.market) == nil { defaults.set(market.rawValue, forKey: Key.market) }
    }
}
