import SwiftUI

/// Первый запуск: что умеет приложение и как подключить свою станцию Marstek.
/// Обычный навигационный стек с системными экранами — как настройка в приложениях Apple.
struct OnboardingView: View {
    @Bindable var model: BatteryViewModel
    var onFinish: () -> Void

    enum Step: Hashable { case enableAPI, findIP, connect }

    /// Демо без станции — для знакомства с приложением (и для проверки в App Store).
    private func startDemo() {
        var s = model.settings
        s.demoMode = true
        model.settings = s   // история и первый замер — в BatteryViewModel
        onFinish()
    }
    @State private var path: [Step] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeStep(next: { path.append(.enableAPI) }, demo: startDemo)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Позже", action: onFinish)
                    }
                }
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .enableAPI: EnableAPIStep { path.append(.findIP) }
                    case .findIP: FindIPStep { path.append(.connect) }
                    case .connect: ConnectStep(model: model, onFinish: onFinish)
                    }
                }
        }
    }
}

// MARK: - Bottom button

private struct BottomButton: ViewModifier {
    let title: String
    var disabled = false
    var secondary: (title: String, action: () -> Void)?
    let action: () -> Void

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button(action: action) {
                    Text(title).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(disabled)
                if let secondary {
                    Button(secondary.title, action: secondary.action)
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}

private extension View {
    func bottomButton(_ title: String, disabled: Bool = false,
                      secondary: (title: String, action: () -> Void)? = nil,
                      action: @escaping () -> Void) -> some View {
        modifier(BottomButton(title: title, disabled: disabled, secondary: secondary, action: action))
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    let next: () -> Void
    let demo: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                VStack(spacing: 14) {
                    Image(systemName: "bolt.batteryblock.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .symbolRenderingMode(.hierarchical)
                    Text("Wattleft")
                        .font(.largeTitle.bold())
                    Text("Показывает заряд станции Marstek и сколько он ещё продержится.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 24) {
                    Feature(icon: "chart.xyaxis.line", color: .green,
                            title: "Заряд и прогноз",
                            text: "График заряда и момент, когда станция дойдёт до резерва.")
                    Feature(icon: "hourglass", color: .orange,
                            title: "Время, а не проценты",
                            text: "Потребление переводится в часы и минуты.")
                    Feature(icon: "lock.iphone", color: .blue,
                            title: "Экран блокировки",
                            text: "Таймер в Dynamic Island и на экране блокировки.")
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .bottomButton("Подключить станцию", secondary: ("Посмотреть демо", demo), action: next)
    }
}

private struct Feature: View {
    let icon: String
    let color: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Steps

private struct EnableAPIStep: View {
    let next: () -> Void

    var body: some View {
        List {
            Section {
                NumberedRow(n: 1, title: "Откройте приложение Marstek",
                            text: "Телефон и станция должны быть в одной Wi-Fi сети.")
                NumberedRow(n: 2, title: "Откройте настройки станции",
                            text: "Найдите пункт Open API — он может называться Local API.")
                NumberedRow(n: 3, title: "Включите его",
                            text: "Порт оставьте 30000 или запомните свой.")
            } footer: {
                Text("Подходят Venus E, C, A и D. Если пункта нет — обновите прошивку станции в приложении Marstek.")
            }
        }
        .navigationTitle("Включите Open API")
        .bottomButton("Дальше", action: next)
    }
}

private struct FindIPStep: View {
    let next: () -> Void

    var body: some View {
        List {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("В приложении Marstek")
                        Text("В информации об устройстве или сети.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "iphone") }
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("В настройках роутера")
                        Text("В списке устройств ищите имя вроде VenusE-…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "wifi.router") }
            } header: {
                Text("Где посмотреть")
            } footer: {
                Text("Совет: закрепите IP за станцией в роутере (резервирование DHCP). Иначе адрес может смениться после перезагрузки роутера.")
            }
        }
        .navigationTitle("Найдите IP-адрес")
        .bottomButton("Дальше", action: next)
    }
}

private struct NumberedRow: View {
    let n: Int
    let title: String
    let text: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "\(n).circle.fill")
                .foregroundStyle(.tint)
                .font(.title3)
        }
    }
}

private struct ConnectStep: View {
    @Bindable var model: BatteryViewModel
    let onFinish: () -> Void

    @State private var host = ""
    @State private var port = 30000
    @State private var testing = false
    @State private var ok: BatterySnapshot?
    @State private var failure: String?
    @FocusState private var focused: Bool

    var body: some View {
        Form {
            Section {
                TextField("IP-адрес, например 192.168.1.50", text: $host)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onSubmit { Task { await test() } }
                LabeledContent("Порт") {
                    TextField("30000", value: $port, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused)
                }
            } footer: {
                Text("iOS попросит доступ к локальной сети — разрешите его, иначе связи не будет.")
            }

            if let ok {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Связь есть")
                            Text("\(ok.deviceName ?? "Станция") · заряд \(Int(ok.socPercent.rounded()))%")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            } else if let failure {
                Section {
                    Label(failure, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } footer: {
                    Text("Проверьте: телефон в той же Wi-Fi сети, Open API включён, доступ к локальной сети разрешён в Настройках iOS → Wattleft.")
                }
            }
        }
        .navigationTitle("Подключение")
        .bottomButton(ok == nil ? (testing ? "Проверяем…" : "Проверить связь") : "Готово",
                      disabled: testing || host.trimmingCharacters(in: .whitespaces).isEmpty) {
            if ok != nil { onFinish() } else { Task { await test() } }
        }
        .onAppear {
            host = model.settings.host
            port = model.settings.port
        }
        .onChange(of: host) { ok = nil; failure = nil }
    }

    private func test() async {
        focused = false
        var s = model.settings
        s.host = host.trimmingCharacters(in: .whitespaces)
        s.port = port
        model.settings = s
        testing = true
        defer { testing = false }
        await model.refresh()
        withAnimation {
            if let error = model.errorText {
                failure = error
                ok = nil
            } else {
                ok = model.snapshot
                failure = nil
            }
        }
    }
}
