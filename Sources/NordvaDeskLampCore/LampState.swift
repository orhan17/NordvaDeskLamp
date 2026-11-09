public struct LampState: Equatable, Sendable {
    public var isOn: Bool
    public var brightness: Int
    public var temperature: Int?

    public init(isOn: Bool, brightness: Int, temperature: Int?) {
        self.isOn = isOn
        self.brightness = brightness
        self.temperature = temperature
    }

    /// The properties `parse` expects, in this order.
    public static let properties = ["power", "bright", "ct"]

    /// Parses a `get_prop` reply such as `["on", "45", "4000"]`. Lamps report numbers as strings.
    public static func parse(_ reply: [String]) -> LampState? {
        guard reply.count >= 2, reply[0] == "on" || reply[0] == "off", let brightness = Int(reply[1]) else {
            return nil
        }
        let temperature = reply.count > 2 ? Int(reply[2]) : nil
        return LampState(isOn: reply[0] == "on", brightness: brightness, temperature: temperature)
    }
}
