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
    /// Các ngày Xu đã đặt thông báo và chưa tự huỷ. Ngày nào trong đây mà không còn trong danh sách chờ
    /// của iOS là đã gửi — đúng ở mọi múi giờ, khác với so giờ tuyệt đối (trigger chạy theo giờ địa phương).
    private static let scheduledKey = "reminderScheduledDays"
    /// Các ngày đã nhắc rồi: đổi giờ nhắc hay tắt/bật lại trong ngày cũng không nhắc lần nữa.
    private static let remindedKey = "reminderRemindedDays"

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
        let pending = Set(ours)

        let previouslyScheduled = defaults.stringArray(forKey: scheduledKey) ?? []
        var reminded = Set(defaults.stringArray(forKey: remindedKey) ?? [])
        // Thông báo của hôm nay (hay trước đó) không còn chờ là iOS đã gửi. Ngày mai trở đi thì chưa thể gửi —
        // nếu mất (ví dụ khôi phục sang máy mới) thì cứ đặt lại.
        for day in previouslyScheduled where !pending.contains(requestPrefix + day)
            && (DayKey(day).map { $0 <= today } ?? false) {
            reminded.insert(day)
        }
        reminded = reminded.filter { DayKey($0).map { $0 >= today } ?? false }
        var scheduled: [String] = []
        defer {
            defaults.set(scheduled, forKey: scheduledKey)
            defaults.set(Array(reminded), forKey: remindedKey)
        }

        guard defaults.bool(forKey: AppSettings.Key.reminderEnabled) else {
            center.removePendingNotificationRequests(withIdentifiers: ours)
            return
        }
        let planned = upcoming(minutes: AppSettings.reminderMinutes, language: language, now: now, today: today,
                               skipping: Set(reminded.compactMap { DayKey($0) }), calendar: calendar)
        let keep = Set(planned.map { $0.request.identifier })
        center.removePendingNotificationRequests(withIdentifiers: ours.filter { !keep.contains($0) })
        // Cùng mã thì lịch mới thay lịch cũ (giờ hoặc chữ đã đổi).
        for item in planned {
            // Chỉ ghi nhận ngày đặt được thật, để lần sau không tưởng nhầm là đã gửi.
            guard (try? await center.add(item.request)) != nil else { continue }
            scheduled.append(item.day.description)
        }
    }

    /// Thông báo cho hôm nay (nếu chưa qua giờ nhắc và chưa nhắc) và các ngày tới. Giờ không gắn múi giờ:
    /// 21:00 là 21:00 ở nơi người dùng đang ở. Thành phần ngày lấy theo lịch của máy, kèm niên hiệu,
    /// để máy đặt lịch Nhật vẫn hiểu đúng năm.
    private static func upcoming(minutes: Int, language: AppLanguage, now: Date, today: DayKey, skipping reminded: Set<DayKey>,
                                 calendar: Calendar) -> [(day: DayKey, request: UNNotificationRequest)] {
        (0..<daysAhead).compactMap { offset -> (day: DayKey, request: UNNotificationRequest)? in
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
            return (day, request)
        }
    }
}
