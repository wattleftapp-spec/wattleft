import Charts
import SwiftUI

/// Заряд во времени: сплошная линия — что было, пунктир — прогноз до резерва (или до 100 % при заряде).
/// Палец по графику показывает заряд и время в любой точке.
struct ChargeChart: View {
    let history: [ChargeHistoryPoint]
    let snapshot: BatterySnapshot
    let estimate: BatteryEstimate
    let reserve: Double

    @State private var selected: Date?
    @State private var reveal: CGFloat = ChargeChart.didReveal ? 1 : 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    /// Прорисовка слева направо — только при первом показе за запуск приложения.
    private static var didReveal = false

    private static let maxForecast: TimeInterval = 36 * 3600

    private var now: Date { snapshot.date }
    private var soc: Double { snapshot.socPercent }

    private var forecastEnd: (date: Date, soc: Double) {
        switch estimate.mode {
        case .idle:
            return (now.addingTimeInterval(3 * 3600), soc)
        case .discharging, .charging:
            let duration = estimate.duration ?? 0
            let target = estimate.mode == .charging ? 100 : reserve
            guard duration > 0 else { return (now.addingTimeInterval(3600), soc) }
            let span = min(duration, Self.maxForecast)
            return (now.addingTimeInterval(span), soc + (target - soc) * span / duration)
        }
    }

    /// Последние 6 часов истории + текущая точка.
    private var past: [ChargeHistoryPoint] {
        let from = now.addingTimeInterval(-6 * 3600)
        var points = history.filter { $0.date >= from && $0.date < now }
        points.append(ChargeHistoryPoint(date: now, soc: soc))
        return points
    }

    private var domain: ClosedRange<Date> {
        // Немного места справа, чтобы последняя подпись оси и время окончания не обрезались.
        let start = past.first?.date ?? now
        let end = forecastEnd.date
        return start...end.addingTimeInterval(max(end.timeIntervalSince(start) * 0.06, 20 * 60))
    }

    /// Ровные часы внутри графика, не ближе ~12% к краям — чтобы подписи не обрезались.
    private var xTicks: [Date] {
        let d = domain
        let span = d.upperBound.timeIntervalSince(d.lowerBound)
        let hours = span / 3600
        let step: Double = hours <= 4 ? 1 : hours <= 8 ? 2 : hours <= 15 ? 3 : hours <= 30 ? 6 : 12
        let cal = Calendar.current
        guard var t = cal.dateInterval(of: .hour, for: d.lowerBound)?.end else { return [] }
        var ticks: [Date] = []
        let margin = span * 0.12
        while t < d.upperBound {
            let hour = cal.component(.hour, from: t)
            if Double(hour).truncatingRemainder(dividingBy: step) == 0,
               t.timeIntervalSince(d.lowerBound) > margin * 0.5,
               d.upperBound.timeIntervalSince(t) > margin {
                ticks.append(t)
            }
            t = t.addingTimeInterval(3600)
        }
        return ticks
    }

    /// Средняя ступень той же палитры, что и у цифры процента, — график и цифра одного цвета.
    private var tint: Color {
        let dark = scheme == .dark
        switch estimate.mode {
        case .charging: return (dark ? FlowingGradientText.chargingDark : FlowingGradientText.chargingLight)[1]
        case .discharging: return (dark ? FlowingGradientText.dischargingDark : FlowingGradientText.dischargingLight)[1]
        case .idle: return .secondary
        }
    }

    var body: some View {
        let end = forecastEnd
        let pastPoints = past

        Chart {
            // Заливка под всей кривой.
            ForEach(Array(pastPoints.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Time", p.date), y: .value("Charge", p.soc))
                    .foregroundStyle(areaGradient)
            }
            AreaMark(x: .value("Time", end.date), y: .value("Charge", end.soc))
                .foregroundStyle(areaGradient)

            // История.
            ForEach(Array(pastPoints.enumerated()), id: \.offset) { _, p in
                LineMark(x: .value("Time", p.date), y: .value("Charge", p.soc), series: .value("Series", "history"))
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }

            // Прогноз.
            LineMark(x: .value("Time", now), y: .value("Charge", soc), series: .value("Series", "forecast"))
                .foregroundStyle(tint.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))
            LineMark(x: .value("Time", end.date), y: .value("Charge", end.soc), series: .value("Series", "forecast"))
                .foregroundStyle(tint.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))

            // Порог резерва.
            if reserve > 0 {
                RuleMark(y: .value("Reserve", reserve))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .bottom, alignment: .leading, spacing: 2) {
                        Text("reserve \(Int(reserve))%", comment: "Chart label for the reserve threshold")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }

            // Сейчас.
            PointMark(x: .value("Time", now), y: .value("Charge", soc))
                .symbol {
                    Circle()
                        .fill(tint)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }

            // Конец прогноза.
            if estimate.mode != .idle {
                PointMark(x: .value("Time", end.date), y: .value("Charge", end.soc))
                    .symbol {
                        Circle()
                            .stroke(tint, lineWidth: 2)
                            .background(Circle().fill(Color(.systemBackground)))
                            .frame(width: 9, height: 9)
                    }
                    .annotation(position: estimate.mode == .charging ? .leading : .top, alignment: estimate.mode == .charging ? .center : .trailing, spacing: 6) {
                        Text(end.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption.weight(.semibold))
                            .fixedSize()
                            .foregroundStyle(tint)
                    }
            }

            // Выбранная пальцем точка.
            if let selected, let value = value(at: selected) {
                RuleMark(x: .value("Selected", selected))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        VStack(spacing: 1) {
                            Text("\(Int(value.rounded()))%")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                            Text(selected.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background {
                            // Плотная подложка вместо стекла: на графике стекло даёт артефакты.
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                        }
                    }
                PointMark(x: .value("Selected", selected), y: .value("Charge", value))
                    .foregroundStyle(tint)
                    .symbolSize(40)
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...100)
        .chartXSelection(value: $selected)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 50, 100]) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                AxisValueLabel {
                    if let d = v.as(Double.self) { Text("\(Int(d))%") }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xTicks) { _ in
                AxisValueLabel(format: .dateTime.hour().minute())
                    .font(.caption2)
            }
        }
        .sensoryFeedback(.selection, trigger: selected.map { Int($0.timeIntervalSince1970 / 600) })
        .animation(.smooth, value: snapshot)
        .mask(alignment: .leading) {
            GeometryReader { g in
                // Маска выше графика, чтобы не срезать подписи оси и подсказку.
                Rectangle()
                    .frame(width: g.size.width * reveal, height: g.size.height + 60)
                    .offset(y: -30)
            }
        }
        .onAppear {
            guard !Self.didReveal else { return }
            Self.didReveal = true
            if reduceMotion {
                reveal = 1
            } else {
                // Сильный ease-out: движение видно сразу, плавно доезжает.
                withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.6)) { reveal = 1 }
            }
        }
    }

    private var areaGradient: LinearGradient {
        LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom)
    }

    /// Заряд в момент времени: интерполяция по истории или по прогнозу.
    private func value(at date: Date) -> Double? {
        if date >= now {
            let end = forecastEnd
            let span = end.date.timeIntervalSince(now)
            guard span > 0 else { return soc }
            let t = min(1, date.timeIntervalSince(now) / span)
            return soc + (end.soc - soc) * t
        }
        let points = past
        guard let after = points.firstIndex(where: { $0.date >= date }) else { return points.last?.soc }
        guard after > 0 else { return points.first?.soc }
        let a = points[after - 1], b = points[after]
        let span = b.date.timeIntervalSince(a.date)
        guard span > 0 else { return b.soc }
        return a.soc + (b.soc - a.soc) * date.timeIntervalSince(a.date) / span
    }
}
