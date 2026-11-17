import SwiftUI
import WidgetKit

// Виджеты домашнего экрана (светлая и тёмная тема): ровная минималистичная карточка,
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
            icon = "bolt.fill"; title = String(localized: "Charging"); label = String(localized: "Until full")
            value = Self.clock(e?.duration); duration = Self.split(e?.duration)
        case .discharging?:
            icon = "bolt.batteryblock.fill"; title = String(localized: "Discharging"); label = String(localized: "Time left")
            value = Self.clock(e?.duration); duration = Self.split(e?.duration)
        default:
            icon = "pause.fill"; title = String(localized: "Idle"); label = String(localized: "Charge")
            value = "\(Int(entrySoc.rounded()))%"; duration = nil
        }

        if isStale {
            footnote = String(localized: "data is out of date")
        } else if let d = e?.duration, e?.mode != .idle {
            let end = date.addingTimeInterval(d)
            let time = end.formatted(date: .omitted, time: .shortened)
            footnote = Calendar.current.isDateInToday(end) ? String(localized: "until \(time)") : String(localized: "tomorrow \(time)")
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
        if h >= 100 { return String(localized: "99+ h") }
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

/// Фон: ровная заливка без свечения, градиентов и рамки — почти чёрный или тёплый белый.
/// Цвет состояния остаётся только на иконке, подписи и полосе.
struct WidgetBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        scheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.08) : Color(red: 0.985, green: 0.982, blue: 0.975)
    }
}

/// Полоса: сплошная заливка до текущего заряда, дальше — тонкие штрихи.
/// При смене записи виджета заливка плавно растёт (зарядка) или убывает (разрядка),
/// а штрихи открываются или прячутся вслед за ней.
struct TickBar: View {
    let fraction: Double
    let color: Color
    var tick: Color = .white.opacity(0.22)
    /// Направление блика: при зарядке бежит вправо, при разрядке — влево.
    var rising = false

    var body: some View {
        GeometryReader { g in
            let h = g.size.height
            let fill = max(h, g.size.width * min(1, max(0, fraction)))
            ZStack(alignment: .leading) {
                // Штрихи рисуются на всю ширину и открываются маской справа от заливки —
                // так они двигаются вместе с ней, а не перескакивают.
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    while x < size.width - 1 {
                        let r = CGRect(x: x, y: size.height * 0.12, width: 1.6, height: size.height * 0.76)
                        ctx.fill(Path(roundedRect: r, cornerRadius: 0.8), with: .color(tick))
                        x += 4.5
                    }
                }
                .mask(alignment: .leading) {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: min(g.size.width, fill + 5))
                        Color.black
                    }
                }
                Capsule()
                    .fill(color)
                    .overlay {
                        // Блик-«волна» по заливке: появляется заново на каждой записи виджета
                        // (новый id) и пробегает от одного края к другому.
                        GeometryReader { b in
                            Capsule()
                                .fill(.white.opacity(0.55))
                                .frame(width: max(h * 3, b.size.width * 0.35))
                                .blur(radius: 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(Sweep(width: b.size.width, rising: rising))
                                .id(fraction)
                        }
                    }
                    .clipShape(Capsule())
                    .frame(width: fill)
                    .widgetAccentable()
            }
            .animation(.smooth(duration: 0.9), value: fraction)
        }
        .frame(height: 8)
    }
}

/// Переход блика: вставка — пробег от одного края полосы за другой, в покое блик спрятан за краем.
private struct Sweep: Transition {
    let width: CGFloat
    let rising: Bool

    func body(content: Content, phase: TransitionPhase) -> some View {
        let start: CGFloat = rising ? -width * 0.5 : width * 1.2
        let end: CGFloat = rising ? width * 1.2 : -width * 0.5
        content
            .offset(x: phase == .willAppear ? start : end)
            .animation(.easeInOut(duration: 1.1), value: phase)
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
                        + Text("h ", comment: "Hours unit after a big number").font(unit).foregroundStyle(unitColor)
                        + Text("\(d.m)").font(num)
                        + Text("m", comment: "Minutes unit after a big number").font(unit).foregroundStyle(unitColor)
                } else {
                    Text("\(d.m)").font(num)
                        + Text(" min", comment: "Minutes unit after a big number").font(unit).foregroundStyle(unitColor)
                }
            } else {
                Text(content.value)
                    .font(.system(size: size, weight: .semibold, design: .rounded))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .contentTransition(.numericText(value: content.duration.map { Double($0.h * 60 + $0.m) } ?? content.soc))
        .animation(.smooth(duration: 0.9), value: content.soc)
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
            TickBar(fraction: content.soc / 100, color: ink.icon(c), tick: ink.tick, rising: content.mode == .charging)
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
            TickBar(fraction: content.soc / 100, color: ink.icon(c), tick: ink.tick, rising: content.mode == .charging)
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
            Text("Open Wattleft and enter your station IP")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ink.secondary)
        }
        .foregroundStyle(ink.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
