import Foundation

/// Настройки, общие для приложения и виджета (хранятся в App Group).
struct AppSettings: Codable, Equatable {
    var host: String = ""
    var port: Int = 30000
    /// Нижний порог разряда (станция обычно не уходит ниже 10–11 %).
    var reservePercent: Double = 10
    /// Если станция считает знак мощности наоборот.
    var invertGridSign: Bool = false
    /// Ручная ёмкость, Wh (0 — брать из станции).
    var capacityOverrideWh: Double = 0
    /// Показывать Live Activity на экране блокировки.
    var liveActivityEnabled: Bool = true
    /// Демо-режим: встроенная имитация станции — чтобы посмотреть приложение без Marstek.
    var demoMode: Bool = false

    var isConfigured: Bool { demoMode || !host.trimmingCharacters(in: .whitespaces).isEmpty }

    init(host: String = "") { self.host = host }

    // Терпим отсутствующие ключи, чтобы старые сохранённые настройки не сбрасывались.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        host = try c.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try c.decodeIfPresent(Int.self, forKey: .port) ?? 30000
        reservePercent = try c.decodeIfPresent(Double.self, forKey: .reservePercent) ?? 10
        invertGridSign = try c.decodeIfPresent(Bool.self, forKey: .invertGridSign) ?? false
        capacityOverrideWh = try c.decodeIfPresent(Double.self, forKey: .capacityOverrideWh) ?? 0
        liveActivityEnabled = try c.decodeIfPresent(Bool.self, forKey: .liveActivityEnabled) ?? true
        demoMode = try c.decodeIfPresent(Bool.self, forKey: .demoMode) ?? false
    }
}

/// Один замер станции.
struct BatterySnapshot: Codable, Equatable {
    var date: Date
    var socPercent: Double
    var capacityWh: Double
    /// Сколько станция отдаёт потребителям, W.
    var outputW: Double
    /// Сколько приходит в станцию (сеть/солнце), W.
    var inputW: Double
    var deviceName: String?

    var remainingWh: Double { capacityWh * socPercent / 100 }
    /// > 0 — батарея разряжается, < 0 — заряжается.
    var netW: Double { outputW - inputW }

    static let sample = BatterySnapshot(
        date: Date(), socPercent: 72, capacityWh: 5120,
        outputW: 340, inputW: 0, deviceName: "VenusE"
    )
}

struct ChargeHistoryPoint: Codable, Equatable {
    let date: Date
    let soc: Double
}

/// Сколько времени осталось.
struct BatteryEstimate: Equatable {
    enum Mode: Equatable { case discharging, charging, idle }

    let mode: Mode
    /// Разряд — до порога резерва; заряд — до 100 %.
    let duration: TimeInterval?
    let usableWh: Double
    let powerW: Double

    static let idleThresholdW: Double = 5

    static func make(remainingWh: Double, capacityWh: Double, reservePercent: Double, netW: Double) -> BatteryEstimate {
        let reserveWh = capacityWh * reservePercent / 100
        let usable = max(0, remainingWh - reserveWh)
        if netW > idleThresholdW {
            return .init(mode: .discharging, duration: usable / netW * 3600, usableWh: usable, powerW: netW)
        } else if netW < -idleThresholdW {
            let toFull = max(0, capacityWh - remainingWh)
            return .init(mode: .charging, duration: toFull / -netW * 3600, usableWh: usable, powerW: -netW)
        }
        return .init(mode: .idle, duration: nil, usableWh: usable, powerW: 0)
    }

    /// «Если подключить X Вт — на сколько хватит».
    static func runtime(usableWh: Double, loadW: Double) -> TimeInterval? {
        guard loadW > 0 else { return nil }
        return usableWh / loadW * 3600
    }
}

/// Хранилище в App Group, доступное приложению и виджету.
enum SharedStore {
    static let groupID = "group.app.wattleft.ios"
    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }

    private static let settingsKey = "settings"
    private static let snapshotKey = "lastSnapshot"
    private static let samplesKey = "samples"
    private static let errorKey = "lastError"

    static var settings: AppSettings {
        get { load(settingsKey) ?? AppSettings() }
        set { save(newValue, settingsKey) }
    }

    static var lastSnapshot: BatterySnapshot? {
        get { load(snapshotKey) }
        set { save(newValue, snapshotKey) }
    }

    static var lastError: String? {
        get { defaults.string(forKey: errorKey) }
        set { defaults.set(newValue, forKey: errorKey) }
    }

    private struct Sample: Codable { let date: Date; let netW: Double }
    private static let historyKey = "chargeHistory"

    /// История заряда за последние сутки (точка не чаще раза в минуту) — для графика.
    static var history: [ChargeHistoryPoint] {
        load(historyKey) ?? []
    }

    /// Сбросить замеры и историю (при переключении между демо и настоящей станцией).
    static func resetData() {
        lastSnapshot = nil
        lastError = nil
        defaults.removeObject(forKey: samplesKey)
        defaults.removeObject(forKey: historyKey)
    }

    /// Сохраняет замер и копит историю для сглаживания потребления.
    static func record(_ snapshot: BatterySnapshot) {
        lastSnapshot = snapshot
        lastError = nil
        var points = history
        if let last = points.last, snapshot.date.timeIntervalSince(last.date) < 60 {
            points[points.count - 1] = ChargeHistoryPoint(date: last.date, soc: snapshot.socPercent)
        } else {
            points.append(ChargeHistoryPoint(date: snapshot.date, soc: snapshot.socPercent))
        }
        let dayAgo = snapshot.date.addingTimeInterval(-24 * 3600)
        save(points.filter { $0.date >= dayAgo }, historyKey)

        var samples: [Sample] = load(samplesKey) ?? []
        samples.append(Sample(date: snapshot.date, netW: snapshot.netW))
        let cutoff = snapshot.date.addingTimeInterval(-15 * 60)
        samples = Array(samples.filter { $0.date >= cutoff }.suffix(100))
        save(samples, samplesKey)
    }

    /// Среднее потребление за последние 10 минут — чтобы прогноз не прыгал от скачков нагрузки.
    static func averagedNetW(at now: Date = Date()) -> Double? {
        let samples: [Sample] = load(samplesKey) ?? []
        let recent = samples.filter { now.timeIntervalSince($0.date) <= 10 * 60 }
        guard !recent.isEmpty else { return nil }
        return recent.map(\.netW).reduce(0, +) / Double(recent.count)
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

enum BatteryService {
    /// Запрашивает станцию и сохраняет результат в общее хранилище.
    @discardableResult
    static func refresh(timeout: TimeInterval = 3) async throws -> BatterySnapshot {
        let settings = SharedStore.settings
        guard settings.isConfigured else { throw MarstekError.notConfigured }
        if settings.demoMode {
            let snapshot = DemoStation.snapshot(at: Date(), settings: settings)
            SharedStore.record(snapshot)
            return snapshot
        }
        let client = MarstekClient(
            host: settings.host.trimmingCharacters(in: .whitespaces),
            port: UInt16(clamping: settings.port),
            timeout: timeout
        )
        do {
            let snapshot = try await client.fetchSnapshot(settings: settings)
            SharedStore.record(snapshot)
            return snapshot
        } catch {
            SharedStore.lastError = error.localizedDescription
            throw error
        }
    }
}

enum Fmt {
    static func duration(_ t: TimeInterval?) -> String {
        guard let t, t.isFinite, t >= 0 else { return "—" }
        let minutes = Int((t / 60).rounded())
        if minutes < 60 { return "\(minutes) мин" }
        let h = minutes / 60, m = minutes % 60
        if h < 48 { return m == 0 ? "\(h) ч" : "\(h) ч \(m) мин" }
        let d = h / 24, rh = h % 24
        return rh == 0 ? "\(d) д" : "\(d) д \(rh) ч"
    }

    static func shortDuration(_ t: TimeInterval?) -> String {
        guard let t, t.isFinite, t >= 0 else { return "—" }
        let minutes = Int((t / 60).rounded())
        if minutes < 60 { return "\(minutes)м" }
        let h = minutes / 60, m = minutes % 60
        if h < 48 { return m == 0 ? "\(h)ч" : "\(h)ч \(m)м" }
        return "\(h / 24)д \(h % 24)ч"
    }

    static func watts(_ w: Double) -> String {
        w >= 1000 ? String(format: "%.2f кВт", w / 1000) : "\(Int(w.rounded())) Вт"
    }

    static func wattHours(_ wh: Double) -> String {
        wh >= 1000 ? String(format: "%.2f кВт·ч", wh / 1000) : "\(Int(wh.rounded())) Вт·ч"
    }
}

/// Имитация станции Venus E 5,12 кВт·ч: медленный суточный цикл без сети и Wi-Fi.
/// Состояние — чистая функция от времени, поэтому приложение и виджет показывают одно и то же.
enum DemoStation {
    static let capacityWh: Double = 5120
    /// Цикл 6 часов: 4,5 ч разряд с ~80 % до ~30 %, затем 1,5 ч заряд обратно.
    static let cycle: TimeInterval = 6 * 3600
    static let dischargeSpan: TimeInterval = 4.5 * 3600

    static func snapshot(at date: Date, settings: AppSettings) -> BatterySnapshot {
        let t = date.timeIntervalSince1970.truncatingRemainder(dividingBy: cycle)
        let wobble = sin(date.timeIntervalSince1970 / 45) * 60 + sin(date.timeIntervalSince1970 / 170) * 40
        let soc: Double
        var output = 0.0, input = 0.0
        if t < dischargeSpan {
            soc = 80 - 50 * t / dischargeSpan
            output = 340 + wobble
        } else {
            soc = 30 + 50 * (t - dischargeSpan) / (cycle - dischargeSpan)
            input = 1200 + wobble * 2
        }
        return BatterySnapshot(date: date, socPercent: soc, capacityWh: capacityWh,
                               outputW: max(0, output), inputW: max(0, input), deviceName: "Демо · Venus E")
    }

    /// История за последние часы — чтобы график в демо не был пустым.
    static func seedHistory(settings: AppSettings) {
        let now = Date()
        for minutes in stride(from: 360, through: 1, by: -2) {
            SharedStore.record(snapshot(at: now.addingTimeInterval(-Double(minutes) * 60), settings: settings))
        }
    }
}
