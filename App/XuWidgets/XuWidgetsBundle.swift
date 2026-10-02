import WidgetKit
import SwiftUI

@main
struct XuWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickChipsWidget()
        TodayAccessoryWidget()
        if #available(iOS 18.0, *) {
            QuickEntryControl()
        }
    }
}
