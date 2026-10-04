import Foundation

/// Một khoản Apple Pay mà Xu **không** tự ghi vì bản Free hết lượt trong tháng (docs/02). Giữ trên máy để người dùng ghi sau, nên khoản không bị
/// bỏ mất mà không ai biết (automation chạy nền, lời nhắn và thông báo không được bảo đảm hiện). Chỉ nằm trên máy, không bao giờ gửi đi.
///
/// Mỗi khoản được lưu **riêng theo `id`** (`storageKey`), không gộp chung một khối. Tác vụ nền thêm khoản và danh sách trong app xoá khoản có thể
/// chạy cùng lúc; đọc cả khối rồi ghi lại cả khối thì bên ghi sau đè mất thay đổi của bên ghi trước (khoản vừa thêm biến mất, khoản đã xoá hiện lại).
/// Thêm hay xoá một khoản chỉ đụng đúng khoá của khoản đó.
public struct PendingPayment: Codable, Equatable, Sendable, Identifiable {
    /// Tiền tố khoá lưu; phần sau là `id`.
    public static let storageKeyPrefix = "pendingPayment."

    public let id: UUID
    /// Theo đơn vị nhỏ nhất của `currencyCode` (đồng, yên), như `QuickEntryResult.amount`.
    public let amount: Int64
    public let currencyCode: String
    public let merchant: String
    public let date: Date

    public init(id: UUID = UUID(), amount: Int64, currencyCode: String, merchant: String, date: Date) {
        self.id = id
        self.amount = amount
        self.currencyCode = currencyCode
        self.merchant = merchant
        self.date = date
    }

    /// Khoá lưu của khoản này (một khoản một khoá).
    public var storageKey: String { Self.storageKeyPrefix + id.uuidString }

    /// Dữ liệu để lưu dưới `storageKey`. Mã hoá lỗi thì ném lỗi, để nơi gọi không tưởng đã giữ được khoản.
    public func encoded() throws -> Data { try JSONEncoder().encode(self) }

    /// Đọc lại từ dữ liệu đã lưu; hỏng thì `nil`.
    public init?(jsonData: Data) {
        guard let payment = try? JSONDecoder().decode(PendingPayment.self, from: jsonData) else { return nil }
        self = payment
    }
}

/// Danh sách khoản Apple Pay chờ ghi, mới nhất trước.
///
/// **Không có giới hạn số khoản.** Bỏ khoản cũ nhất khi đầy nghĩa là xoá tiền của người dùng mà họ chưa hề quyết định bỏ, trong khi danh sách này
/// tồn tại qua nhiều tháng; mỗi khoản chỉ vài trăm byte nên giữ hết không phải gánh nặng.
public struct PendingPayments: Equatable, Sendable {
    public let items: [PendingPayment]

    /// Sắp mới nhất trước (cùng lúc thì theo `id` cho thứ tự ổn định); trùng `id` chỉ giữ một.
    public init(items: [PendingPayment] = []) {
        var seen = Set<UUID>()
        self.items = items
            .sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
            .filter { seen.insert($0.id).inserted }
    }

    /// Dựng từ mọi cặp khoá/giá trị của kho lưu (ví dụ `UserDefaults.dictionaryRepresentation()`): chỉ lấy khoá có tiền tố `storageKeyPrefix`.
    /// Mục hỏng hoặc có khoá không khớp `id` bên trong thì bị bỏ qua và không làm mất các khoản khác; mọi khoản được liệt kê đều xoá được qua
    /// `storageKey` của nó.
    public init(storedValues: [String: Any]) {
        self.init(items: storedValues.compactMap { key, value -> PendingPayment? in
            guard key.hasPrefix(PendingPayment.storageKeyPrefix),
                  let data = value as? Data,
                  let payment = PendingPayment(jsonData: data),
                  payment.storageKey == key else { return nil }
            return payment
        })
    }

    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }
}
