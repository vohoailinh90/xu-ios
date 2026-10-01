import WidgetKit
import SwiftUI
import AppIntents
import XuCore

/// Widget màn hình chính: chạm vào khoản quen là ghi ngay (≈1 giây, không mở app).
struct QuickChipsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickChipsWidget", provider: XuTimelineProvider()) { entry in
            QuickChipsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(AppSettings.language.t(.quickChips))
        .description(AppSettings.language.t(.widgetChipsDescription))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickChipsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: XuEntry

    private var visibleChips: [ChipSnapshot] {
        Array(entry.chips.prefix(family == .systemSmall ? 2 : 4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.language.t(.widgetTodayLine, money(entry.spentToday, entry.currency)))
                    .font(.caption.bold())
                    .contentTransition(.numericText())
                Spacer()
                Link(destination: URL(string: "xu://new")!) {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel(entry.language.t(.logSomethingElse))
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: family == .systemSmall ? 1 : 2)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(visibleChips) { chip in
                    Button(intent: LogChipIntent(chipID: chip.id)) {
                        HStack(spacing: 4) {
                            Text(chip.emoji)
                            Text(chip.title).lineLimit(1)
                            Spacer(minLength: 0)
                            Text(money(chip.amount, chip.currency)).foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func money(_ amount: Int64, _ currency: Currency) -> String {
        MoneyFormatter.compact(amount, currency: currency, language: entry.language)
    }
}
