import AppIntents
import SwiftUI
import WidgetKit
import XuCore

/// Nút "Ghi chi tiêu" cho Trung tâm điều khiển, màn hình khoá và Nút Tác vụ (iOS 18, docs/02 W4): chạm là mở Xu với
/// con trỏ trong ô ghi. Tên trong thư viện điều khiển do hệ thống đọc theo ngôn ngữ máy (`Localizable.xcstrings`);
/// chữ trên nút theo ngôn ngữ chọn trong app, như widget.
@available(iOS 18.0, *)
struct QuickEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "QuickEntryControl") {
            ControlWidgetButton(action: OpenQuickEntryIntent()) {
                Label(AppSettings.language.t(.controlLogExpense), systemImage: "square.and.pencil")
            }
        }
        .displayName("Ghi chi tiêu")
        .description("Mở Xu, con trỏ nằm sẵn trong ô ghi.")
    }
}
