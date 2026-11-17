import SwiftUI
import WidgetKit

// MARK: - Timeline

struct BatteryEntry: TimelineEntry {
    let date: Date
    let configured: Bool
    let snapshot: BatterySnapshot?
    /// SOC, спроецированный на момент `date` с учётом текущего потребления.
    let socPercent: Double
    let estimate: BatteryEstimate?
    let isStale: Bool

    static let placeholder: BatteryEntry = make(at: Date(), snapshot: .sample, settings: AppSettings(host: "demo"), netW: nil)

    static func make(at date: Date, snapshot: BatterySnapshot?, settings: AppSettings, netW: Double?) -> BatteryEntry {
        guard let snapshot else {
            return BatteryEntry(date: date, configured: settings.isConfigured, snapshot: nil,
                                socPercent: 0, estimate: nil, isStale: false)
        }
        let net = netW ?? snapshot.netW
        // Проецируем максимум на 2 часа вперёд, дальше считаем данные устаревшими.
        let elapsed = min(max(0, date.timeIntervalSince(snapshot.date)), 2 * 3600)
        let remaining = min(snapshot.capacityWh, max(0, snapshot.remainingWh - net * elapsed / 3600))
        let soc = snapshot.capacityWh > 0 ? remaining / snapshot.capacityWh * 100 : snapshot.socPercent
        let estimate = BatteryEstimate.make(remainingWh: remaining, capacityWh: snapshot.capacityWh,
                                            reservePercent: settings.reservePercent, netW: net)
        return BatteryEntry(date: date, configured: settings.isConfigured, snapshot: snapshot,
                            socPercent: soc, estimate: estimate,
                            isStale: date.timeIntervalSince(snapshot.date) > 45 * 60)
    }
}

struct BatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        if context.isPreview && SharedStore.lastSnapshot == nil {
            completion(.placeholder)
        } else {
            completion(.make(at: Date(), snapshot: SharedStore.lastSnapshot,
                             settings: SharedStore.settings, netW: SharedStore.averagedNetW()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        Task {
            let settings = SharedStore.settings
            if settings.isConfigured {
                _ = try? await BatteryService.refresh(timeout: 4)
            }
            let now = Date()
            let snapshot = SharedStore.lastSnapshot
            let net = SharedStore.averagedNetW(at: snapshot?.date ?? now)
            // iOS обновляет виджет примерно раз в 15 мин, поэтому между запросами
            // плавно «отматываем» заряд по текущему потреблению каждые 5 минут.
            let entries = (0..<12).map { i in
                BatteryEntry.make(at: now.addingTimeInterval(Double(i) * 300),
                                  snapshot: snapshot, settings: settings, netW: net)
            }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
        }
    }
}

// MARK: - Views

private func socColor(_ soc: Double) -> Color {
    soc > 50 ? .green : soc > 20 ? .orange : .red
}

private struct StatusLine: View {
    let entry: BatteryEntry
    var short = false

    var body: some View {
        if let e = entry.estimate {
            switch e.mode {
            case .discharging, .charging:
                if !short, !entry.isStale, let d = e.duration, d < 99 * 3600 {
                    // Обратный отсчёт идёт каждую секунду силами системы, без обновлений виджета.
                    let end = entry.date.addingTimeInterval(d)
                    HStack(spacing: 3) {
                        Text(e.mode == .charging ? String(localized: "until full") : String(localized: "left"))
                        Text(timerInterval: entry.date...end, countsDown: true)
                            .monospacedDigit()
                    }
                } else if e.mode == .charging {
                    Text(short ? "⚡︎ \(Fmt.shortDuration(e.duration))" : String(localized: "full in \(Fmt.duration(e.duration))"))
                } else {
                    Text(short ? "≈ \(Fmt.shortDuration(e.duration))" : String(localized: "lasts ≈ \(Fmt.duration(e.duration))"))
                }
            case .idle:
                Text("no load")
            }
        } else {
            Text("—")
        }
    }
}

struct MarstekWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BatteryEntry

    var body: some View {
        Group {
            if entry.snapshot == nil {
                switch family {
                case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                    Text(entry.configured ? String(localized: "Wattleft: no data") : String(localized: "Wattleft: set up"))
                default:
                    NotConfiguredCard()
                }
            } else {
                switch family {
                case .systemMedium:
                    WidgetCard(content: entry.cardContent)
                case .accessoryCircular:
                    Gauge(value: entry.socPercent, in: 0...100) {
                        Image(systemName: "bolt.fill")
                    } currentValueLabel: {
                        Text("\(Int(entry.socPercent.rounded()))")
                    }
                    .gaugeStyle(.accessoryCircular)
                case .accessoryRectangular:
                    VStack(alignment: .leading) {
                        Text("Wattleft \(Int(entry.socPercent.rounded()))%").font(.headline)
                        StatusLine(entry: entry)
                        Gauge(value: entry.socPercent, in: 0...100) { EmptyView() }
                            .gaugeStyle(.accessoryLinearCapacity)
                    }
                case .accessoryInline:
                    HStack {
                        Image(systemName: "bolt.batteryblock.fill")
                        Text("\(Int(entry.socPercent.rounded()))% · ")
                        StatusLine(entry: entry, short: true)
                    }
                default:
                    WidgetCard(content: entry.cardContent)
                }
            }
        }
        .containerBackground(for: .widget) {
            switch family {
            case .systemSmall, .systemMedium:
                WidgetBackground()
            default:
                Color.clear
            }
        }
    }
}

// MARK: - Widget

struct MarstekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MarstekBattery", provider: BatteryProvider()) { entry in
            MarstekWidgetView(entry: entry)
        }
        .configurationDisplayName("Battery Charge")
        .description("Battery charge and how long it will last at the current load.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct MarstekWidgetBundle: WidgetBundle {
    var body: some Widget {
        MarstekWidget()
        MarstekLiveActivity()
    }
}

#Preview(as: .systemSmall) {
    MarstekWidget()
} timeline: {
    BatteryEntry.placeholder
}

#Preview(as: .systemMedium) {
    MarstekWidget()
} timeline: {
    BatteryEntry.placeholder
}

extension BatteryEntry {
    var cardContent: WidgetContent {
        WidgetContent(estimate: estimate, soc: socPercent, date: date, isStale: isStale)
    }
}
