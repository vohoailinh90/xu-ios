import UIKit
import UserNotifications
import XuCore

/// Nhận nút bấm trên thông báo "Chốt ngày", kể cả khi app đang tắt (iOS mở app chạy nền để xử lý).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ReminderScheduler.registerCategories(language: AppSettings.language)
        return true
    }

    /// App đang mở vẫn hiện thông báo, để người dùng chốt ngày được ngay.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Chốt đúng ngày của thông báo, kể cả khi người dùng bấm sau nửa đêm.
        let day = DayKey(response.notification.date, calendar: .current)
        let action = response.actionIdentifier
        Task { @MainActor in
            if action == ReminderScheduler.closeDayActionID {
                try? Ledger.setDayClosed(day, closed: true, in: SharedStore.container.mainContext)
            } else if action != UNNotificationDismissActionIdentifier {
                // "Ghi thêm" hoặc chạm vào thông báo: mở thẳng ô nhập
                AppSettings.requestFocus()
            }
            completionHandler()
        }
    }
}
