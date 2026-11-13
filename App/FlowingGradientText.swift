import SwiftUI

/// Текст, залитый бесконечно переливающимся градиентом.
/// Заряд — зелёно-бирюзовый, течёт вверх; разряд — тёплый, течёт вниз; простой — обычный цвет.
struct FlowingGradientText: View {
    enum Flow { case charging, discharging, idle }

    let text: String
    let font: Font
    let flow: Flow
    /// Секунд на один полный цикл.
    var period: Double = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.colorScheme) private var scheme

    static let chargingLight = BatteryPalette.chargingLight
    static let chargingDark = BatteryPalette.chargingDark
    static let dischargingLight = BatteryPalette.dischargingLight
    static let dischargingDark = BatteryPalette.dischargingDark

    private var colors: [Color]? {
        let dark = scheme == .dark
        switch flow {
        case .charging: return dark ? Self.chargingDark : Self.chargingLight
        case .discharging: return dark ? Self.dischargingDark : Self.dischargingLight
        case .idle: return nil
        }
    }

    var body: some View {
        let label = Text(text).font(font).monospacedDigit()

        if let colors {
            label
                .foregroundStyle(.clear)
                .overlay {
                    TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { ctx in
                        let time = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                        if #available(iOS 18.0, *) {
                            mesh(colors, time: time)
                        } else {
                            gradient(colors, phase: (time / period).truncatingRemainder(dividingBy: 1))
                        }
                    }
                    .mask(label)
                }
                .animation(.easeInOut(duration: 0.6), value: flow)
        } else {
            label.foregroundStyle(.primary)
        }
    }

    /// Сетка 3×3: углы закреплены, остальные точки медленно плавают по синусоидам с разными
    /// периодами — цвета перетекают облаками, движение непрерывное и никогда не «прыгает».
    @available(iOS 18.0, *)
    private func mesh(_ colors: [Color], time: Double) -> some View {
        // Углы считаем в Double: время с 2001 года слишком велико для точности Float.
        let t = time * 2 * .pi / period   // ~один оборот за `period` секунд
        func wave(_ k: Double, _ shift: Double, cosine: Bool = false) -> Float {
            Float(cosine ? cos(t * k + shift) : sin(t * k + shift))
        }
        // Заряд — облака чуть тянутся вверх, разряд — вниз.
        let lift: Float = flow == .charging ? -0.06 : 0.06
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5 + 0.30 * wave(0.7, 0), 0], [1, 0],
            [0, 0.5 + 0.30 * wave(0.9, 1.0)],
            [0.5 + 0.22 * wave(0.8, 2.0), 0.5 + lift + 0.22 * wave(0.6, 0, cosine: true)],
            [1, 0.5 + 0.30 * wave(0.75, 0.5, cosine: true)],
            [0, 1], [0.5 + 0.30 * wave(0.65, 1.5, cosine: true), 1], [1, 1],
        ]
        // 0 — тёмная, 1 — средняя, 2 — светлая ступень. Свет сверху, тень снизу.
        let d = colors[0], m = colors[1], l = colors[2]
        return MeshGradient(
            width: 3, height: 3,
            points: points,
            colors: [m, l, m,
                     d, l, m,
                     d, m, d],
            smoothsColors: true
        )
    }

    /// Запасной вариант для iOS 17: полоса из двух повторов палитры, сдвигаемая на одну длину цикла — поэтому петля бесшовная.
    private func gradient(_ colors: [Color], phase: Double) -> some View {
        GeometryReader { g in
            let cycle = g.size.height * 1.6
            let stops = colors + colors + [colors[0]]
            let y = flow == .charging ? -phase * cycle : -cycle + phase * cycle
            LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
                .frame(width: g.size.width, height: cycle * 2)
                .offset(y: y)
        }
    }
}
