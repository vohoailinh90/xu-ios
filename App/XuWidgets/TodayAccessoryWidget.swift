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
        .configurationDisplayName(AppSettings.language.t(.today))
        .description(AppSettings.language.t(.widgetTodayDescription))
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct TodayAccessoryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: XuEntry

    private var spent: String {
        MoneyFormatter.compact(entry.spentToday, currency: entry.currency, language: entry.language)
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.language.t(.widgetInline, spent))
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "plus")
                Text(spent).font(.caption2).minimumScaleFactor(0.6)
            }
        default:
            VStack(alignment: .leading) {
                Text(entry.language.t(.spentToday)).font(.caption)
                Text(spent).font(.title3.bold())
                Text(entry.language.t(.tapToLog)).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
