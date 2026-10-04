import Foundation
import XuCore

/// Cài đặt mà app, widget và App Intents cùng đọc: ngôn ngữ giao diện và nơi chi tiêu.
/// Nằm trong UserDefaults của App Group vì widget chạy ở tiến trình riêng.
enum AppSettings {
    static let defaults: UserDefaults = UserDefaults(suiteName: SharedStore.appGroupID) ?? .standard

    enum Key {
        static let language = "appLanguage"
        static let market = "market"
        static let reminderEnabled = "reminderEnabled"
        /// Phút trong ngày, mặc định 21:00 (docs/05).
        static let reminderMinutes = "reminderMinutes"
        /// Đổi giá trị này (thời điểm) để Home focus ô nhập, ví dụ khi chạm "Ghi thêm" trên thông báo.
        static let focusRequest = "focusRequest"
        /// Người dùng đã tự thêm/sửa/xoá/sắp xếp khoản quen: không bao giờ tự đặt lại khoản quen mặc định nữa.
        static let chipsCustomized = "chipsCustomized"
        /// `EntryTimingLog` dạng JSON — thời gian ghi, chỉ trên máy.
        static let entryTimings = "entryTimings"
        /// Bản sao trạng thái Xu Pro cho widget (tiến trình riêng). Nguồn thật là StoreKit, `ProStore` cập nhật lại mỗi lần mở app.
        static let isPro = "isPro"
        /// Lúc bắt đầu chờ duyệt giao dịch Xu Pro (Hỏi mua…), để mở lại app vẫn báo "đang chờ duyệt".
        static let proPendingSince = "proPendingSince"
        /// Lời mời Pro (docs/07): ngày thẻ hiện lần đầu (`DayKey`, "" = chưa) và đã chạm "Để sau"/"Xem Xu Pro" chưa.
        static let proInviteDay = "proInviteDay"
        static let proInviteDismissed = "proInviteDismissed"
        /// Đã hỏi đánh giá App Store sau lần chốt ngày thứ 5 (docs/07), để chỉ hỏi một lần.
        static let reviewRequested = "reviewRequested"
        /// Khoá Face ID che phần xem (docs/02, S4). Tắt sẵn; ô ghi không bao giờ bị khoá.
        static let faceIDLock = "faceIDLock"
        /// `MonthlyQuota` dạng JSON — số ảnh biên lai đã đọc trong tháng (bản Free, docs/02), chỉ trên máy.
        static let receiptQuota = "receiptQuota"
        /// `MonthlyQuota` dạng JSON — số khoản Apple Pay đã tự ghi trong tháng (bản Free, docs/02), chỉ trên máy.
        static let applePayQuota = "applePayQuota"
        /// Mã ngẫu nhiên đổi mỗi khi danh sách khoản Apple Pay chờ ghi đổi (thêm/xoá), để thẻ ở Home và danh sách đang mở đọc lại. Không chứa dữ liệu
        /// người dùng; chính các khoản nằm ở khoá riêng của từng khoản (`PendingPayment.storageKey`).
        static let pendingPaymentsRevision = "pendingPaymentsRevision"
    }

    static let defaultReminderMinutes = 21 * 60

    static var reminderMinutes: Int {
        defaults.object(forKey: Key.reminderMinutes) as? Int ?? defaultReminderMinutes
    }

    static var chipsCustomized: Bool {
        get { defaults.bool(forKey: Key.chipsCustomized) }
        set { defaults.set(newValue, forKey: Key.chipsCustomized) }
    }

    static var entryTimings: EntryTimingLog {
        get {
            defaults.data(forKey: Key.entryTimings)
                .flatMap { try? JSONDecoder().decode(EntryTimingLog.self, from: $0) } ?? EntryTimingLog()
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.entryTimings) }
    }

    static var receiptQuota: MonthlyQuota? {
        get { defaults.data(forKey: Key.receiptQuota).flatMap { try? JSONDecoder().decode(MonthlyQuota.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.receiptQuota) }
    }

    static var applePayQuota: MonthlyQuota? {
        get { defaults.data(forKey: Key.applePayQuota).flatMap { try? JSONDecoder().decode(MonthlyQuota.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.applePayQuota) }
    }

    /// Khoản Apple Pay chưa được tự ghi vì bản Free hết lượt, giữ để người dùng ghi sau (docs/02), chỉ trên máy. Mỗi khoản một khoá theo `id`:
    /// thêm và xoá chỉ đụng đúng khoản đó, nên tác vụ nền (thêm) và danh sách trong app (xoá) chạy cùng lúc không đè nhau. Đọc cả khối rồi ghi
    /// lại cả khối thì có.
    static var pendingPayments: PendingPayments { PendingPayments(storedValues: defaults.dictionaryRepresentation()) }

    static func addPendingPayment(_ payment: PendingPayment) throws {
        let data = try payment.encoded()
        defaults.set(data, forKey: payment.storageKey)
        notifyPendingPaymentsChanged()
    }

    static func removePendingPayment(_ payment: PendingPayment) {
        defaults.removeObject(forKey: payment.storageKey)
        notifyPendingPaymentsChanged()
    }

    /// Ghi mù một mã mới, không đọc giá trị cũ, nên không có đọc-sửa-ghi.
    private static func notifyPendingPaymentsChanged() {
        defaults.set(UUID().uuidString, forKey: Key.pendingPaymentsRevision)
    }

    static var faceIDLockEnabled: Bool { defaults.bool(forKey: Key.faceIDLock) }

    static var isPro: Bool {
        get { defaults.bool(forKey: Key.isPro) }
        set { defaults.set(newValue, forKey: Key.isPro) }
    }

    static var proPendingSince: Date? {
        get { (defaults.object(forKey: Key.proPendingSince) as? Double).map(Date.init(timeIntervalSince1970:)) }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: Key.proPendingSince)
            } else {
                defaults.removeObject(forKey: Key.proPendingSince)
            }
        }
    }

    static func requestFocus() {
        defaults.set(Date().timeIntervalSince1970, forKey: Key.focusRequest)
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
