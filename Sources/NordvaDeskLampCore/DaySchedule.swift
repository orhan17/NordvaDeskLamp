public enum DayPhase: String, CaseIterable, Sendable {
    case day
    case evening
    case night

    public var setting: LightSetting {
        switch self {
        case .day: return LightSetting(brightness: 100, temperature: 4800)
        case .evening: return LightSetting(brightness: 60, temperature: 3000)
        case .night: return LightSetting(brightness: 15, temperature: 2500)
        }
    }
}

/// Time-of-day lighting. Each phase starts at a minute of the day, and the light eases
/// into it linearly over `ramp` minutes before that start. Times may wrap past midnight.
public struct DaySchedule: Equatable, Sendable {
    public static let minutesPerDay = 1440.0

    public var dayStart: Int
    public var eveningStart: Int
    public var nightStart: Int
    public var ramp: Int

    public init(dayStart: Int = 9 * 60, eveningStart: Int = 20 * 60, nightStart: Int = 23 * 60, ramp: Int = 60) {
        self.dayStart = dayStart
        self.eveningStart = eveningStart
        self.nightStart = nightStart
        self.ramp = ramp
    }

    public func phase(at minute: Double) -> DayPhase {
        bounds(at: minute).current.phase
    }

    public func setting(at minute: Double) -> LightSetting {
        let (current, next, m) = bounds(at: minute)
        let ramp = min(Double(self.ramp), next.start - current.start)
        let fraction = ramp > 0 ? (m - (next.start - ramp)) / ramp : 0
        guard fraction > 0 else { return current.phase.setting }
        return blend(current.phase.setting, next.phase.setting, min(fraction, 1))
    }

    /// Minutes from `minute` until the next phase starts; a manual override lasts until then.
    public func minutesUntilNextPhase(at minute: Double) -> Double {
        let (_, next, m) = bounds(at: minute)
        return next.start - m
    }

    private func bounds(at minute: Double) -> (current: (start: Double, phase: DayPhase), next: (start: Double, phase: DayPhase), minute: Double) {
        let m = minute.truncatingRemainder(dividingBy: Self.minutesPerDay)
        let starts = [(Double(dayStart), DayPhase.day), (Double(eveningStart), .evening), (Double(nightStart), .night)]
            .sorted { $0.0 < $1.0 }
        let index = starts.lastIndex { $0.0 <= m }
        let current = index.map { starts[$0] } ?? (starts[starts.count - 1].0 - Self.minutesPerDay, starts[starts.count - 1].1)
        let nextIndex = index.map { $0 + 1 } ?? 0
        let next = nextIndex < starts.count
            ? starts[nextIndex]
            : (starts[0].0 + Self.minutesPerDay, starts[0].1)
        return ((current.0, current.1), (next.0, next.1), m)
    }

    private func blend(_ a: LightSetting, _ b: LightSetting, _ f: Double) -> LightSetting {
        LightSetting(
            brightness: Int((Double(a.brightness) + Double(b.brightness - a.brightness) * f).rounded()),
            temperature: Int((Double(a.temperature) + Double(b.temperature - a.temperature) * f).rounded())
        )
    }
}
