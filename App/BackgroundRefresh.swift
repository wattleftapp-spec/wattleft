import BackgroundTasks
import WidgetKit

/// Фоновое обновление: iOS сама решает когда, обычно раз в 15–30 минут.
/// Обновляет снимок, Live Activity и виджеты, пока приложение закрыто.
enum BackgroundRefresh {
    static let taskID = "app.wattleft.ios.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run() async {
        schedule()
        if let snapshot = try? await BatteryService.refresh(timeout: 4) {
            await LiveActivityManager.updateIfRunning(snapshot: snapshot, settings: SharedStore.settings)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
