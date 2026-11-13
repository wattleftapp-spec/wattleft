import ActivityKit
import Foundation

/// Данные Live Activity на экране блокировки и в Dynamic Island.
struct MarstekActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var socPercent: Double
        var capacityWh: Double
        var netW: Double
        var updated: Date
        var reservePercent: Double
    }

    var deviceName: String
}

extension MarstekActivityAttributes.ContentState {
    init(snapshot: BatterySnapshot, settings: AppSettings, netW: Double?) {
        self.init(socPercent: snapshot.socPercent, capacityWh: snapshot.capacityWh,
                  netW: netW ?? snapshot.netW, updated: snapshot.date,
                  reservePercent: settings.reservePercent)
    }

    var estimate: BatteryEstimate {
        BatteryEstimate.make(remainingWh: capacityWh * socPercent / 100, capacityWh: capacityWh,
                             reservePercent: reservePercent, netW: netW)
    }

    /// Момент, когда батарея дойдёт до резерва (разряд) или до 100 % (заряд).
    var endDate: Date? {
        estimate.duration.map { updated.addingTimeInterval($0) }
    }

    /// Интервал для «живой» полоски: от условного 100 % (или 0 %) до `endDate`.
    /// Система сама двигает полоску по времени, без обновлений приложения.
    var barInterval: ClosedRange<Date>? {
        guard let end = endDate, end > updated else { return nil }
        let e = estimate
        switch e.mode {
        case .discharging:
            let fullUsableWh = capacityWh * (100 - reservePercent) / 100
            let start = end.addingTimeInterval(-fullUsableWh / e.powerW * 3600)
            return start < end ? start...end : nil
        case .charging:
            let start = end.addingTimeInterval(-capacityWh / e.powerW * 3600)
            return start < end ? start...end : nil
        case .idle:
            return nil
        }
    }
}

enum LiveActivityManager {
    typealias Act = Activity<MarstekActivityAttributes>

    static var isRunning: Bool { !Act.activities.isEmpty }
    static var isAllowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Создаёт Live Activity, если её ещё нет, иначе обновляет. Создать можно только из открытого приложения.
    static func startOrUpdate(snapshot: BatterySnapshot, settings: AppSettings) async throws {
        let state = MarstekActivityAttributes.ContentState(
            snapshot: snapshot, settings: settings, netW: SharedStore.averagedNetW(at: snapshot.date))
        let content = ActivityContent(state: state, staleDate: snapshot.date.addingTimeInterval(30 * 60))
        if Act.activities.isEmpty {
            _ = try Act.request(
                attributes: MarstekActivityAttributes(deviceName: snapshot.deviceName ?? "Marstek"),
                content: content, pushType: nil)
        } else {
            for activity in Act.activities {
                await activity.update(content)
            }
        }
    }

    /// Только обновляет уже запущенную (работает и из фона).
    static func updateIfRunning(snapshot: BatterySnapshot, settings: AppSettings) async {
        guard isRunning else { return }
        try? await startOrUpdate(snapshot: snapshot, settings: settings)
    }

    static func stopAll() async {
        for activity in Act.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
