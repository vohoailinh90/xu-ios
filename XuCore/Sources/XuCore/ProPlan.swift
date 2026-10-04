import Foundation

/// Giới hạn bản Free và Xu Pro (docs/02). Không bao giờ giới hạn việc ghi chép hay xuất dữ liệu:
/// ô nhập, khoản quen trong app, Phím tắt và CSV luôn như nhau với mọi người.
public enum ProPlan {
    /// Thói quen đang theo dõi cùng lúc ở bản Free.
    public static let freeHabitLimit = 2
    /// Số nút khoản quen trên widget màn hình chính ở bản Free (trong app vẫn đủ cả).
    public static let freeWidgetChipLimit = 2
    /// Widget vừa có chỗ cho 4 nút; Pro dùng hết chỗ.
    public static let widgetChipCapacity = 4
    /// Đọc ảnh chuyển khoản (OCR) ở bản Free: số ảnh mỗi tháng dương lịch (chủ dự án chốt 2026-10-04, `docs/02`). Xu Pro không giới hạn.
    /// Ghi tay, ghi nhanh và xuất dữ liệu không bao giờ bị đếm.
    public static let freeReceiptReadsPerMonth = 5
    /// Tự ghi Apple Pay (`LogPaymentIntent`, automation "Giao dịch") ở bản Free: số khoản mỗi tháng dương lịch (chủ dự án chốt 2026-10-04,
    /// `docs/02`). Xu Pro không giới hạn. Ghi tay, ghi nhanh, `LogExpenseIntent` (Action Button, Siri, Phím tắt gõ/đọc) và xuất dữ liệu không bị đếm.
    public static let freeApplePayLogsPerMonth = 5

    /// Thêm được thói quen mới không. Thói quen đã có từ trước thì giữ nguyên, không bao giờ bị tắt.
    public static func canAddHabit(activeHabits: Int, isPro: Bool) -> Bool {
        isPro || activeHabits < freeHabitLimit
    }

    public static func widgetChipLimit(isPro: Bool) -> Int {
        isPro ? widgetChipCapacity : freeWidgetChipLimit
    }

    /// Màn "Tháng này" (biểu đồ theo danh mục): bản Free xem tháng hiện tại, Xu Pro xem lại các tháng trước (docs/02).
    /// Danh sách giao dịch và CSV vẫn đủ mọi tháng cho tất cả mọi người.
    public static func canViewMonth(_ month: MonthKey, current: MonthKey, isPro: Bool) -> Bool {
        isPro || month >= current
    }

    /// Màn "Theo tuần": bản Free xem tuần hiện tại, Xu Pro xem lại các tuần cũ (docs/02, "toàn bộ lịch sử").
    /// Danh sách giao dịch và CSV vẫn đủ mọi tuần cho tất cả mọi người. Hai tham số là thứ Hai của từng tuần.
    public static func canViewWeek(startingOn weekStart: DayKey, currentWeekStart: DayKey, isPro: Bool) -> Bool {
        isPro || weekStart >= currentWeekStart
    }

    /// Công tắc khoá Face ID (docs/02, S4) chạm được không: Xu Pro bật/tắt tự do. Bản Free chỉ còn tắt được khoá đã
    /// bật từ trước (ví dụ sau hoàn tiền) — không bao giờ để người dùng bị khoá ngoài dữ liệu của chính mình.
    /// Khoá chỉ che việc xem (danh sách, biểu đồ, thói quen, cài đặt, xuất CSV), không bao giờ che ô ghi.
    public static func canChangeFaceIDLock(isPro: Bool, isEnabled: Bool) -> Bool { isPro || isEnabled }
}

/// Lời mời Xu Pro (docs/07): đúng một lần, sau 7 ngày dùng liên tục. Không phải paywall: là một thẻ trên Home,
/// chạm mới mở paywall, và không bao giờ bật ra giữa lúc đang ghi.
public enum ProInvite {
    public static let streakDays = 7

    /// Thẻ mời có hiện hôm nay không.
    /// - `usedDays`: ngày có ghi ít nhất một khoản hoặc đã chốt ngày (như thói quen "Ghi chép mỗi ngày").
    ///   Chỉ xét 7 ngày **trước hôm nay**, nên ghi thêm hôm nay không làm thẻ bật ra giữa chừng.
    ///   Chỉ được tính khi cần (người dùng Pro hay đã mời rồi thì không phải duyệt danh sách giao dịch).
    /// - `shownOn`: ngày thẻ hiện lần đầu. Thẻ chỉ ở lại trong chính ngày đó; sang ngày khác là thôi.
    /// - `dismissed`: đã chạm "Để sau" hoặc "Xem Xu Pro".
    public static func isVisible(usedDays: @autoclosure () -> Set<DayKey>, today: DayKey, shownOn: DayKey?,
                                 dismissed: Bool, isPro: Bool, calendar: Calendar) -> Bool {
        guard !isPro, !dismissed else { return false }
        if let shownOn { return shownOn == today }
        let used = usedDays()
        return (1...streakDays).allSatisfy { used.contains(today.adding(days: -$0, calendar: calendar)) }
    }
}
