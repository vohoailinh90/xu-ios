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

    /// Thêm được thói quen mới không. Thói quen đã có từ trước thì giữ nguyên, không bao giờ bị tắt.
    public static func canAddHabit(activeHabits: Int, isPro: Bool) -> Bool {
        isPro || activeHabits < freeHabitLimit
    }

    public static func widgetChipLimit(isPro: Bool) -> Int {
        isPro ? widgetChipCapacity : freeWidgetChipLimit
    }
}
