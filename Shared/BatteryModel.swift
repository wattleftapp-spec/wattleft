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
    /// Уведомлять, когда появилось питание от сети и станция начала заряжаться.
    var notifyGridReturn: Bool = true

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
        notifyGridReturn = try c.decodeIfPresent(Bool.self, forKey: .notifyGridReturn) ?? true
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
    /// Сколько из входящей мощности приходит именно из городской сети, W (без солнца).
    /// nil — в старых сохранённых замерах.
    var gridInW: Double? = nil

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
        guard let last = recent.last else { return nil }
        // Усредняем только с последней смены режима: если дали свет и станция пошла на заряд,
        // старые замеры разряда не должны тянуть прогноз назад.
        func mode(_ w: Double) -> Int { w > BatteryEstimate.idleThresholdW ? 1 : (w < -BatteryEstimate.idleThresholdW ? -1 : 0) }
        let current = mode(last.netW)
        let sameMode = recent.reversed().prefix { mode($0.netW) == current }
        return sameMode.map(\.netW).reduce(0, +) / Double(sameMode.count)
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
            if SharedStore.history.count < 10 { DemoStation.seedHistory(settings: settings) }
            let snapshot = DemoStation.snapshot(at: Date(), settings: settings)
            SharedStore.record(snapshot)
            await GridWatcher.check(snapshot, settings: settings)
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
            await GridWatcher.check(snapshot, settings: settings)
            return snapshot
        } catch {
            SharedStore.lastError = error.localizedDescription
            throw error
        }
    }
}

enum Fmt {
    /// Длительность целиком без переносов строки («2 h 30 min» не разрывается).
    static func duration(_ t: TimeInterval?) -> String {
        durationText(t).replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    private static func durationText(_ t: TimeInterval?) -> String {
        guard let t, t.isFinite, t >= 0 else { return "—" }
        let minutes = Int((t / 60).rounded())
        if minutes < 60 { return String(localized: "\(minutes) min") }
        let h = minutes / 60, m = minutes % 60
        if h < 48 { return m == 0 ? String(localized: "\(h) h") : String(localized: "\(h) h \(m) min") }
        let d = h / 24, rh = h % 24
        return rh == 0 ? String(localized: "\(d) d") : String(localized: "\(d) d \(rh) h")
    }

    static func shortDuration(_ t: TimeInterval?) -> String {
        guard let t, t.isFinite, t >= 0 else { return "—" }
        let minutes = Int((t / 60).rounded())
        if minutes < 60 { return String(localized: "\(minutes)m", comment: "Short duration: minutes") }
        let h = minutes / 60, m = minutes % 60
        if h < 48 { return m == 0 ? String(localized: "\(h)h", comment: "Short duration: hours")
                                  : String(localized: "\(h)h \(m)m", comment: "Short duration: hours and minutes") }
        let d = h / 24, rh = h % 24
        return String(localized: "\(d)d \(rh)h", comment: "Short duration: days and hours")
    }

    static func watts(_ w: Double) -> String {
        if w >= 1000 {
            // 1500 → «1.5 kW», 2000 → «2 kW», 1234 → «1.23 kW».
            let kw = (w / 1000).formatted(.number.precision(.fractionLength(0...2)))
            return String(localized: "\(kw) kW")
        }
        let watts = Int(w.rounded())
        return String(localized: "\(watts) W")
    }

    static func wattHours(_ wh: Double) -> String {
        if wh >= 1000 {
            let kwh = (wh / 1000).formatted(.number.precision(.fractionLength(2)))
            return String(localized: "\(kwh) kWh")
        }
        let value = Int(wh.rounded())
        return String(localized: "\(value) Wh")
    }
}

/// Имитация станции Venus E 5,12 кВт·ч: медленный суточный цикл без сети и Wi-Fi.
/// Состояние — чистая функция от времени, поэтому приложение и виджет показывают одно и то же.
enum DemoStation {
    static let capacityWh: Double = 5120
    /// Цикл 12 часов: 10 ч плавный разряд с ~95 % до ~20 %, затем 2 ч заряд обратно.
    static let cycle: TimeInterval = 12 * 3600
    static let dischargeSpan: TimeInterval = 10 * 3600

    /// Для скриншотов: запуск с `-demoSoc 72` ставит текущий заряд демо около 72 % (только отладка).
    static let timeShift: TimeInterval = {
        #if DEBUG
        // Читаем и из общего хранилища — чтобы виджет считал так же, как приложение.
        let shared = SharedStore.defaults.double(forKey: "demoSoc")
        let target = shared > 0 ? shared : UserDefaults.standard.double(forKey: "demoSoc")
        guard target > 20, target < 95 else { return 0 }
        // `demoCharging` — ставим в фазу заряда (для скриншота «Свет дали»).
        let charging = SharedStore.defaults.bool(forKey: "demoCharging")
            || UserDefaults.standard.bool(forKey: "demoCharging")
        let want = charging
            ? dischargeSpan + (target - 20) / 75 * (cycle - dischargeSpan)
            : (95 - target) / 75 * dischargeSpan
        let have = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: cycle)
        return want - have
        #else
        return 0
        #endif
    }()

    static func snapshot(at date: Date, settings: AppSettings) -> BatterySnapshot {
        let now = date.timeIntervalSince1970 + timeShift
        let t = now.truncatingRemainder(dividingBy: cycle)
        let wobble = sin(now / 45) * 60 + sin(now / 170) * 40
        // Нагрузка в течение дня «гуляет» — кривая разряда не идеально прямая.
        let drift = sin(now / 2400) * 2.5
        let soc: Double
        var output = 0.0, input = 0.0
        if t < dischargeSpan {
            soc = 95 - 75 * t / dischargeSpan + drift
            output = 340 + wobble
        } else {
            soc = 20 + 75 * (t - dischargeSpan) / (cycle - dischargeSpan)
            input = 1200 + wobble * 2
        }
        return BatterySnapshot(date: date, socPercent: min(100, max(0, soc)), capacityWh: capacityWh,
                               outputW: max(0, output), inputW: max(0, input), deviceName: String(localized: "Demo · Venus E"),
                               gridInW: max(0, input))
    }

    /// История за последние часы — чтобы график в демо не был пустым.
    static func seedHistory(settings: AppSettings) {
        let now = Date()
        for minutes in stride(from: 160, through: 1, by: -2) {
            SharedStore.record(snapshot(at: now.addingTimeInterval(-Double(minutes) * 60), settings: settings))
        }
    }
}
