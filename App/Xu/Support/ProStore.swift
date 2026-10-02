import Foundation
import Observation
import StoreKit
import WidgetKit

/// Xu Pro: một sản phẩm non-consumable mua một lần qua StoreKit 2 (docs/03, docs/07), không cần máy chủ.
/// Giá luôn lấy từ App Store (`Product.displayPrice`), không ghi cứng trong app.
@MainActor
@Observable
final class ProStore {
    static let shared = ProStore()

    /// Phải trùng với sản phẩm non-consumable tạo trong App Store Connect — cần kiểm tra khi đổi bundle ID.
    static let productID = "com.example.xu.pro"

    private(set) var product: Product?
    private(set) var isPro: Bool = AppSettings.isPro
    private(set) var loadFailed = false
    private(set) var isWorking = false
    /// Kết quả của lần mua/khôi phục gần nhất cần báo cho người dùng (nil = không có gì để báo).
    private(set) var notice: Notice?

    enum Notice: Equatable {
        /// Mạng, App Store lỗi hoặc giao dịch không xác minh được: chưa mua, thử lại được.
        case purchaseFailed
        /// Đang chờ duyệt (Hỏi mua, xác minh thanh toán). Duyệt xong `Transaction.updates` sẽ tự mở khoá.
        case purchasePending
        case restoreFailed
        /// Khôi phục xong nhưng tài khoản Apple này chưa mua Xu Pro.
        case nothingToRestore
    }

    @ObservationIgnored private var updates: Task<Void, Never>?

    private init() {}

    /// Gọi một lần khi mở app: nghe giao dịch mới (mua trên máy khác, hoàn tiền…), cập nhật quyền và tải giá.
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        Task {
            await refreshEntitlement()
            await loadProduct()
        }
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
            loadFailed = product == nil
        } catch {
            loadFailed = true
        }
    }

    func purchase() async {
        guard let product, !isWorking else { return }
        isWorking = true
        notice = nil
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlement()
            case .success(.unverified):
                notice = .purchaseFailed
            case .pending:
                notice = .purchasePending
            case .userCancelled:
                break
            @unknown default:
                notice = .purchaseFailed
            }
        } catch StoreKitError.userCancelled {
            // Người dùng tự huỷ: không có gì để báo.
        } catch {
            notice = .purchaseFailed
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        notice = nil
        defer { isWorking = false }
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return
        } catch {
            notice = .restoreFailed
            return
        }
        let unverified = await refreshEntitlement()
        // Có giao dịch nhưng không xác minh được là lỗi, không phải "chưa mua".
        if !isPro { notice = unverified ? .restoreFailed : .nothingToRestore }
    }

    /// Mở paywall thì bỏ các kết quả đã xong của lần trước, để không thấy kết quả cũ. Giữ "đang chờ duyệt": giao dịch
    /// vẫn chờ thật, tới khi được duyệt (`refreshEntitlement` xoá) hoặc người dùng mua lại.
    func clearStaleNotice() {
        if notice != .purchasePending { notice = nil }
    }

    /// Đọc lại quyền Xu Pro từ StoreKit. Trả về `true` nếu có giao dịch Xu Pro không xác minh được, để báo lỗi
    /// thay vì nói người dùng chưa mua.
    @discardableResult
    func refreshEntitlement() async -> Bool {
        var owned = false
        var unverified = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                owned = true
            } else if case .unverified(let transaction, _) = result, transaction.productID == Self.productID {
                unverified = true
            }
        }
        isPro = owned
        // Đã mở khoá (kể cả giao dịch chờ duyệt vừa được duyệt qua Transaction.updates): thôi báo lỗi hay "đang chờ".
        if owned { notice = nil }
        if AppSettings.isPro != owned {
            AppSettings.isPro = owned
            WidgetCenter.shared.reloadAllTimelines()
        }
        return unverified
    }
}
