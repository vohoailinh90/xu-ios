import WidgetKit
import SwiftUI
import XuCore

/// Widget màn hình khóa: nhìn là biết hôm nay đã tiêu bao nhiêu; chạm mở thẳng ô nhập.
struct TodayAccessoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayAccessoryWidget", provider: XuTimelineProvider()) { entry in
            TodayAccessoryView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(URL(string: "xu://new"))
        }
        .configurationDisplayName("Hôm nay")
        .description("Số đã tiêu hôm nay. Chạm để ghi.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct TodayAccessoryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: XuEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Xu · hôm nay \(MoneyFormatter.compact(entry.spentToday))")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "plus")
                Text(MoneyFormatter.compact(entry.spentToday)).font(.caption2).minimumScaleFactor(0.6)
            }
        default:
            VStack(alignment: .leading) {
                Text("Hôm nay đã tiêu").font(.caption)
                Text(MoneyFormatter.compact(entry.spentToday)).font(.title3.bold())
                Text("Chạm để ghi").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
