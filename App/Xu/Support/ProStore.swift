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

    /// Phải trùng với sản phẩm non-consumable tạo trong App Store Connect — cần kiểm tra khi đổi bundle ID. Định nghĩa ở `ProEntitlement`
    /// (dùng chung với App Intents chạy nền, nơi không có `ProStore`).
    static let productID = ProEntitlement.productID

    private(set) var product: Product?
    private(set) var isPro: Bool = AppSettings.isPro
    private(set) var loadFailed = false
    private(set) var isWorking = false
    /// Kết quả của lần mua/khôi phục gần nhất cần báo cho người dùng (nil = không có gì để báo).
    private(set) var notice: Notice?
    /// Lúc bắt đầu chờ duyệt giao dịch mua (Hỏi mua, xác minh thanh toán); nil = không chờ. Là trạng thái, không phải
    /// kết quả một lần: lưu qua các lần mở app (`AppSettings.proPendingSince`), hết khi đã có quyền Xu Pro (duyệt xong,
    /// `Transaction.updates` báo về) — mở lại paywall hay khôi phục không xoá.
    private(set) var pendingSince: Date? = AppSettings.proPendingSince

    /// Xu không biết được yêu cầu chờ duyệt bị từ chối hay hết hạn (không có giao dịch nào báo về), nên sau bấy lâu
    /// thì thôi báo "đang chờ" để không treo mãi. Người dùng vẫn mua lại được bất cứ lúc nào.
    static let pendingNoticeLifetime: TimeInterval = 24 * 60 * 60

    /// Còn báo "đang chờ duyệt" vào lúc `now` không. Tính theo thời gian mỗi lần hỏi, nên tự hết hạn cả khi app đang mở.
    func isPurchasePending(at now: Date = Date()) -> Bool {
        guard let pendingSince else { return false }
        return now.timeIntervalSince(pendingSince) < Self.pendingNoticeLifetime
    }

    enum Notice: Equatable {
        /// Mạng, App Store lỗi hoặc giao dịch không xác minh được: chưa mua, thử lại được.
        case purchaseFailed
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
                setPurchasePending(true)
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
        // Có giao dịch nhưng không xác minh được là lỗi, không phải "chưa mua". Đang chờ duyệt thì cũng không phải
        // "chưa mua": thông báo chờ duyệt vẫn hiện.
        if !isPro, !isPurchasePending() { notice = unverified ? .restoreFailed : .nothingToRestore }
    }

    /// Mở paywall thì bỏ kết quả mua/khôi phục của lần trước, để không thấy kết quả cũ. Trạng thái chờ duyệt giữ nguyên.
    func clearNotice() {
        notice = nil
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
        if owned {
            notice = nil
            setPurchasePending(false)
        }
        if AppSettings.isPro != owned {
            AppSettings.isPro = owned
            WidgetCenter.shared.reloadAllTimelines()
        }
        return unverified
    }

    private func setPurchasePending(_ pending: Bool) {
        pendingSince = pending ? Date() : nil
        AppSettings.proPendingSince = pendingSince
    }
}
