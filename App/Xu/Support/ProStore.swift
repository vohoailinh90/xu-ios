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
        defer { isWorking = false }
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result, case .verified(let transaction) = verification {
            await transaction.finish()
            await refreshEntitlement()
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var owned = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
        if AppSettings.isPro != owned {
            AppSettings.isPro = owned
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
