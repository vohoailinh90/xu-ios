import Foundation
import UserNotifications
import XuCore

/// Nhắc "Chốt ngày" buổi tối (docs/05): thông báo cục bộ, đặt lịch trên máy, không cần mạng.
/// Hai nút: "Đã ghi đủ" chốt ngày ngay trên thông báo, "Ghi thêm" mở app vào ô nhập.
///
/// Mỗi ngày một thông báo riêng (đặt trước `daysAhead` ngày, nạp thêm mỗi lần mở app), mang theo ngày
/// nó nhắc trong `userInfo`. Nhờ vậy "Đã ghi đủ" luôn chốt đúng ngày đó, kể cả khi người dùng bấm sau
/// nửa đêm hay đã bay sang múi giờ khác. Không mở app hơn hai tuần thì Xu thôi nhắc (không làm phiền).
enum ReminderScheduler {
    static let categoryID = "xu.dayClose"
    static let closeDayActionID = "xu.dayClose.allLogged"
    static let logMoreActionID = "xu.dayClose.logMore"
    /// Khoá trong `userInfo`, giá trị là `DayKey.description` ("2026-10-01").
    static let dayInfoKey = "day"
    static let requestPrefix = "xu.eveningReminder."
    /// Bản đầu dùng một thông báo lặp lại với mã này; dọn đi khi đặt lịch mới.
    static let legacyRequestID = "xu.eveningReminder"
    static let daysAhead = 14
    /// Ngày → thời điểm nhắc đã đặt (giây từ 1970). Lần nào đã tới giờ là đã gửi: đổi giờ nhắc
    /// trong cùng ngày không được nhắc lần nữa (thông báo đã gửi không còn trong danh sách chờ).
    private static let firedKey = "reminderFireTimes"

    /// Đăng ký hai nút với chữ theo ngôn ngữ hiện tại. Gọi lúc mở app và khi đổi ngôn ngữ.
    static func registerCategories(language: AppLanguage) {
        let closeDay = UNNotificationAction(identifier: closeDayActionID, title: language.t(.actionAllLogged), options: [])
        let logMore = UNNotificationAction(identifier: logMoreActionID, title: language.t(.actionLogMore), options: [.foreground])
        let category = UNNotificationCategory(identifier: categoryID, actions: [closeDay, logMore],
                                              intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Bật nhắc: xin quyền (chỉ hỏi lần đầu) rồi đặt lịch. Trả về `false` nếu người dùng không cho phép.
    @MainActor
    static func enable() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        if granted { refresh() }
        return granted
    }

    /// Đặt lại lịch cho khớp cài đặt hiện tại: bật/tắt, giờ nhắc, ngôn ngữ. Gọi khi mở app (để nạp thêm ngày),
    /// khi đổi cài đặt và sau khi chốt ngày. Các lần gọi chạy lần lượt, lần sau luôn thắng.
    @MainActor
    static func refresh() {
        let previous = pending
        pending = Task { @MainActor in
            await previous?.value
            await sync()
        }
    }

    @MainActor private static var pending: Task<Void, Never>?

    @MainActor
    private static func sync() async {
        let center = UNUserNotificationCenter.current()
        let defaults = AppSettings.defaults
        let language = AppSettings.language
        let now = Date()
        let calendar = Calendar.current
        let today = DayKey(now, calendar: calendar)
        registerCategories(language: language)
        let ours = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0 == legacyRequestID || $0.hasPrefix(requestPrefix) }

        // Chỉ giữ các lần nhắc đã tới giờ từ hôm nay trở đi; lần chưa tới giờ sẽ được đặt lại bên dưới.
        let stored = defaults.dictionary(forKey: firedKey) as? [String: Double] ?? [:]
        var fired = stored.filter { key, time in
            time <= now.timeIntervalSince1970 && (DayKey(key).map { $0 >= today } ?? false)
        }
        defer { defaults.set(fired, forKey: firedKey) }

        guard defaults.bool(forKey: AppSettings.Key.reminderEnabled) else {
            center.removePendingNotificationRequests(withIdentifiers: ours)
            return
        }
        let reminded = Set(fired.keys.compactMap { DayKey($0) })
        let planned = upcoming(minutes: AppSettings.reminderMinutes, language: language, now: now, today: today,
                               skipping: reminded, calendar: calendar)
        let keep = Set(planned.map { $0.request.identifier })
        center.removePendingNotificationRequests(withIdentifiers: ours.filter { !keep.contains($0) })
        // Cùng mã thì lịch mới thay lịch cũ (giờ hoặc chữ đã đổi).
        for item in planned {
            try? await center.add(item.request)
            fired[item.day.description] = item.fire.timeIntervalSince1970
        }
    }

    /// Thông báo cho hôm nay (nếu chưa qua giờ nhắc và chưa nhắc) và các ngày tới. Giờ không gắn múi giờ:
    /// 21:00 là 21:00 ở nơi người dùng đang ở. Thành phần ngày lấy theo lịch của máy, kèm niên hiệu,
    /// để máy đặt lịch Nhật vẫn hiểu đúng năm.
    private static func upcoming(minutes: Int, language: AppLanguage, now: Date, today: DayKey, skipping reminded: Set<DayKey>,
                                 calendar: Calendar) -> [(day: DayKey, fire: Date, request: UNNotificationRequest)] {
        (0..<daysAhead).compactMap { offset -> (day: DayKey, fire: Date, request: UNNotificationRequest)? in
            let day = today.adding(days: offset, calendar: calendar)
            guard !reminded.contains(day),
                  let fire = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0,
                                           of: day.date(in: calendar)),
                  fire > now else { return nil }
            let components = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute], from: fire)
            let content = UNMutableNotificationContent()
            content.title = language.t(.reminderTitle)
            content.body = language.t(.reminderBody)
            content.categoryIdentifier = categoryID
            content.sound = .default
            content.userInfo = [dayInfoKey: day.description]
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: requestPrefix + day.description, content: content, trigger: trigger)
            return (day, fire, request)
        }
    }
}
