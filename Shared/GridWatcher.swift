import Foundation
import UserNotifications

/// Следит, появилось ли питание от городской сети, и шлёт локальное уведомление
/// «Свет дали — станция заряжается», когда сеть вернулась.
///
/// Вызывается после каждого замера — из приложения, фонового обновления, виджета и кнопки «Обновить»,
/// поэтому состояние хранится в общем хранилище App Group, а не в памяти.
enum GridWatcher {
    /// Ниже этой мощности из сети считаем, что сети нет (шум датчика, дежурные потери).
    static let onlineThresholdW: Double = 40

    private static let stateKey = "gridOnline"

    /// nil — состояние ещё ни разу не определяли (первый замер, без уведомления).
    static var lastKnownOnline: Bool? {
        get { SharedStore.defaults.object(forKey: stateKey) as? Bool }
        set { SharedStore.defaults.set(newValue, forKey: stateKey) }
    }

    static func isOnline(_ s: BatterySnapshot) -> Bool {
        (s.gridInW ?? 0) >= onlineThresholdW
    }

    /// Сравнивает с прошлым состоянием и уведомляет при переходе «нет сети → есть сеть».
    static func check(_ snapshot: BatterySnapshot, settings: AppSettings) async {
        let online = isOnline(snapshot)
        let previous = lastKnownOnline
        lastKnownOnline = online
        guard settings.notifyGridReturn, previous == false, online else { return }
        await postGridReturned(snapshot, settings: settings)
    }

    /// Сбросить, чтобы первый замер после смены станции/демо не породил ложное уведомление.
    static func reset() {
        SharedStore.defaults.removeObject(forKey: stateKey)
    }

    static func postGridReturned(_ s: BatterySnapshot, settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let estimate = BatteryEstimate.make(remainingWh: s.remainingWh, capacityWh: s.capacityWh,
                                            reservePercent: settings.reservePercent, netW: s.netW)
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Power is back")
        let soc = Int(s.socPercent.rounded())
        if estimate.mode == .charging, let d = estimate.duration {
            content.body = String(localized: "The station is charging from the grid: \(soc)%, full in \(Fmt.duration(d)).")
        } else {
            content.body = String(localized: "The station is getting power from the grid: \(soc)%.")
        }
        content.sound = .default
        content.threadIdentifier = "grid"
        // Один и тот же идентификатор — новое уведомление заменяет старое, а не копится.
        let request = UNNotificationRequest(identifier: "grid-returned", content: content, trigger: nil)
        try? await center.add(request)
    }

    /// Запросить разрешение на уведомления (один раз; дальше iOS сама помнит ответ).
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        return await center.notificationSettings().authorizationStatus == .authorized
    }
}
