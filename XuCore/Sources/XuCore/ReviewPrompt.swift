import Foundation

/// Hỏi đánh giá App Store (docs/07): đúng một lần, khi người dùng tự chốt ngày trong app và đã chốt đủ 5 ngày —
/// lúc vừa xong việc, không bao giờ lúc đang ghi. Hiện hộp đánh giá hay không là do iOS quyết (`requestReview`).
public enum ReviewPrompt {
    public static let closedDaysBeforeAsking = 5

    /// - `closedDays`: số ngày đã chốt, tính cả ngày vừa chốt.
    /// - `alreadyAsked`: Xu đã gọi `requestReview` trước đây (dù iOS có hiện hộp hay không).
    public static func shouldAsk(closedDays: Int, alreadyAsked: Bool) -> Bool {
        !alreadyAsked && closedDays >= closedDaysBeforeAsking
    }
}
