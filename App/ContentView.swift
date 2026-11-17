import SwiftUI
import UserNotifications

struct ContentView: View {
    /// Режим съёмки скриншотов: `-hideDemoBanner` прячет баннер демо и не даёт остальным скрываться (только отладка).
    #if DEBUG
    static let hideDemoBanner = CommandLine.arguments.contains("-hideDemoBanner")
    #else
    static let hideDemoBanner = false
    #endif

    @State private var model = BatteryViewModel()
    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var openGuideAfterSettings = false
    /// Информационные баннеры (без действия), которые уже показались и скрылись сами.
    /// Баннер снова может появиться, только когда его условие пропало и вернулось.
    @State private var dismissedBanners: Set<String> = []
    /// Баннеры, которые прямо сейчас проигрывают анимацию ухода.
    @State private var leavingBanners: Set<String> = []
    @State private var hypotheticalW: Double = 150
    @AppStorage("onboardingDone") private var onboardingDone = false
    @Environment(\.scenePhase) private var scenePhase

    private let presets: [(name: String, icon: String, watts: Double)] = [
        (String(localized: "Router"), "wifi.router", 15),
        (String(localized: "Laptop"), "laptopcomputer", 60),
        (String(localized: "Boiler"), "flame", 120),
        (String(localized: "Fridge"), "refrigerator", 150),
        (String(localized: "TV"), "tv", 200),
        (String(localized: "Heater"), "heater.vertical", 1500),
        (String(localized: "Kettle"), "cup.and.saucer", 2000),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if model.settings.isConfigured {
                    list
                } else {
                    List {
                        Section {
                            VStack(spacing: 14) {
                                InfoBanner(icon: "bolt.slash", title: "No station connected",
                                           message: "Turn on Open API in the Marstek app and enter the station IP address.",
                                           tone: .neutral) { showOnboarding = true }
                                InfoBanner(icon: "play.fill", title: "Try the demo",
                                           message: "See how Wattleft works with a simulated station.",
                                           tone: .info) { model.settings.demoMode = true }
                            }
                        }
                        .bannerRow()
                    }
                    .listSectionSpacing(.custom(32))
                    .contentMargins(.top, 20, for: .scrollContent)
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                }
            }
        }
        // Онбординг открываем только после того, как лист настроек полностью закрылся —
        // иначе полноэкранный экран появляется во время анимации и остаётся прозрачным.
        .sheet(isPresented: $showSettings, onDismiss: {
            if openGuideAfterSettings {
                openGuideAfterSettings = false
                showOnboarding = true
            }
        }) {
            SettingsView(settings: $model.settings,
                         onTest: { await model.refresh() },
                         onShowGuide: {
                             openGuideAfterSettings = true
                             showSettings = false
                         })
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(model: model) {
                onboardingDone = true
                showOnboarding = false
                if model.settings.notifyGridReturn {
                    Task { await GridWatcher.requestAuthorization() }
                }
            }
        }
        .onAppear {
            // Режим съёмки скриншотов: убрать старые уведомления с экрана блокировки.
            if Self.hideDemoBanner { UNUserNotificationCenter.current().removeAllDeliveredNotifications() }
            if !onboardingDone { showOnboarding = true }
            // Для уже настроенных пользователей: спросить разрешение один раз (iOS запомнит ответ).
            if onboardingDone && model.settings.isConfigured && model.settings.notifyGridReturn {
                Task { await GridWatcher.requestAuthorization() }
            }
        }
        .onChange(of: banners.map(\.id)) { _, ids in
            dismissedBanners.formIntersection(ids)
        }
        .task(id: scenePhase) {
            if scenePhase == .active { await model.poll() }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            let shown = banners.filter { !dismissedBanners.contains($0.id) }
            if !shown.isEmpty {
                Section {
                    // Каждый баннер — своя строка: список сам плавно схлопывает место после ухода.
                    ForEach(shown) { item in
                        item.view
                            .bannerLeaving(leavingBanners.contains(item.id))
                            .bannerRow(bottom: item.id == shown.last?.id ? 0 : 14)
                            .task(id: item.id) {
                                // В режиме съёмки скриншотов (-hideDemoBanner) баннеры не прячутся.
                                guard item.autoDismiss, !Self.hideDemoBanner else { return }
                                try? await Task.sleep(for: .seconds(3))
                                guard !Task.isCancelled else { return }
                                await dismissBanner(item.id)
                            }
                    }
                }
            }

            if let s = model.snapshot, let e = model.estimate {
                Section {
                    // Одна строка списка: иначе между шапкой и графиком появляется разделитель.
                    VStack(alignment: .leading, spacing: 24) {
                        summary(s, e)
                        VStack(spacing: 12) {
                            ChargeChart(history: model.history, snapshot: s, estimate: e,
                                        reserve: model.settings.reservePercent)
                                .frame(height: 210)
                            legend
                        }
                    }
                    .padding(.vertical, 10)
                }

                Section("Now") {
                    if let name = s.deviceName {
                        LabeledContent("Station", value: name)
                    }
                    LabeledContent("Output", value: Fmt.watts(s.outputW))
                    LabeledContent("Input", value: Fmt.watts(s.inputW))
                    LabeledContent("Energy", value: String(localized: "\(Fmt.wattHours(s.remainingWh)) of \(Fmt.wattHours(s.capacityWh))"))
                    LabeledContent("Available above reserve", value: Fmt.wattHours(e.usableWh))
                    LabeledContent("Updated") {
                        Text("\(s.date, style: .relative) ago")
                    }
                }

                calculator(e)

                Section {
                    Toggle("Lock Screen", systemImage: "lock.iphone", isOn: $model.settings.liveActivityEnabled)
                } footer: {
                    // Ошибка Live Activity показывается баннером сверху, здесь — только пояснение.
                    Text("Charge and time left on the Lock Screen and in the Dynamic Island. The timer keeps counting even when the app is closed.")
                }
            } else {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Connecting to the station…")
                        Spacer()
                    }
                    .padding(.vertical, 40)
                }
            }
        }
        .listSectionSpacing(.custom(32))
        .contentMargins(.top, 20, for: .scrollContent)
        .refreshable { await model.refresh() }
        .animation(.default, value: model.errorText)
    }

    // MARK: - Banners

    struct BannerItem: Identifiable {
        let id: String
        let view: InfoBanner
        /// Баннер без действия только сообщает — скрываем его сам через 3 секунды.
        var autoDismiss: Bool { view.action == nil }
    }

    /// Все подсказки над карточкой заряда, по важности: ошибки → предупреждения → инфо.
    private var banners: [BannerItem] {
        var items: [BannerItem] = []
        let settings = model.settings

        if let error = model.errorText {
            let age = model.snapshot.map { Text("\n") + Text("Last data \($0.date, style: .relative) ago.") } ?? Text("")
            items.append(.init(id: "error", view: InfoBanner(
                icon: "wifi.exclamationmark", title: "Station isn’t responding",
                message: Text(error) + age, tone: .error) { showSettings = true }))
        }

        if let e = model.estimate, e.mode == .discharging, let d = e.duration, d < 3600 {
            items.append(.init(id: "low", view: InfoBanner(
                icon: "battery.25percent", title: "Almost at reserve",
                message: Text("About \(Fmt.duration(d)) left at the current load. Turn off what you don’t need."),
                tone: .warning)))
        }

        if let s = model.snapshot, GridWatcher.isOnline(s), let e = model.estimate, e.mode == .charging {
            items.append(.init(id: "grid", view: InfoBanner(
                icon: "bolt.fill", title: "Power is back",
                message: Text("Charging from the grid, full in \(Fmt.duration(e.duration)).") ,
                tone: .success)))
        }

        if settings.notifyGridReturn && model.notificationsDenied {
            items.append(.init(id: "notif", view: InfoBanner(
                icon: "bell.slash", title: "Notifications are off",
                message: "You won’t know when power is back. Turn them on in Settings → Wattleft.",
                tone: .warning) { openSystemSettings() }))
        }

        if settings.liveActivityEnabled, let err = model.liveActivityError {
            items.append(.init(id: "live", view: InfoBanner(
                icon: "lock.iphone", title: "Lock Screen timer is off",
                message: Text(err), tone: .warning) { openSystemSettings() }))
        }

        if settings.demoMode && !Self.hideDemoBanner {
            items.append(.init(id: "demo", view: InfoBanner(
                icon: "play.fill", title: "Demo mode",
                message: "The data isn’t real. Tap to connect your own station.",
                tone: .info) {
                    model.settings.demoMode = false
                    showOnboarding = true
                }))
        }
        return items
    }

    /// Два шага: сначала баннер растворяется на месте (размытие, уменьшение, сдвиг вверх),
    /// затем список плавно убирает освободившееся место — без рывков и обрезанных соседей.
    private func dismissBanner(_ id: String) async {
        withAnimation(.bannerExit) { _ = leavingBanners.insert(id) }
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.smooth(duration: 0.35)) {
            _ = dismissedBanners.insert(id)
            _ = leavingBanners.remove(id)
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    // MARK: - Summary

    private func summary(_ s: BatterySnapshot, _ e: BatteryEstimate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            statusLine(e)
            FlowingGradientText(
                text: "\(Int(s.socPercent.rounded()))%",
                font: .system(size: 64, weight: .bold, design: .rounded),
                flow: e.mode == .charging ? .charging : e.mode == .discharging ? .discharging : .idle
            )
            .contentTransition(.numericText(value: s.socPercent))
            headline(e)
                .font(.title3.weight(.semibold))
                .contentTransition(.numericText())
        }
        .animation(.smooth(duration: 0.3), value: s.socPercent)
        .animation(.smooth(duration: 0.3), value: e.duration.map { Int($0 / 60) })
    }

    /// «● Разряд · 276 Вт» — контекст к цифре.
    private func statusLine(_ e: BatteryEstimate) -> some View {
        let (title, color): (String, Color) = switch e.mode {
        case .discharging: (String(localized: "Discharging"), FlowingGradientText.dischargingLight[1])
        case .charging: (String(localized: "Charging"), FlowingGradientText.chargingLight[1])
        case .idle: (String(localized: "Idle"), .gray)
        }
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
            if e.mode != .idle {
                Text("·").foregroundStyle(.tertiary)
                Text(Fmt.watts(e.powerW)).monospacedDigit()
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
    }

    /// Длительность — главное; время окончания показано на графике.
    private func headline(_ e: BatteryEstimate) -> Text {
        switch e.mode {
        case .discharging:
            return Text("Lasts ", comment: "Followed by a duration, e.g. Lasts 5 h 20 min").foregroundStyle(.secondary) + Text(Fmt.duration(e.duration))
        case .charging:
            return Text("Full in ", comment: "Followed by a duration").foregroundStyle(.secondary) + Text(Fmt.duration(e.duration))
        case .idle:
            return Text("In reserve ", comment: "Followed by energy, e.g. In reserve 3.2 kWh").foregroundStyle(.secondary) + Text(Fmt.wattHours(e.usableWh))
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(String(localized: "history", comment: "Chart legend"), dashed: false)
            legendItem(String(localized: "forecast", comment: "Chart legend"), dashed: true)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ title: String, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Path { p in
                p.move(to: CGPoint(x: 1, y: 1))
                p.addLine(to: CGPoint(x: 17, y: 1))
            }
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: dashed ? [2, 4] : []))
            .frame(width: 18, height: 2)
            Text(title)
        }
    }

    /// «21:14», «завтра 09:10» или «14 нояб. 09:10».
    static func clock(_ date: Date) -> String {
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date) { return time }
        if cal.isDateInTomorrow(date) { return String(localized: "tomorrow \(time)") }
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    // MARK: - Calculator

    private func calculator(_ e: BatteryEstimate) -> some View {
        Section {
            Menu {
                ForEach(presets, id: \.name) { p in
                    Button("\(p.name) — \(Fmt.watts(p.watts))", systemImage: p.icon) {
                        withAnimation { hypotheticalW = p.watts }
                    }
                }
            } label: {
                LabeledContent("Appliance") {
                    HStack(spacing: 4) {
                        Text(presets.first { $0.watts == hypotheticalW }?.name ?? String(localized: "Custom power"))
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                }
            }
            .tint(.primary)

            VStack(alignment: .leading) {
                LabeledContent("Power", value: Fmt.watts(hypotheticalW))
                // Без `step:` — иначе iOS рисует под ползунком шкалу из 600 делений.
                Slider(value: Binding(get: { hypotheticalW },
                                      set: { hypotheticalW = max(5, ($0 / 5).rounded() * 5) }),
                       in: 5...3000) {
                    Text("Power")
                } minimumValueLabel: {
                    Image(systemName: "powerplug").font(.caption).foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Image(systemName: "bolt.fill").font(.caption).foregroundStyle(.secondary)
                }
            }

            LabeledContent("Lasts") {
                Text(Fmt.duration(BatteryEstimate.runtime(usableWh: e.usableWh, loadW: hypotheticalW)))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
        } header: {
            Text("What if I plug in")
        } footer: {
            Text("Based on the energy above the reserve. The inverter loses 5–10%, so the real time will be a bit shorter.")
        }
    }
}
