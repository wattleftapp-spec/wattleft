#if DEBUG
import SwiftUI

/// Витрина карточек виджетов во всех вариантах — для скриншотов и проверки дизайна.
/// Открывается при запуске с аргументом `-widgetGallery`.
struct WidgetGallery: View {
    /// Размеры виджетов iPhone 17 Pro.
    private let small = CGSize(width: 170, height: 170)
    private let medium = CGSize(width: 364, height: 170)

    private func content(_ mode: BatteryEstimate.Mode, soc: Double, hours: Double, power: Double) -> WidgetContent {
        let e = BatteryEstimate(mode: mode, duration: hours * 3600, usableWh: 0, powerW: power)
        return WidgetContent(estimate: e, soc: soc, date: Date(), isStale: false)
    }

    /// Шаг «записи» виджета: с `-animateWidgets` меняется каждые 2 с, чтобы увидеть анимацию полосы.
    @State private var step = 0
    private let animate = ProcessInfo.processInfo.arguments.contains("-animateWidgets")

    var body: some View {
        let k = Double(step % 4)
        let discharging = content(.discharging, soc: 77 - k * 12, hours: 10.5 - k * 1.6, power: 320)
        let charging = content(.charging, soc: 46 + k * 14, hours: 3.4 - k * 0.8, power: 410)

        ScrollView {
            VStack(spacing: 14) {
                card(discharging, size: medium)
                card(charging, size: medium)
                HStack(spacing: 14) {
                    card(discharging, size: small)
                    card(charging, size: small)
                }
            }
            .padding(.vertical, 70)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(colors: [Color(red: 0.55, green: 0.75, blue: 0.95), Color(red: 0.35, green: 0.80, blue: 0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        )
        .task {
            guard animate else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                step += 1
            }
        }
    }

    @ViewBuilder
    private func card(_ c: WidgetContent, size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        Group {
            WidgetCard(content: c)
        }
        .padding(16)
        .frame(width: size.width, height: size.height)
        .background(WidgetBackground())
        .clipShape(shape)
    }
}

/// Витрина всех баннеров — для проверки дизайна. Запуск с `-bannerGallery`.
struct BannerGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                InfoBanner(icon: "bolt.slash", title: "No station connected",
                           message: "Turn on Open API in the Marstek app and enter the station IP address.",
                           tone: .neutral) {}
                InfoBanner(icon: "play.fill", title: "Try the demo",
                           message: "See how Wattleft works with a simulated station.", tone: .info) {}
                InfoBanner(icon: "play.fill", title: "Demo mode",
                           message: "The data isn’t real. Tap to connect your own station.", tone: .info) {}
                InfoBanner(icon: "wifi.exclamationmark", title: "Station isn’t responding",
                           message: Text(MarstekError.timeout.localizedDescription), tone: .error) {}
                InfoBanner(icon: "battery.25percent", title: "Almost at reserve",
                           message: Text("About \(Fmt.duration(2_400)) left at the current load. Turn off what you don’t need."),
                           tone: .warning)
                InfoBanner(icon: "bolt.fill", title: "Power is back",
                           message: Text("Charging from the grid, full in \(Fmt.duration(9_000))."), tone: .success)
                InfoBanner(icon: "bell.slash", title: "Notifications are off",
                           message: "You won’t know when power is back. Turn them on in Settings → Wattleft.",
                           tone: .warning) {}
                InfoBanner(icon: "lock.iphone", title: "Lock Screen timer is off",
                           message: Text("Live Activities are off: Settings → Wattleft → Live Activities."), tone: .warning) {}
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 60)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
#endif
