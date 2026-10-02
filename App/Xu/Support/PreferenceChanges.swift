import WidgetKit

/// Việc cần làm sau khi người dùng đổi ngôn ngữ hoặc nơi chi tiêu (Cài đặt, onboarding):
/// khoản quen mặc định đổi theo, widget vẽ lại chữ và loại tiền, thông báo nhắc đặt lại chữ.
@MainActor
enum PreferenceChanges {
    static func apply() {
        SampleData.refreshSeedsIfUntouched()
        WidgetCenter.shared.reloadAllTimelines()
        // Nút "Ghi chi tiêu" trong Trung tâm điều khiển không đi theo timeline của widget: tải lại riêng để chữ trên nút
        // đổi theo ngôn ngữ vừa chọn.
        if #available(iOS 18.0, *) { ControlCenter.shared.reloadAllControls() }
        ReminderScheduler.refresh()
    }
}
