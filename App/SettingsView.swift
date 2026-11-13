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
                    Toggle("Демо-режим", isOn: $draft.demoMode)
                } footer: {
                    Text("Встроенная имитация станции — чтобы посмотреть приложение без Marstek. Выключите, чтобы подключить свою.")
                }

                Section {
                    TextField("IP-адрес, например 192.168.1.50", text: $draft.host)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    LabeledContent("Порт") {
                        TextField("30000", value: $draft.port, format: .number.grouping(.never))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Станция")
                } footer: {
                    Text("Порт по умолчанию 30000. IP лучше закрепить за станцией в роутере.")
                }

                Section {
                    Stepper("Резерв: \(Int(draft.reservePercent))%", value: $draft.reservePercent, in: 0...50, step: 1)
                    Toggle("Инвертировать знак мощности сети", isOn: $draft.invertGridSign)
                    LabeledContent("Ёмкость, Вт·ч") {
                        TextField("авто", value: $draft.capacityOverrideWh, format: .number.grouping(.never))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Расчёт")
                } footer: {
                    Text("Резерв — заряд, ниже которого станция не разряжается. Ёмкость 0 — брать из станции. Инвертируйте знак, если при разряде приложение показывает «заряжается».")
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
                                testResult = "Связь есть — заряд \(SharedStore.lastSnapshot.map { "\(Int($0.socPercent))%" } ?? "")"
                            }
                        }
                    } label: {
                        HStack {
                            Text("Проверить связь")
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    if let testResult {
                        Label(testResult, systemImage: testOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(testOK ? Color.green : Color.orange)
                    }
                    Button("Как подключить станцию", action: onShowGuide)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        settings = draft
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .onAppear { draft = settings }
        }
    }
}
