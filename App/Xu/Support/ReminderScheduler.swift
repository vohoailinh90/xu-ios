import Foundation
import UserNotifications
import XuCore

/// Nhắc "Chốt ngày" buổi tối (docs/05): thông báo cục bộ, đặt lịch trên máy, không cần mạng.
/// Hai nút: "Đã ghi đủ" chốt ngày ngay trên thông báo, "Ghi thêm" mở app vào ô nhập.
enum ReminderScheduler {
    static let categoryID = "xu.dayClose"
    static let closeDayActionID = "xu.dayClose.allLogged"
    static let logMoreActionID = "xu.dayClose.logMore"
    static let requestID = "xu.eveningReminder"

    /// Đăng ký hai nút với chữ theo ngôn ngữ hiện tại. Gọi lúc mở app và khi đổi ngôn ngữ.
    static func registerCategories(language: AppLanguage) {
        let closeDay = UNNotificationAction(identifier: closeDayActionID, title: language.t(.actionAllLogged), options: [])
        let logMore = UNNotificationAction(identifier: logMoreActionID, title: language.t(.actionLogMore), options: [.foreground])
        let category = UNNotificationCategory(identifier: categoryID, actions: [closeDay, logMore],
                                              intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Bật nhắc: xin quyền (chỉ hỏi lần đầu) rồi đặt lịch. Trả về `false` nếu người dùng không cho phép.
    static func enable(minutes: Int, language: AppLanguage) async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        schedule(minutes: minutes, language: language)
        return true
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestID])
    }

    /// Đổi ngôn ngữ hoặc giờ nhắc: đặt lại lịch để chữ trên thông báo và giờ khớp cài đặt.
    static func refresh() {
        let language = AppSettings.language
        registerCategories(language: language)
        guard AppSettings.defaults.bool(forKey: AppSettings.Key.reminderEnabled) else { return }
        schedule(minutes: AppSettings.reminderMinutes, language: language)
    }

    private static func schedule(minutes: Int, language: AppLanguage) {
        registerCategories(language: language)
        let content = UNMutableNotificationContent()
        content.title = language.t(.reminderTitle)
        content.body = language.t(.reminderBody)
        content.categoryIdentifier = categoryID
        content.sound = .default
        var time = DateComponents()
        time.hour = minutes / 60
        time.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        // Cùng requestID nên lịch mới thay lịch cũ.
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))
    }
}
