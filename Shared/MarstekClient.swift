import Foundation
import Network

/// Ошибки при общении со станцией.
enum MarstekError: LocalizedError {
    case notConfigured
    case timeout
    case badResponse(String)
    case device(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Укажите IP-адрес станции в настройках."
        case .timeout:
            return "Станция не ответила. Проверьте IP и порт, что телефон в той же Wi-Fi сети и что Open API включён в приложении Marstek."
        case .badResponse(let raw):
            return "Непонятный ответ станции: \(raw)"
        case .device(let message):
            return "Станция вернула ошибку: \(message)"
        }
    }
}

/// Число, которое может прийти и как JSON-число, и как строка (`"soc": "90"`).
struct LooseDouble: Decodable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            value = nil
        } else if let d = try? c.decode(Double.self) {
            value = d
        } else if let s = try? c.decode(String.self) {
            value = Double(s)
        } else {
            value = nil
        }
    }
}

/// Ответ `ES.GetStatus` (Marstek Device Open API, раздел 3.6.1).
struct ESStatus: Decodable {
    let batSoc: LooseDouble?        // %
    let batCap: LooseDouble?        // полная ёмкость, Wh
    let pvPower: LooseDouble?       // W
    let ongridPower: LooseDouble?   // W
    let offgridPower: LooseDouble?  // W
    let batPower: LooseDouble?      // W (есть не во всех прошивках)
}

/// Ответ `Bat.GetStatus` (раздел 3.4.1) — запасной источник SOC и ёмкости.
struct BatStatus: Decodable {
    let soc: LooseDouble?
    let batTemp: LooseDouble?
    let batCapacity: LooseDouble?   // остаток, Wh
    let ratedCapacity: LooseDouble? // номинал, Wh
}

private struct RPCResponse<T: Decodable>: Decodable {
    let result: T?
    let error: RPCError?
    let src: String?
}

private struct RPCError: Decodable {
    let code: Int?
    let message: String?
}

/// Клиент локального UDP JSON-RPC API станций Marstek Venus.
struct MarstekClient {
    let host: String
    let port: UInt16
    var timeout: TimeInterval = 3

    func call<T: Decodable>(_ method: String, as type: T.Type) async throws -> (T, String?) {
        let body: [String: Any] = [
            "id": Int.random(in: 1...60000),
            "method": method,
            "params": ["id": 0],
        ]
        let payload = try JSONSerialization.data(withJSONObject: body)
        let raw = try await exchange(payload)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response: RPCResponse<T>
        do {
            response = try decoder.decode(RPCResponse<T>.self, from: raw)
        } catch {
            throw MarstekError.badResponse(String(decoding: raw.prefix(200), as: UTF8.self))
        }
        if let error = response.error {
            throw MarstekError.device(error.message ?? "код \(error.code ?? 0)")
        }
        guard let result = response.result else {
            throw MarstekError.badResponse(String(decoding: raw.prefix(200), as: UTF8.self))
        }
        return (result, response.src)
    }

    /// Отправляет одну UDP-датаграмму и ждёт первый ответ.
    private func exchange(_ payload: Data) async throws -> Data {
        guard !host.isEmpty, let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw MarstekError.notConfigured
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .udp)
        let queue = DispatchQueue(label: "marstek.udp")
        let timeout = self.timeout

        return try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce(continuation)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: payload, completion: .contentProcessed { error in
                        if let error {
                            once.resume(.failure(error))
                            connection.cancel()
                        }
                    })
                    connection.receiveMessage { data, _, _, error in
                        if let data, !data.isEmpty {
                            once.resume(.success(data))
                        } else {
                            once.resume(.failure(error ?? MarstekError.timeout))
                        }
                        connection.cancel()
                    }
                case .failed(let error):
                    once.resume(.failure(error))
                    connection.cancel()
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                once.resume(.failure(MarstekError.timeout))
                connection.cancel()
            }
        }
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private var continuation: CheckedContinuation<Data, Error>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<Data, Error>) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(with: result)
    }
}

extension MarstekClient {
    /// Читает состояние станции и превращает его в снимок для приложения и виджета.
    func fetchSnapshot(settings: AppSettings) async throws -> BatterySnapshot {
        let (es, src) = try await call("ES.GetStatus", as: ESStatus.self)

        var soc = es.batSoc?.value
        var capacity = es.batCap?.value
        if soc == nil || capacity == nil || capacity == 0 {
            // Некоторые прошивки не отдают SOC в ES.GetStatus — спрашиваем батарею.
            try? await Task.sleep(nanoseconds: 300_000_000)
            if let (bat, _) = try? await call("Bat.GetStatus", as: BatStatus.self) {
                soc = soc ?? bat.soc?.value
                if capacity == nil || capacity == 0 { capacity = bat.ratedCapacity?.value }
            }
        }
        if settings.capacityOverrideWh > 0 { capacity = settings.capacityOverrideWh }

        guard let soc else { throw MarstekError.badResponse("нет поля bat_soc") }
        let totalWh = (capacity ?? 0) > 0 ? capacity! : 5120

        // ongrid_power > 0 — станция отдаёт энергию в дом; < 0 — берёт из сети (заряд).
        let sign: Double = settings.invertGridSign ? -1 : 1
        let ongrid = (es.ongridPower?.value ?? 0) * sign
        let offgrid = es.offgridPower?.value ?? 0
        let pv = es.pvPower?.value ?? 0

        let output = max(0, ongrid) + max(0, offgrid)
        let input = max(0, -ongrid) + max(0, pv)

        return BatterySnapshot(
            date: Date(),
            socPercent: min(100, max(0, soc)),
            capacityWh: totalWh,
            outputW: output,
            inputW: input,
            deviceName: src
        )
    }
}
