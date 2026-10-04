import Foundation
import UserNotifications
import XuCore

/// Báo khi một khoản Apple Pay **không** được tự ghi vì bản Free hết lượt trong tháng (docs/02). Automation chạy nền, không có màn hình,
/// nên lời nhắn trong kết quả của tác vụ có thể không ai thấy; thông báo giúp người dùng biết sớm hơn. Đây chỉ là lớp báo thêm: khoản đã được
/// giữ trong `PendingPayments` và hiện ở Home dù người dùng có thấy thông báo hay không.
///
/// - Chỉ gửi khi người dùng **đã cho phép** thông báo (Xu không xin quyền từ đây).
/// - Tạo ngay trên máy, không qua máy chủ (docs/09). Không nêu số tiền hay người bán: thông báo hiện cả trên màn hình khoá.
/// - Chạm vào thông báo mở Xu: `AppDelegate` xử lý như mọi thông báo của Xu không phải nút "Đã ghi đủ"; thẻ khoản chưa ghi nằm ở Home.
enum ApplePayLimitNotice {
    static let requestPrefix = "xu.applePayLimit."

    static func post(language: AppLanguage) async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = language.t(.applePayLimitTitle)
        content.body = language.t(.applePayLimitBody)
        // Mã riêng cho từng lần để mỗi khoản không được ghi đều có một thông báo, không đè lên nhau.
        let request = UNNotificationRequest(identifier: requestPrefix + UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }
}
