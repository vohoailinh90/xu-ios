import Foundation

/// Một khoản Apple Pay mà Xu **không** tự ghi vì bản Free hết lượt trong tháng (docs/02). Giữ trên máy để người dùng ghi sau, nên khoản không bị
/// bỏ mất mà không ai biết (automation chạy nền, lời nhắn và thông báo không được bảo đảm hiện). Chỉ nằm trên máy, không bao giờ gửi đi.
public struct PendingPayment: Codable, Equatable, Sendable, Identifiable {
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
}

/// Danh sách khoản Apple Pay chờ ghi, mới nhất trước.
public struct PendingPayments: Codable, Equatable, Sendable {
    /// Giữ tối đa chừng này khoản (khoản cũ nhất rơi ra trước): đủ rộng để không mất khoản khi lâu không mở app, mà không phình dữ liệu.
    public static let capacity = 200
    public private(set) var items: [PendingPayment]

    public init(items: [PendingPayment] = []) {
        self.items = Array(items.prefix(Self.capacity))
    }

    /// Đọc từ JSON đã lưu; dữ liệu rỗng hay hỏng thì là danh sách trống.
    public init(jsonData: Data) {
        self = (try? JSONDecoder().decode(PendingPayments.self, from: jsonData)) ?? PendingPayments()
    }

    public var jsonData: Data { (try? JSONEncoder().encode(self)) ?? Data() }
    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }

    /// Thêm khoản mới lên đầu; quá `capacity` thì bỏ khoản cũ nhất.
    public mutating func add(_ payment: PendingPayment) {
        items.insert(payment, at: 0)
        if items.count > Self.capacity { items.removeLast(items.count - Self.capacity) }
    }

    public mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }
}
