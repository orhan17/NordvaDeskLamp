import Foundation
import NordvaDeskLampCore

final class Preferences: ObservableObject {
    var onChange: (() -> Void)?

    @Published var autoEnabled: Bool { didSet { save(autoEnabled, "autoEnabled") } }
    @Published var dayStart: Int { didSet { save(dayStart, "dayStart") } }
    @Published var eveningStart: Int { didSet { save(eveningStart, "eveningStart") } }
    @Published var nightStart: Int { didSet { save(nightStart, "nightStart") } }
    @Published var followMac: Bool { didSet { save(followMac, "followMac") } }
    @Published var callLight: Bool { didSet { save(callLight, "callLight") } }

    init() {
        let store = UserDefaults.standard
        let defaults = DaySchedule()
        autoEnabled = store.object(forKey: "autoEnabled") as? Bool ?? true
        dayStart = store.object(forKey: "dayStart") as? Int ?? defaults.dayStart
        eveningStart = store.object(forKey: "eveningStart") as? Int ?? defaults.eveningStart
        nightStart = store.object(forKey: "nightStart") as? Int ?? defaults.nightStart
        followMac = store.object(forKey: "followMac") as? Bool ?? true
        callLight = store.object(forKey: "callLight") as? Bool ?? true
    }

    var schedule: DaySchedule {
        DaySchedule(dayStart: dayStart, eveningStart: eveningStart, nightStart: nightStart)
    }

    private func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
        onChange?()
    }
}
