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
                        Button("Later", action: onFinish)
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
        // Явный непрозрачный фон: экран всегда закрывает приложение под собой.
        .background(Color(.systemBackground).ignoresSafeArea())
        .presentationBackground(Color(.systemBackground))
    }
}

// MARK: - Bottom button

private struct BottomButton: ViewModifier {
    let title: LocalizedStringKey
    var disabled = false
    var secondary: (title: LocalizedStringKey, action: () -> Void)?
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
    func bottomButton(_ title: LocalizedStringKey, disabled: Bool = false,
                      secondary: (title: LocalizedStringKey, action: () -> Void)? = nil,
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
                    Text("Shows your Marstek battery’s charge and how long it will last.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 24) {
                    Feature(icon: "chart.xyaxis.line", color: .green,
                            title: "Charge and forecast",
                            text: "A charge chart and the moment the station reaches its reserve.")
                    Feature(icon: "hourglass", color: .orange,
                            title: "Time, not percent",
                            text: "Consumption turned into hours and minutes.")
                    Feature(icon: "lock.iphone", color: .blue,
                            title: "Lock Screen",
                            text: "A timer in the Dynamic Island and on the Lock Screen.")
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .bottomButton("Connect station", secondary: ("See demo", demo), action: next)
    }
}

private struct Feature: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let text: LocalizedStringKey

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
                NumberedRow(n: 1, title: "Open the Marstek app",
                            text: "Your phone and the station must be on the same Wi‑Fi network.")
                NumberedRow(n: 2, title: "Open the station settings",
                            text: "Find Open API — it may be called Local API.")
                NumberedRow(n: 3, title: "Turn it on",
                            text: "Keep port 30000 or note your own.")
            } footer: {
                Text("Works with Venus E, C, A and D. If the option is missing, update the station firmware in the Marstek app.")
            }
        }
        .navigationTitle("Turn on Open API")
        .bottomButton("Next", action: next)
    }
}

private struct FindIPStep: View {
    let next: () -> Void

    var body: some View {
        List {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("In the Marstek app")
                        Text("In the device or network info.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "iphone") }
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("In your router settings")
                        Text("Look for a name like VenusE-… in the device list.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "wifi.router") }
            } header: {
                Text("Where to look")
            } footer: {
                Text("Tip: reserve the IP for the station in your router (DHCP reservation). Otherwise the address may change after a router restart.")
            }
        }
        .navigationTitle("Find the IP address")
        .bottomButton("Next", action: next)
    }
}

private struct NumberedRow: View {
    let n: Int
    let title: LocalizedStringKey
    let text: LocalizedStringKey

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
                TextField("IP address, e.g. 192.168.1.50", text: $host)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onSubmit { Task { await test() } }
                LabeledContent("Port") {
                    TextField("30000", value: $port, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused)
                }
            } footer: {
                Text("iOS will ask for Local Network access — allow it, or the app can’t reach the station.")
            }

            if let ok {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected")
                            Text("\(ok.deviceName ?? String(localized: "Station")) · charge \(Int(ok.socPercent.rounded()))%")
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
                    Text("Check that your phone is on the same Wi‑Fi network, Open API is on, and Local Network access is allowed in iOS Settings → Wattleft.")
                }
            }
        }
        .navigationTitle("Connection")
        .bottomButton(ok == nil ? (testing ? "Checking…" : "Check connection") : "Done",
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
