import SwiftUI

struct ContentView: View {
    @State private var model = BatteryViewModel()
    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var hypotheticalW: Double = 150
    @AppStorage("onboardingDone") private var onboardingDone = false
    @Environment(\.scenePhase) private var scenePhase

    private let presets: [(name: String, icon: String, watts: Double)] = [
        ("Роутер", "wifi.router", 15),
        ("Ноутбук", "laptopcomputer", 60),
        ("Котёл", "flame", 120),
        ("Холодильник", "refrigerator", 150),
        ("Телевизор", "tv", 200),
        ("Обогреватель", "heater.vertical", 1500),
        ("Чайник", "cup.and.saucer", 2000),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if model.settings.isConfigured {
                    list
                } else {
                    ContentUnavailableView {
                        Label("Станция не подключена", systemImage: "bolt.slash")
                    } description: {
                        Text("Включите Open API в приложении Marstek и укажите IP-адрес станции.")
                    } actions: {
                        Button("Подключить") { showOnboarding = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Настройки", systemImage: "gearshape") { showSettings = true }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: $model.settings,
                         onTest: { await model.refresh() },
                         onShowGuide: {
                             showSettings = false
                             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showOnboarding = true }
                         })
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(model: model) {
                onboardingDone = true
                showOnboarding = false
            }
        }
        .onAppear {
            if !onboardingDone { showOnboarding = true }
        }
        .task(id: scenePhase) {
            if scenePhase == .active { await model.poll() }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            if model.settings.demoMode {
                Section {
                    HStack {
                        Label("Демо-режим — данные не настоящие", systemImage: "play.circle")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Подключить") {
                            model.settings.demoMode = false
                            showOnboarding = true
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
            }
            if let error = model.errorText {
                Section {
                    Label(error, systemImage: "wifi.exclamationmark")
                        .foregroundStyle(.orange)
                        .font(.footnote)
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

                Section("Сейчас") {
                    if let name = s.deviceName {
                        LabeledContent("Станция", value: name)
                    }
                    LabeledContent("Отдаёт", value: Fmt.watts(s.outputW))
                    LabeledContent("Получает", value: Fmt.watts(s.inputW))
                    LabeledContent("Энергия", value: "\(Fmt.wattHours(s.remainingWh)) из \(Fmt.wattHours(s.capacityWh))")
                    LabeledContent("Доступно до резерва", value: Fmt.wattHours(e.usableWh))
                    LabeledContent("Обновлено") {
                        Text(s.date, style: .relative) + Text(" назад")
                    }
                }

                calculator(e)

                Section {
                    Toggle("Экран блокировки", systemImage: "lock.iphone", isOn: $model.settings.liveActivityEnabled)
                } footer: {
                    Text(model.liveActivityError
                         ?? "Заряд и оставшееся время на экране блокировки и в Dynamic Island. Таймер идёт сам, даже когда приложение закрыто.")
                }
            } else {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Связываемся со станцией…")
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
        case .discharging: ("Разряд", FlowingGradientText.dischargingLight[1])
        case .charging: ("Заряд", FlowingGradientText.chargingLight[1])
        case .idle: ("Простой", .gray)
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
            return Text("Хватит на ").foregroundStyle(.secondary) + Text(Fmt.duration(e.duration))
        case .charging:
            return Text("До полной ").foregroundStyle(.secondary) + Text(Fmt.duration(e.duration))
        case .idle:
            return Text("В запасе ").foregroundStyle(.secondary) + Text(Fmt.wattHours(e.usableWh))
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem("было", dashed: false)
            legendItem("прогноз", dashed: true)
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
        if cal.isDateInTomorrow(date) { return "завтра \(time)" }
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    // MARK: - Calculator

    private func calculator(_ e: BatteryEstimate) -> some View {
        Section {
            Menu {
                ForEach(presets, id: \.name) { p in
                    Button("\(p.name) — \(Int(p.watts)) Вт", systemImage: p.icon) {
                        withAnimation { hypotheticalW = p.watts }
                    }
                }
            } label: {
                LabeledContent("Прибор") {
                    HStack(spacing: 4) {
                        Text(presets.first { $0.watts == hypotheticalW }?.name ?? "Своя мощность")
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                }
            }
            .tint(.primary)

            VStack(alignment: .leading) {
                LabeledContent("Мощность", value: Fmt.watts(hypotheticalW))
                // Без `step:` — иначе iOS рисует под ползунком шкалу из 600 делений.
                Slider(value: Binding(get: { hypotheticalW },
                                      set: { hypotheticalW = max(5, ($0 / 5).rounded() * 5) }),
                       in: 5...3000) {
                    Text("Мощность")
                } minimumValueLabel: {
                    Image(systemName: "powerplug").font(.caption).foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Image(systemName: "bolt.fill").font(.caption).foregroundStyle(.secondary)
                }
            }

            LabeledContent("Хватит на") {
                Text(Fmt.duration(BatteryEstimate.runtime(usableWh: e.usableWh, loadW: hypotheticalW)))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
        } header: {
            Text("Если подключить")
        } footer: {
            Text("Считается от энергии выше резерва. Инвертор теряет 5–10%, реальное время будет чуть меньше.")
        }
    }
}
