import XCTest
@testable import XuCore

/// Bản Swift của quy tắc chọn số tiền ở `prototypes/cham-bien-lai.html` (docs/11). Mọi giá trị và điểm mong đợi dưới đây lấy từ việc chạy **chính
/// đoạn JavaScript của trang** (`findAmounts` + `pick`) trên cùng chuỗi, để hai bản không lệch nhau — trừ các test ghi rõ "khác trang chấm có chủ ý"
/// (toàn khổ, số vượt Int64). Chuỗi mẫu là dữ liệu giả.
final class ReceiptAmountReaderTests: XCTestCase {
    /// "giá trị:điểm" của từng ứng viên theo thứ tự xuất hiện — so chuỗi cho dễ đọc khi sai.
    private func pairs(_ text: String) -> [String] {
        ReceiptAmountReader.candidates(in: text).map { "\($0.value):\($0.score)" }
    }

    func testExampleOfScoringPage() {
        let text = "Chuyển tiền thành công\n-1.356.780 VND\n26/09/2026 08:41:12\nTài khoản nguồn\n0123456789\nNgười nhận\nNGUYEN VAN A\n"
            + "Ngân hàng nhận\nACB\nNội dung\nTien an trua thang 9\nPhí giao dịch\n0 VND\nMã giao dịch\nFT26269123456"
        let reading = ReceiptAmountReader.read(text)
        XCTAssertEqual(reading?.best.value, 1_356_780)
        XCTAssertEqual(reading?.best.score, 5, "đơn vị +3, dấu - +2")
        XCTAssertEqual(reading?.isAmbiguous, false)
        // Số tài khoản, năm, mã giao dịch (số trần không đơn vị) và "0 VND" (không phải số dương dạng số tiền) không thành ứng viên.
        XCTAssertEqual(ReceiptAmountReader.candidates(in: text).count, 1)
    }

    func testUnitWithoutSpaceAndDong() {
        let text = "Thanh toán thành công\n52.000đ\nNgười nhận\nTRẦN THỊ BÍCH NGỌC\nNội dung\nca phe voi Lan\nMã giao dịch\n2609271905123456"
        XCTAssertEqual(ReceiptAmountReader.read(text)?.best.value, 52_000)
        XCTAssertEqual(ReceiptAmountReader.read(text)?.best.score, 3)
        XCTAssertEqual(ReceiptAmountReader.candidates(in: text).count, 1, "mã 16 chữ số không đơn vị bị bỏ")
    }

    func testIncomingKeepsAmountOverBalance() {
        let text = "Biến động số dư\n+2.500.000 VND\nThời gian\n28/09/2026 10:15:30\nSố dư\n8.431.200 VND"
        XCTAssertEqual(pairs(text), ["2500000:-1", "8431200:-3"])
        XCTAssertEqual(ReceiptAmountReader.read(text)?.best.value, 2_500_000,
                       "tiêu đề \"số dư\" trừ điểm cả hai số, nhưng số tiền vẫn hơn số dư nhờ dấu + và đơn vị")
    }

    func testLabelBeatsFee() {
        let text = "Số tiền\n1.200.000\nPhí giao dịch\n1.100 VND"
        XCTAssertEqual(pairs(text), ["1200000:4", "1100:-3"])
        XCTAssertEqual(ReceiptAmountReader.read(text)?.best.value, 1_200_000)
    }

    func testTieTakesLargerAndIsAmbiguous() {
        let reading = ReceiptAmountReader.read("Chuyển khoản\n2.000.000 VND\n3.000.000 VND")
        XCTAssertEqual(reading?.best.value, 3_000_000, "hoà điểm thì lấy số lớn hơn, như trang chấm")
        XCTAssertEqual(reading?.isAmbiguous, true, "nhưng báo là nhập nhằng để người dùng xem lại")
    }

    func testNothingLooksLikeAnAmount() {
        XCTAssertNil(ReceiptAmountReader.read("Tài khoản\n0123456789\nMã\n123456789\nNgày 26/09/2026"))
        XCTAssertNil(ReceiptAmountReader.read(""))
    }

    func testCommaGroupingAndLabelOnPreviousLine() {
        let text = "Số tiền giao dịch\n1,356,780 VND"
        XCTAssertEqual(ReceiptAmountReader.read(text)?.best.value, 1_356_780)
        XCTAssertEqual(ReceiptAmountReader.read(text)?.best.score, 7, "đơn vị +3, nhãn \"số tiền\" ở dòng trên +4")
    }

    func testBalanceLineIsLowerThanAmountLine() {
        let text = "Số tiền: 500.000đ\nSố dư 12.345.678đ"
        XCTAssertEqual(pairs(text), ["500000:7", "12345678:1"])
    }

    func testUnitBeforeNumberStillFoundWithoutUnitBonus() {
        let text = "VND 1.356.780\nNội dung\nan trua"
        XCTAssertEqual(pairs(text), ["1356780:0"])
    }

    func testLabelAndFeeOnSameLine() {
        // Nhãn "phí" đứng sau số nên chưa ảnh hưởng điểm của số trước nó.
        XCTAssertEqual(pairs("Số tiền chuyển 350.000 VND Phí 0 VND"), ["350000:7"])
    }

    func testFeeLinePenaltyLeaksToNextLine() {
        // Giới hạn đã biết, giữ để khớp trang chấm: nhãn trừ điểm ở dòng trên còn kéo điểm số ở dòng dưới xuống. Vẫn chọn đúng vì phí bị trừ nhiều hơn.
        let text = "Phí giao dịch 11.000 VND\nSố tiền 250.000 VND"
        XCTAssertEqual(pairs(text), ["11000:-3", "250000:1"])
        XCTAssertEqual(ReceiptAmountReader.read(text)?.best.value, 250_000)
    }

    func testBareNumbersNeedAUnit() {
        XCTAssertNil(ReceiptAmountReader.read("Số tiền\n5000\nMã 4321"), "số trần không đơn vị bị bỏ, kể cả có nhãn: giới hạn đã biết")
        let reading = ReceiptAmountReader.read("Số tiền 5000 VND")
        XCTAssertEqual(reading?.best.value, 5_000)
        XCTAssertEqual(reading?.best.score, 7)
    }

    func testIgnoresGroupsThatAreNotThousands() {
        // "26.09" không phải số tiền: sau dấu chấm phải đủ ba chữ số.
        XCTAssertNil(ReceiptAmountReader.read("Ngày 26.09 lúc 10,15"))
    }

    func testPlusSignMarksIncomeButDoesNotChangeTheChoice() {
        let incoming = ReceiptAmountReader.candidates(in: "Biến động số dư\n+2.500.000 VND\nSố dư\n8.431.200 VND")
        XCTAssertEqual(incoming.map(\.hasPlusSign), [true, false])
        XCTAssertEqual(ReceiptAmountReader.candidates(in: "-1.356.780 VND").map(\.hasPlusSign), [false])
        XCTAssertEqual(ReceiptAmountReader.candidates(in: "1.356.780 VND").map(\.hasPlusSign), [false])
    }

    func testHugeNumberDoesNotCrash() {
        // Khác trang chấm có chủ ý: trang vẫn nhận số này (JavaScript dùng số thực, ra 1e26), app bỏ vì không vừa Int64.
        XCTAssertNil(ReceiptAmountReader.read("Số tiền 99999999999999999999999999 VND"), "vượt Int64: bỏ, không đoán")
    }

    func testContextWindowCountsUTF16LikeThePage() {
        // Cửa sổ 60 đơn vị UTF-16: mỗi emoji tính 2. Với 26 emoji nhãn "số tiền" còn nằm trọn trong cửa sổ, với 27 thì bị cắt mất chữ "s".
        // Đếm theo `Character` (1 emoji = 1) thì cả hai đều thấy nhãn và 27 emoji cho kết quả khác trang chấm.
        let inside = "9.000.000 VND\nSố tiền" + String(repeating: "😀", count: 26) + "1.000 VND"
        XCTAssertEqual(pairs(inside), ["9000000:3", "1000:7"])
        XCTAssertEqual(ReceiptAmountReader.candidates(in: inside).map(\.offset), [0, 73], "vị trí tính theo UTF-16 như idx của trang")
        XCTAssertEqual(ReceiptAmountReader.read(inside)?.best.value, 1_000)

        let cutOff = "9.000.000 VND\nSố tiền" + String(repeating: "😀", count: 27) + "1.000 VND"
        XCTAssertEqual(pairs(cutOff), ["9000000:3", "1000:3"])
        XCTAssertEqual(ReceiptAmountReader.candidates(in: cutOff).map(\.offset), [0, 75])
        let reading = ReceiptAmountReader.read(cutOff)
        XCTAssertEqual(reading?.best.value, 9_000_000)
        XCTAssertEqual(reading?.isAmbiguous, true)
    }

    func testCRLFLineBreaks() {
        // "\r\n" là một `Character` của Swift nhưng JavaScript tách dòng theo "\n"; khớp còn bắt đầu giữa "\r\n" (`\s?` ăn "\n").
        let text = "Số tiền\r\n1.200.000 VND\r\nPhí giao dịch\r\n1.100 VND"
        XCTAssertEqual(pairs(text), ["1200000:7", "1100:-3"])
        XCTAssertEqual(ReceiptAmountReader.candidates(in: text).map(\.offset), [8, 38])
        XCTAssertEqual(ReceiptAmountReader.read(text)?.best.value, 1_200_000)
    }

    func testFullwidthIsFoldedUnlikeThePage() {
        // Khác trang chấm có chủ ý: `TextFolding` đưa chữ/số toàn khổ về nửa khổ, còn `findAmounts` của trang thì không tìm thấy gì.
        let reading = ReceiptAmountReader.read("３.０００.０００ ＶＮＤ")
        XCTAssertEqual(reading?.best.value, 3_000_000)
        XCTAssertEqual(reading?.best.score, 3)
    }
}
