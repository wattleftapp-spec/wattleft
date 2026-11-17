import SwiftUI
import WidgetKit

// Виджеты домашнего экрана (светлая и тёмная тема): ровная минималистичная карточка —
// подпись, крупное значение, полоса со штрихами на пустой части и строка с процентом.

/// Что показывать в карточке — общее для маленького и среднего размера.
struct WidgetContent {
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
            label = String(localized: "Until full")
            value = Self.clock(e?.duration); duration = Self.split(e?.duration)
        case .discharging?:
            label = String(localized: "Time left")
            value = Self.clock(e?.duration); duration = Self.split(e?.duration)
        default:
            label = String(localized: "Charge")
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
                    .frame(width: fill)
                    .widgetAccentable()
            }
            .animation(.smooth(duration: 0.9), value: fraction)
        }
        .frame(height: 8)
    }
}

/// Размеры шрифтов — как у виджета «Календарь»: короткая подпись цветом сверху,
/// крупное число (жирное, скруглённое — как процент на главном экране) и мелкая вторичная строка внизу.
enum WidgetType {
    static let label = Font.system(size: 12, weight: .semibold)
    static let value: CGFloat = 40
    static let footnote = Font.system(size: 13)
}

/// «10ч 47м»: цифры крупно, единицы вдвое мельче и приглушённее — не путается со временем на часах.
struct BigValue: View {
    let content: WidgetContent
    var size: CGFloat = WidgetType.value
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let d = content.duration {
                let unitColor = Ink(scheme: scheme).unit
                let unit = Font.system(size: size * 0.5, weight: .bold, design: .rounded)
                let num = Font.system(size: size, weight: .bold, design: .rounded)
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
                    .font(.system(size: size, weight: .bold, design: .rounded))
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

/// Карточка виджета — одна для малого и среднего размера: подпись, время, полоса и строка
/// «77 % · до 21:40». Без иконок и заголовков: цвет подписи и полосы уже говорит, заряд это или разряд.
struct WidgetCard: View {
    let content: WidgetContent
    @Environment(\.colorScheme) private var scheme

    private var footnote: String? {
        guard content.duration != nil else { return content.footnote }
        let soc = "\(Int(content.soc.rounded()))%"
        return content.footnote.map { "\(soc) · \($0)" } ?? soc
    }

    var body: some View {
        let ink = Ink(scheme: scheme)
        let c = content.colors(scheme)
        VStack(alignment: .leading, spacing: 0) {
            Text(content.label)
                .font(WidgetType.label)
                .textCase(.uppercase)
                .foregroundStyle(ink.label(c))
                .widgetAccentable()
            BigValue(content: content)
            Spacer(minLength: 0)
            TickBar(fraction: content.soc / 100, color: ink.icon(c), tick: ink.tick)
            if let footnote {
                Text(footnote)
                    .font(WidgetType.footnote)
                    .foregroundStyle(ink.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 6)
            }
        }
        .foregroundStyle(ink.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
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
