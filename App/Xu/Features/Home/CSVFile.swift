import SwiftUI
import UniformTypeIdentifiers
import XuCore

/// Xuất CSV — "dữ liệu là của bạn" là một điểm bán hàng, không phải tính năng phụ.
/// Tiêu đề cột, loại thu/chi và tên danh mục theo ngôn ngữ đang chọn; số tiền là số nguyên kèm mã tiền (VND, JPY).
struct CSVFile: Transferable {
    let text: String

    @MainActor
    init(records: [TransactionRecord], language: AppLanguage) {
        let iso = ISO8601DateFormatter()
        var lines = [language.t(.csvHeader)]
        for r in records {
            let fields = [
                iso.string(from: r.occurredAt),
                language.t(r.isIncome ? .csvIncome : .csvExpense),
                String(r.amount),
                r.currencyCode,
                r.category.name(in: language),
                r.note,
                r.sourceRaw
            ].map(Self.escape)
            lines.append(fields.joined(separator: ","))
        }
        // BOM để Excel (cả bản tiếng Việt lẫn tiếng Nhật) mở đúng chữ có dấu và chữ Nhật
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
