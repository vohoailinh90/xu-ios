import Foundation

/// Tiền tệ Xu hiểu được. Cả hai đều không có số lẻ nên số tiền luôn là `Int64` nguyên.
/// Không quy đổi giữa hai loại tiền: tỷ giá cần mạng, trái nguyên tắc offline (docs/08).
public enum Currency: String, CaseIterable, Codable, Sendable, Identifiable {
    case vnd = "VND"
    case jpy = "JPY"

    public var id: String { rawValue }
    /// Mã ISO 4217, lưu vào `currencyCode` của giao dịch.
    public var code: String { rawValue }

    /// Mã lạ (dữ liệu cũ, CSV…) → VND, vì mọi giao dịch trước khi có đa tiền tệ đều là VND.
    public init(code: String) {
        self = Currency(rawValue: code.uppercased()) ?? .vnd
    }

    /// Ký hiệu ngắn, ví dụ để ghi cạnh ô nhập ngân sách.
    public func symbol(in language: AppLanguage) -> String {
        switch (self, language) {
        case (.vnd, .vi): "đ"
        case (.vnd, _): "₫"
        case (.jpy, .ja): "円"
        case (.jpy, _): "¥"
        }
    }
}

/// Nơi người dùng tiêu tiền. Quyết định:
/// - tiền mặc định cho số không kèm đơn vị ("phở 45", "ラーメン 980"),
/// - thứ tự ngày/tháng khi gõ "9/12",
/// - từ lóng của người Việt ở Nhật: "5 man" = 5 vạn yên = 50.000 yên, "3 sen" = 3.000 yên.
public enum Market: String, CaseIterable, Codable, Sendable, Identifiable {
    case vietnam
    case japan

    public var id: String { rawValue }

    public var currency: Currency {
        switch self {
        case .vietnam: .vnd
        case .japan: .jpy
        }
    }

    /// Việt Nam ghi ngày trước ("12/9" = 12 tháng 9); Nhật ghi tháng trước ("9/12" = 12 tháng 9).
    public var dayFirst: Bool { self == .vietnam }

    public var names: LocalizedText {
        switch self {
        case .vietnam: LocalizedText(vi: "Việt Nam (đồng)", en: "Vietnam (₫)", ja: "ベトナム(ドン)")
        case .japan: LocalizedText(vi: "Nhật Bản (yên)", en: "Japan (¥)", ja: "日本(円)")
        }
    }

    public func name(in language: AppLanguage) -> String { names[language] }

    /// Đoán lần mở đầu tiên từ vùng của máy: vùng Nhật → Nhật, còn lại → Việt Nam (Việt Nam trước).
    public static func guess(regionCode: String?) -> Market {
        regionCode?.uppercased() == "JP" ? .japan : .vietnam
    }
}
