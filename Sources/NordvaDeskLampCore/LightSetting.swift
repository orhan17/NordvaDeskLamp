public struct LightSetting: Equatable, Sendable {
    /// 1...100 %
    public var brightness: Int
    /// Kelvin, 2500...4800 on the Mi LED Desk Lamp Pro.
    public var temperature: Int

    public init(brightness: Int, temperature: Int) {
        self.brightness = brightness
        self.temperature = temperature
    }

    /// Whether moving to `other` is worth a command: smaller steps are invisible.
    public func differsNoticeably(from other: LightSetting) -> Bool {
        abs(brightness - other.brightness) >= 2 || abs(temperature - other.temperature) >= 50
    }
}

public enum LightScene: String, CaseIterable, Sendable {
    case work
    case reading
    case evening
    case night
    case call

    public var setting: LightSetting {
        switch self {
        case .work: return LightSetting(brightness: 100, temperature: 4800)
        case .reading: return LightSetting(brightness: 80, temperature: 4000)
        case .evening: return LightSetting(brightness: 45, temperature: 2900)
        case .night: return LightSetting(brightness: 5, temperature: 2500)
        case .call: return LightSetting(brightness: 90, temperature: 4300)
        }
    }
}
