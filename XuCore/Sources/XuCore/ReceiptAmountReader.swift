import Foundation

/// Chọn số tiền trong chữ đọc được từ biên lai/thông báo chuyển khoản (docs/11). Bản Swift của `findAmounts` + `pick` trong
/// `prototypes/cham-bien-lai.html` — **cùng quy tắc chọn**, để số đo của trang chấm tham khảo được cho app. Quy tắc đó mới được thử trên ít biên lai thật
/// (chưa đủ 50 ảnh/5 ngân hàng), chưa kết luận.
///
/// Thuần chữ, không phụ thuộc Vision: dùng được cho cả đường đọc ảnh lẫn đường dán nội dung thông báo ngân hàng (hướng dự phòng ở docs/11).
///
/// Quy tắc:
/// - Số tiền là dãy có dấu nhóm nghìn kiểu `1.356.780` / `1,356,780`, hoặc số trần từ 4 chữ số **có đơn vị** (`5000 VND`, `52000đ`);
///   số trần không đơn vị (số tài khoản, mã giao dịch, năm) bị bỏ.
/// - Điểm: đơn vị `vnd`/`đ` +3, dấu `+`/`-` ngay trước +2, nhãn "số tiền/amount/tổng tiền" ở dòng trước hoặc dòng hiện tại +4,
///   nhãn "số dư/balance/phí/fee/hạn mức" ở hai dòng đó −6. Chọn điểm cao nhất, hoà thì chọn số lớn hơn (`Reading.isAmbiguous` báo hoà).
/// - Cửa sổ ngữ cảnh đếm theo đơn vị UTF-16 và tách dòng theo `\n` như JavaScript của trang (emoji, `\r\n` không làm lệch), nên với chữ Latin/ASCII thường gặp
///   trên biên lai hai bên chọn như nhau.
/// - **Khác trang chấm có chủ ý** (`TextFolding` dùng chung với phần còn lại của XuCore): chữ/số toàn khổ được đưa về nửa khổ
///   (`３.０００.０００ ＶＮＤ` có ứng viên, trang thì không); số vượt `Int64` bị bỏ (trang vẫn nhận dạng số thực). Ký tự lạ khác chưa kiểm hết.
/// - Giới hạn đã biết (giữ nguyên để khớp trang chấm): nhãn tìm theo chuỗi con nên "phi" trong từ khác cũng trừ điểm, nhãn trừ điểm ở dòng trên còn
///   ảnh hưởng số ở dòng dưới ("Phí 11.000 VND" rồi "Số tiền 250.000 VND" giảm điểm số sau), số trần không đơn vị như `52000` bị bỏ,
///   chữ `₫` và `dong` không tính là đơn vị.
public enum ReceiptAmountReader {
    public struct Candidate: Equatable, Sendable {
        public let value: Int64
        public let score: Int
        /// Vị trí đầu của khớp (kể cả dấu và khoảng trắng đứng trước số) trong chuỗi đã gấp, tính theo đơn vị UTF-16 như `idx` của trang chấm.
        public let offset: Int
        public let hasUnit: Bool
        /// Có dấu `+` ngay trước số (biến động số dư: tiền vào). Không dùng để chọn số, chỉ để biết khoản là thu hay chi.
        public let hasPlusSign: Bool
    }

    public struct Reading: Equatable, Sendable {
        public let best: Candidate
        /// Có số khác, giá trị khác, cùng điểm với số được chọn: người dùng nên xem lại thay vì tin ngay.
        public let isAmbiguous: Bool
    }

    private static let regex = try! NSRegularExpression(
        pattern: #"(?<![\d.,])([+-]?)\s?(\d{1,3}(?:[.,]\d{3})+|\d{4,})(?!\d)(?:\s*(vnd|d)\b)?"#
    )
    /// "so tien giao dich" và "so tien chuyen" đã gồm trong "so tien".
    private static let amountLabels = ["so tien", "amount", "tong tien"]
    private static let notAmountLabels = ["so du", "balance", "phi", "fee", "han muc"]
    private static let contextLength = 60

    /// Mọi số có dạng số tiền, theo thứ tự xuất hiện.
    public static func candidates(in text: String) -> [Candidate] {
        // Làm việc trên đơn vị UTF-16 (cùng hệ chỉ mục của NSRange và của `String.slice` trong JavaScript), không đổi sang `String.Index`:
        // khớp có thể bắt đầu giữa "\r\n" (một `Character` của Swift) hoặc cắt giữa emoji.
        let folded = TextFolding.fold(text)
        let units = Array(folded.utf16)
        var found: [Candidate] = []
        for match in regex.matches(in: folded, range: NSRange(location: 0, length: units.count)) {
            let raw = string(units, match.range(at: 2))
            let hasUnit = match.range(at: 3).location != NSNotFound
            let hasSeparator = raw.contains { $0 == "." || $0 == "," }
            if !hasUnit && !hasSeparator { continue }
            guard let value = parse(raw), value > 0 else { continue }

            let sign = string(units, match.range(at: 1))
            let start = match.range.location
            // 60 đơn vị UTF-16 trước số, lấy hai dòng cuối, nối bằng một dấu cách.
            let lines = units[max(0, start - contextLength)..<start].split(separator: 10, omittingEmptySubsequences: false)
            var window: [UInt16] = []
            for (index, line) in lines.suffix(2).enumerated() {
                if index > 0 { window.append(32) }
                window.append(contentsOf: line)
            }
            let context = String(decoding: window, as: UTF16.self)

            var score = 0
            if hasUnit { score += 3 }
            if sign == "-" || sign == "+" { score += 2 }
            if amountLabels.contains(where: { context.contains($0) }) { score += 4 }
            if notAmountLabels.contains(where: { context.contains($0) }) { score -= 6 }
            found.append(Candidate(value: value, score: score, offset: start, hasUnit: hasUnit, hasPlusSign: sign == "+"))
        }
        return found
    }

    private static func string(_ units: [UInt16], _ range: NSRange) -> String {
        guard range.location != NSNotFound else { return "" }
        return String(decoding: units[range.location..<range.location + range.length], as: UTF16.self)
    }

    /// Số được chọn, hoặc nil khi không có số nào có dạng số tiền.
    public static func read(_ text: String) -> Reading? {
        let all = candidates(in: text)
        guard let best = all.max(by: { ($0.score, $0.value) < ($1.score, $1.value) }) else { return nil }
        let isAmbiguous = all.contains { $0.score == best.score && $0.value != best.value }
        return Reading(best: best, isAmbiguous: isAmbiguous)
    }

    /// "1.356.780" → 1356780; "5000" → 5000. Dấu nhóm phải chia đúng từng 3 chữ số.
    private static func parse(_ raw: String) -> Int64? {
        let parts = raw.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "." || $0 == "," })
        if parts.count > 1 && !parts.dropFirst().allSatisfy({ $0.count == 3 }) { return nil }
        return Int64(parts.joined())
    }
}
