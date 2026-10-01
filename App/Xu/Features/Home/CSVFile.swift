import SwiftUI
import UniformTypeIdentifiers

/// Xuất CSV — "dữ liệu là của bạn" là một điểm bán hàng, không phải tính năng phụ.
struct CSVFile: Transferable {
    let text: String

    @MainActor
    init(records: [TransactionRecord]) {
        let iso = ISO8601DateFormatter()
        var lines = ["ngay,loai,so_tien,don_vi,danh_muc,ghi_chu,nguon"]
        for r in records {
            let fields = [
                iso.string(from: r.occurredAt),
                r.isIncome ? "thu" : "chi",
                String(r.amount),
                r.currencyCode,
                r.category.name,
                r.note,
                r.sourceRaw
            ].map(Self.escape)
            lines.append(fields.joined(separator: ","))
        }
        // BOM để Excel mở đúng tiếng Việt
        text = "\u{FEFF}" + lines.joined(separator: "\n")
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { Data($0.text.utf8) }
            .suggestedFileName("xu-giao-dich.csv")
    }
}
