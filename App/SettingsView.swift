import SwiftUI

struct SettingsView: View {
    @Binding var settings: AppSettings
    var onTest: () async -> Void
    var onShowGuide: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = AppSettings()
    @State private var testResult: String?
    @State private var testOK = false
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Demo mode", isOn: $draft.demoMode)
                } footer: {
                    Text("A built-in simulated station, to try the app without a Marstek battery. Turn it off to connect your own.")
                }

                Section {
                    TextField("IP address, e.g. 192.168.1.50", text: $draft.host)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    LabeledContent("Port") {
                        TextField("30000", value: $draft.port, format: .number.grouping(.never))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Station")
                } footer: {
                    Text("The default port is 30000. It’s best to reserve the station’s IP in your router.")
                }

                Section {
                    Toggle("When grid power returns", isOn: $draft.notifyGridReturn)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("A notification when the station starts charging from the grid. iOS lets the app check the station every 15–30 minutes in the background, so it may arrive with a delay.")
                }

                Section {
                    Stepper("Reserve: \(Int(draft.reservePercent))%", value: $draft.reservePercent, in: 0...50, step: 1)
                    Toggle("Invert grid power sign", isOn: $draft.invertGridSign)
                    LabeledContent("Capacity, Wh") {
                        TextField("auto", value: $draft.capacityOverrideWh, format: .number.grouping(.never))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Calculation")
                } footer: {
                    Text("Reserve is the charge the station won’t discharge below. Capacity 0 means read it from the station. Invert the sign if the app shows “Charging” while the station discharges.")
                }

                Section {
                    Button {
                        Task {
                            testing = true
                            settings = draft
                            await onTest()
                            testing = false
                            if let err = SharedStore.lastError {
                                testOK = false
                                testResult = err
                            } else {
                                testOK = true
                                let soc = SharedStore.lastSnapshot.map { "\(Int($0.socPercent))%" } ?? ""
                                testResult = String(localized: "Connected — charge \(soc)")
                            }
                        }
                    } label: {
                        HStack {
                            Text("Check connection")
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    if let testResult {
                        Label(testResult, systemImage: testOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(testOK ? Color.green : Color.orange)
                    }
                    Button("How to connect a station", action: onShowGuide)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settings = draft
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { draft = settings }
        }
    }
}
