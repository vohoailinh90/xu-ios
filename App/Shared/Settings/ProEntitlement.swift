import Foundation
import StoreKit
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Quyền Xu Pro đọc thẳng từ StoreKit, cho nơi không có `ProStore` (App Intents chạy nền): bản sao `AppSettings.isPro` chỉ được cập nhật khi
/// mở app, nên có thể cũ (cài lại máy, mua trên máy khác, chưa mở app). Người dùng Xu Pro không bao giờ bị giới hạn nhầm vì bản sao cũ.
enum ProEntitlement {
    /// Phải trùng với sản phẩm non-consumable tạo trong App Store Connect — cần kiểm tra khi đổi bundle ID. `ProStore` dùng chung mã này.
    static let productID = "com.example.xu.pro"

    /// Hỏi StoreKit xem tài khoản Apple này đang có Xu Pro không, rồi cập nhật bản sao `AppSettings.isPro` nếu khác.
    /// Giao dịch không xác minh được hay đã hoàn tiền thì coi là chưa có.
    static func verifyAndCache() async -> Bool {
        var owned = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == productID, transaction.revocationDate == nil {
                owned = true
            }
        }
        if AppSettings.isPro != owned {
            AppSettings.isPro = owned
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
        return owned
    }
}
