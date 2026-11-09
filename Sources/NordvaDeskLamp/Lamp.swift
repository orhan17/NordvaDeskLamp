import Foundation
import NordvaDeskLampCore

/// The lamp as the panel sees it. Published state lives on the main thread; network
/// calls run on one serial queue. Slider drags send only the latest value per command,
/// throttled, so the lamp is not flooded with requests.
final class Lamp: ObservableObject {
    enum Status: Equatable {
        case idle
        case connecting
        case online
        case failed(String)
    }

    static let brightnessRange: ClosedRange<Double> = 1...100
    static let temperatureRange: ClosedRange<Double> = 2500...4800

    @Published private(set) var status = Status.idle
    @Published private(set) var hasToken = false
    @Published private(set) var isOn = false
    @Published private(set) var brightness = 50.0
    @Published private(set) var temperature = 3600.0
    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "host") }
    }

    private let client = MiioClient()
    private let queue = DispatchQueue(label: "nordvadesklamp.miio")
    private let lock = NSLock()
    private var token: String?
    private var pending: [(method: String, params: [Any])] = []
    private var draining = false

    private var pollTimer: Timer?
    private var polling = false
    private var lastLocalChange = Date.distantPast

    init() {
        host = UserDefaults.standard.string(forKey: "host") ?? ""
    }

    func refresh(then done: (() -> Void)? = nil) {
        let host = host
        status = status == .online ? .online : .connecting
        queue.async { [self] in
            let result = Result { () -> LampState in
                try prepare(host: host)
                return try readState()
            }
            DispatchQueue.main.async { [self] in
                hasToken = token != nil
                switch result {
                case let .success(state):
                    apply(state)
                    status = .online
                case let .failure(error):
                    status = .failed(error.localizedDescription)
                }
                done?()
            }
        }
    }

    /// The lamp can't report changes made with its own button, so its state is polled.
    /// `nil` stops polling.
    func poll(every interval: TimeInterval?) {
        pollTimer?.invalidate()
        pollTimer = nil
        guard let interval else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pollOnce()
        }
    }

    func setPower(_ on: Bool) {
        lastLocalChange = Date()
        isOn = on
        enqueue("set_power", [on ? "on" : "off", "smooth", 300])
    }

    func setBrightness(_ value: Double) {
        lastLocalChange = Date()
        brightness = value
        if !isOn { setPower(true) }
        enqueue("set_bright", [Int(value.rounded()), "smooth", 200])
    }

    func setTemperature(_ value: Double) {
        lastLocalChange = Date()
        temperature = value
        if !isOn { setPower(true) }
        enqueue("set_ct_abx", [Int(value.rounded()), "smooth", 200])
    }

    private func pollOnce() {
        guard !polling, lock.withLock({ pending.isEmpty && !draining }) else { return }
        polling = true
        let host = host
        queue.async { [self] in
            let result = Result { () -> LampState in
                try prepare(host: host)
                return try readState()
            }
            DispatchQueue.main.async { [self] in
                polling = false
                hasToken = token != nil
                switch result {
                case let .success(state):
                    // A reading taken before the user's last change reached the lamp would undo it on screen.
                    if Date().timeIntervalSince(lastLocalChange) > 1.5 {
                        apply(state)
                    }
                    status = .online
                case let .failure(error):
                    status = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func apply(_ state: LampState) {
        isOn = state.isOn
        brightness = Double(state.brightness)
        if let kelvin = state.temperature {
            temperature = min(max(Double(kelvin), Self.temperatureRange.lowerBound), Self.temperatureRange.upperBound)
        }
    }

    private func enqueue(_ method: String, _ params: [Any]) {
        let host = host
        let start = lock.withLock { () -> Bool in
            if let index = pending.firstIndex(where: { $0.method == method }) {
                pending[index].params = params
            } else {
                pending.append((method, params))
            }
            defer { draining = true }
            return !draining
        }
        if start {
            queue.async { [self] in drain(host: host) }
        }
    }

    // MARK: - Network queue only

    private func prepare(host: String) throws {
        if token == nil { token = LampToken.load() }
        client.configure(host: host, tokenHex: token)
    }

    private func readState() throws -> LampState {
        let reply = try client.call("get_prop", LampState.properties) as? [Any] ?? []
        guard let state = LampState.parse(reply.map { "\($0)" }) else {
            throw LampError.device("unexpected reply \(reply)")
        }
        return state
    }

    private func drain(host: String) {
        var failure: String?
        do { try prepare(host: host) } catch { failure = error.localizedDescription }
        while let next = lock.withLock({ () -> (method: String, params: [Any])? in
            guard !pending.isEmpty else {
                draining = false
                return nil
            }
            return pending.removeFirst()
        }) {
            do {
                _ = try client.call(next.method, next.params)
                failure = nil
            } catch {
                failure = error.localizedDescription
            }
            Thread.sleep(forTimeInterval: 0.15)
        }
        let message = failure
        DispatchQueue.main.async { [self] in
            hasToken = token != nil
            status = message.map(Status.failed) ?? .online
        }
    }
}
