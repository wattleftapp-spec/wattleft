import ActivityKit
import SwiftUI
import WidgetKit

private typealias State = MarstekActivityAttributes.ContentState

private func socColor(_ soc: Double) -> Color {
    soc > 50 ? .green : soc > 20 ? .orange : .red
}

/// Оставшееся время, которое система отсчитывает сама, каждую секунду.
private struct LiveCountdown: View {
    let state: State

    var body: some View {
        if let end = state.endDate, end > Date() {
            Text(timerInterval: state.updated...end, countsDown: true)
                .monospacedDigit()
        } else if state.estimate.mode == .idle {
            Text("—")
        } else {
            Text("0:00")
        }
    }
}

/// Полоска заряда, которая плавно убывает/растёт без обновлений.
private struct LiveBar: View {
    let state: State

    var body: some View {
        Group {
            if let range = state.barInterval {
                ProgressView(timerInterval: range, countsDown: state.estimate.mode == .discharging) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            } else {
                ProgressView(value: state.socPercent, total: 100)
            }
        }
        .tint(socColor(state.socPercent))
    }
}

private func modeTitle(_ state: State) -> String {
    switch state.estimate.mode {
    case .discharging: return "Хватит на"
    case .charging: return "До полной"
    case .idle: return "Нет нагрузки"
    }
}

private func powerText(_ state: State) -> String {
    let e = state.estimate
    switch e.mode {
    case .discharging: return "нагрузка \(Fmt.watts(e.powerW))"
    case .charging: return "заряд \(Fmt.watts(e.powerW))"
    case .idle: return "в простое"
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<MarstekActivityAttributes>

    var body: some View {
        let s = context.state
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(socColor(s.socPercent).opacity(0.25), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: s.socPercent / 100)
                    .stroke(socColor(s.socPercent), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(s.socPercent.rounded()))%")
                    .font(.system(.callout, design: .rounded).weight(.bold))
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(modeTitle(s)).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(intent: RefreshBatteryIntent()) {
                        Image(systemName: "arrow.clockwise").font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                LiveCountdown(state: s)
                    .font(.title2.weight(.bold))
                LiveBar(state: s)
                Text("\(powerText(s)) · данные \(s.updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(context.isStale ? .orange : .secondary)
            }
        }
        .padding(16)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .activityBackgroundTint(Color.black.opacity(0.75))
        .activitySystemActionForegroundColor(.white)
    }
}

struct MarstekLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MarstekActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(Int(s.socPercent.rounded()))%", systemImage: "bolt.batteryblock.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(socColor(s.socPercent))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(modeTitle(s)).font(.caption2).foregroundStyle(.secondary)
                        LiveCountdown(state: s).font(.title3.weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        LiveBar(state: s)
                        HStack {
                            Text(powerText(s))
                            Spacer()
                            Text("данные \(s.updated.formatted(date: .omitted, time: .shortened))")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill").foregroundStyle(socColor(s.socPercent))
                    Text("\(Int(s.socPercent.rounded()))%")
                }
            } compactTrailing: {
                LiveCountdown(state: s)
                    .frame(maxWidth: 56)
                    .multilineTextAlignment(.trailing)
            } minimal: {
                Text("\(Int(s.socPercent.rounded()))")
                    .foregroundStyle(socColor(s.socPercent))
            }
        }
    }
}

#Preview("Экран блокировки", as: .content, using: MarstekActivityAttributes(deviceName: "VenusE")) {
    MarstekLiveActivity()
} contentStates: {
    State(socPercent: 76, capacityWh: 5120, netW: 410, updated: Date(), reservePercent: 10)
}
