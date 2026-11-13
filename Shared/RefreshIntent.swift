import AppIntents
import WidgetKit

/// Кнопка «обновить» на виджете и в Live Activity.
/// `LiveActivityIntent` выполняется в процессе приложения, поэтому может обновить Live Activity.
struct RefreshBatteryIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Refresh battery charge"
    static var description = IntentDescription("Requests the current charge from the station.")

    func perform() async throws -> some IntentResult {
        if let snapshot = try? await BatteryService.refresh(timeout: 4) {
            await LiveActivityManager.updateIfRunning(snapshot: snapshot, settings: SharedStore.settings)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
