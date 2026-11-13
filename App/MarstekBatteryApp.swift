import SwiftUI
import UserNotifications
import WidgetKit

/// Показывать уведомление «Свет дали» и когда приложение открыто.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .list, .sound] }
}

@main
struct MarstekBatteryApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if CommandLine.arguments.contains("-widgetGallery") {
                WidgetGallery()
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { BackgroundRefresh.schedule() }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskID)) {
            await BackgroundRefresh.run()
        }
    }
}

@Observable
@MainActor
final class BatteryViewModel {
    var settings: AppSettings = SharedStore.settings {
        didSet {
            guard settings != oldValue else { return }
            SharedStore.settings = settings
            WidgetCenter.shared.reloadAllTimelines()
            if settings.notifyGridReturn && !oldValue.notifyGridReturn {
                Task { await GridWatcher.requestAuthorization() }
            }
            if settings.demoMode != oldValue.demoMode || settings.host != oldValue.host {
                GridWatcher.reset()
            }
            if settings.demoMode != oldValue.demoMode {
                // Демо и настоящая станция не смешиваются в истории.
                SharedStore.resetData()
                if settings.demoMode { DemoStation.seedHistory(settings: settings) }
                snapshot = SharedStore.lastSnapshot
                history = SharedStore.history
                errorText = nil
                Task { await refresh() }
            }
            if settings.liveActivityEnabled != oldValue.liveActivityEnabled {
                Task { await syncLiveActivity() }
            }
        }
    }
    var snapshot: BatterySnapshot? = SharedStore.lastSnapshot
    var history: [ChargeHistoryPoint] = SharedStore.history
    var errorText: String?
    var liveActivityError: String?
    var isLoading = false
    private var lastWidgetReload = Date.distantPast

    var estimate: BatteryEstimate? {
        guard let snapshot else { return nil }
        return BatteryEstimate.make(remainingWh: snapshot.remainingWh, capacityWh: snapshot.capacityWh,
                                    reservePercent: settings.reservePercent,
                                    netW: SharedStore.averagedNetW() ?? snapshot.netW)
    }

    func refresh() async {
        guard settings.isConfigured else {
            errorText = MarstekError.notConfigured.localizedDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await BatteryService.refresh()
            history = SharedStore.history
            errorText = nil
            await syncLiveActivity()
            if Date().timeIntervalSince(lastWidgetReload) > 60 {
                lastWidgetReload = Date()
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// Включает/обновляет/выключает Live Activity по настройке.
    func syncLiveActivity() async {
        guard settings.liveActivityEnabled else {
            await LiveActivityManager.stopAll()
            liveActivityError = nil
            return
        }
        guard let snapshot else { return }
        guard LiveActivityManager.isAllowed else {
            liveActivityError = String(localized: "Live Activities are off: Settings → Wattleft → Live Activities.")
            return
        }
        do {
            try await LiveActivityManager.startOrUpdate(snapshot: snapshot, settings: settings)
            liveActivityError = nil
        } catch {
            liveActivityError = String(localized: "Couldn’t start the Live Activity: \(error.localizedDescription)")
        }
    }

    /// Пока приложение открыто — опрашиваем станцию каждые 10 секунд.
    func poll() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }
    }
}
