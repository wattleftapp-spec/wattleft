import SwiftUI
import WidgetKit

// Виджеты домашнего экрана (светлая и тёмная тема): карточка со свечением цвета состояния,
// шапка с иконкой, подпись, крупное значение и полоса со штрихами на пустой части.

/// Что показывать в карточке — общее для маленького и среднего размера.
struct WidgetContent {
    let icon: String
    let title: String
    let label: String
    let value: String
    /// Длительность часами и минутами — рисуется с мелкими единицами («10ч 47м»).
    let duration: (h: Int, m: Int)?
    let footnote: String?
    let soc: Double
    let mode: BatteryEstimate.Mode?

    init(estimate e: BatteryEstimate?, soc: Double, date: Date, isStale: Bool) {
        self.soc = soc
        mode = e?.mode
        let entrySoc = soc

        switch e?.mode {
        case .charging?:
            icon = "bolt.fill"; title = "Заряд"; label = "До полной"
            value = Self.clock(e?.duration); duration = Self.split(e?.duration)
        case .discharging?:
            icon = "bolt.batteryblock.fill"; title = "Разряд"; label = "Осталось"
            value = Self.clock(e?.duration); duration = Self.split(e?.duration)
        default:
            icon = "pause.fill"; title = "Простой"; label = "Заряд"
            value = "\(Int(entrySoc.rounded()))%"; duration = nil
        }

        if isStale {
            footnote = "данные устарели"
        } else if let d = e?.duration, e?.mode != .idle {
            let end = date.addingTimeInterval(d)
            let time = end.formatted(date: .omitted, time: .shortened)
            footnote = Calendar.current.isDateInToday(end) ? "до \(time)" : "завтра \(time)"
        } else {
            footnote = nil
        }
    }

    /// Тёмная, средняя, светлая ступени палитры для текущей темы.
    func colors(_ scheme: ColorScheme) -> [Color] {
        BatteryPalette.colors(for: mode, dark: scheme == .dark)
    }

    static func split(_ t: TimeInterval?) -> (h: Int, m: Int)? {
        guard let t, t.isFinite, t >= 0 else { return nil }
        let minutes = Int((t / 60).rounded())
        return (min(99, minutes / 60), minutes % 60)
    }

    /// «2:40» — часы и минуты, как на циферблате.
    static func clock(_ t: TimeInterval?) -> String {
        guard let t, t.isFinite, t >= 0 else { return "—" }
        let minutes = Int((t / 60).rounded())
        let h = minutes / 60, m = minutes % 60
        if h >= 100 { return "99+ ч" }
        return "\(h):" + String(format: "%02d", m)
    }
}

/// Чернила карточки: белые на тёмной, почти чёрные на светлой.
struct Ink {
    let scheme: ColorScheme
    var dark: Bool { scheme == .dark }
    var primary: Color { dark ? .white : Color(red: 0.07, green: 0.07, blue: 0.08) }
    var secondary: Color { primary.opacity(dark ? 0.55 : 0.5) }
    var unit: Color { primary.opacity(dark ? 0.6 : 0.45) }
    var tick: Color { primary.opacity(dark ? 0.22 : 0.16) }
    /// Подпись цветом состояния: на тёмном — светлая ступень, на светлом — тёмная (для контраста).
    func label(_ c: [Color]) -> Color { dark ? c[2].opacity(0.85) : c[0] }
    func icon(_ c: [Color]) -> Color { dark ? c[2] : c[1] }
}

/// Фон: почти чёрный, свечение тёмной ступени сверху и средней снизу, тонкая светлая кромка.
/// На светлой теме — тёплый белый со светлым пастельным свечением того же цвета.
struct GlowBackground: View {
    let mode: BatteryEstimate.Mode?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = BatteryPalette.colors(for: mode, dark: scheme == .dark)
        if scheme == .dark {
            ZStack {
                Color(red: 0.055, green: 0.055, blue: 0.065)
                RadialGradient(colors: [c[0].opacity(0.75), c[0].opacity(0)],
                               center: .topTrailing, startRadius: 0, endRadius: 240)
                RadialGradient(colors: [c[1].opacity(0.35), c[1].opacity(0)],
                               center: .bottomLeading, startRadius: 0, endRadius: 200)
                LinearGradient(colors: [.white.opacity(0.06), .clear], startPoint: .top, endPoint: .center)
                ContainerRelativeShape()
                    .strokeBorder(.white.opacity(0.09), lineWidth: 1)
            }
        } else {
            ZStack {
                Color(red: 0.985, green: 0.982, blue: 0.975)
                RadialGradient(colors: [c[2].opacity(0.30), c[2].opacity(0)],
                               center: .topTrailing, startRadius: 0, endRadius: 240)
                RadialGradient(colors: [c[1].opacity(0.12), c[1].opacity(0)],
                               center: .bottomLeading, startRadius: 0, endRadius: 200)
                ContainerRelativeShape()
                    .strokeBorder(.black.opacity(0.06), lineWidth: 1)
            }
        }
    }
}

/// Полоса: градиентная заливка до текущего заряда, дальше — тонкие штрихи.
struct TickBar: View {
    let fraction: Double
    let colors: [Color]
    var tick: Color = .white.opacity(0.22)

    var body: some View {
        GeometryReader { g in
            let h = g.size.height
            let fill = max(h, g.size.width * min(1, max(0, fraction)))
            ZStack(alignment: .leading) {
                Canvas { ctx, size in
                    var x = fill + 5
                    while x < size.width - 1 {
                        let r = CGRect(x: x, y: size.height * 0.12, width: 1.6, height: size.height * 0.76)
                        ctx.fill(Path(roundedRect: r, cornerRadius: 0.8), with: .color(tick))
                        x += 4.5
                    }
                }
                Capsule()
                    .fill(LinearGradient(colors: [colors[1], colors[2]], startPoint: .leading, endPoint: .trailing))
                    .frame(width: fill)
                    .widgetAccentable()
            }
        }
        .frame(height: 8)
    }
}

/// «10ч 47м»: цифры крупно, единицы мельче и приглушённее — не путается со временем на часах.
struct BigValue: View {
    let content: WidgetContent
    let size: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let d = content.duration {
                let unitColor = Ink(scheme: scheme).unit
                let unit = Font.system(size: size * 0.5, weight: .semibold, design: .rounded)
                let num = Font.system(size: size, weight: .semibold, design: .rounded)
                if d.h > 0 {
                    Text("\(d.h)").font(num)
                        + Text("ч ").font(unit).foregroundStyle(unitColor)
                        + Text("\(d.m)").font(num)
                        + Text("м").font(unit).foregroundStyle(unitColor)
                } else {
                    Text("\(d.m)").font(num)
                        + Text(" мин").font(unit).foregroundStyle(unitColor)
                }
            } else {
                Text(content.value)
                    .font(.system(size: size, weight: .semibold, design: .rounded))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .widgetAccentable()
    }
}

private struct Header: View {
    let content: WidgetContent
    var font: Font = .subheadline
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let ink = Ink(scheme: scheme)
        HStack(spacing: 6) {
            Image(systemName: content.icon)
                .foregroundStyle(ink.icon(content.colors(scheme)))
                .widgetAccentable()
            Text(content.title)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(Int(content.soc.rounded()))%")
                .foregroundStyle(ink.secondary)
                .monospacedDigit()
        }
        .font(font.weight(.semibold))
    }
}

struct SmallCard: View {
    let content: WidgetContent
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let ink = Ink(scheme: scheme)
        let c = content.colors(scheme)
        VStack(alignment: .leading, spacing: 0) {
            // Как «Time in Daylight»: иконка и процент сверху, название отдельной строкой.
            HStack {
                Image(systemName: content.icon)
                    .foregroundStyle(ink.icon(c))
                    .widgetAccentable()
                Spacer()
                Text("\(Int(content.soc.rounded()))%")
                    .foregroundStyle(ink.secondary)
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
            Text(content.title)
                .font(.headline)
                .padding(.top, 6)
            Spacer(minLength: 0)
            Text(content.label)
                .font(.subheadline)
                .foregroundStyle(ink.label(c))
            BigValue(content: content, size: 38)
            TickBar(fraction: content.soc / 100, colors: ink.dark ? c : [c[0], c[0], c[1]], tick: ink.tick)
                .padding(.top, 8)
        }
        .foregroundStyle(ink.primary)
    }
}

struct MediumCard: View {
    let content: WidgetContent
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let ink = Ink(scheme: scheme)
        let c = content.colors(scheme)
        VStack(alignment: .leading, spacing: 0) {
            Header(content: content, font: .headline)
            Spacer(minLength: 0)
            Text(content.label)
                .font(.subheadline)
                .foregroundStyle(ink.label(c))
            HStack(alignment: .lastTextBaseline) {
                BigValue(content: content, size: 42)
                Spacer()
                if let footnote = content.footnote {
                    Label(footnote, systemImage: "arrow.right.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ink.secondary)
                        .monospacedDigit()
                }
            }
            TickBar(fraction: content.soc / 100, colors: ink.dark ? c : [c[0], c[0], c[1]], tick: ink.tick)
                .padding(.top, 10)
        }
        .foregroundStyle(ink.primary)
    }
}

struct NotConfiguredCard: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let ink = Ink(scheme: scheme)
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "bolt.batteryblock").font(.title2)
            Spacer(minLength: 0)
            Text("Откройте Wattleft и укажите IP станции")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ink.secondary)
        }
        .foregroundStyle(ink.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
