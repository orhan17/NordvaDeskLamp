import AppKit
import Combine
import NordvaDeskLampCore

/// Time of day, the Mac's lock and sleep, and the camera decide the lamp's light.
/// It never turns the lamp on by the clock; it only shapes the light while the lamp is on.
/// A manual change pauses the schedule until its next phase, so it never fights the user.
final class Autopilot: ObservableObject {
    enum Mode: Equatable {
        case off
        case auto(DayPhase)
        case manual(until: Date)
        case call
    }

    @Published private(set) var mode = Mode.off

    private let lamp: Lamp
    private let prefs: Preferences
    private let camera = CameraMonitor()
    private var timer: Timer?
    private var overrideUntil: Date?
    private var turnedOffByMac = false
    private var beforeCall: (isOn: Bool, setting: LightSetting)?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var lampSwitchedOn: AnyCancellable?

    init(lamp: Lamp, prefs: Preferences) {
        self.lamp = lamp
        self.prefs = prefs
    }

    /// Separate from init so debug runs (--check, snapshots) never drive the lamp.
    func start() {
        lamp.onUserAdjust = { [weak self] in self?.userTookOver() }
        camera.onChange = { [weak self] active in self?.cameraChanged(active) }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.tick() }
        // Switched on from the panel or its own button: bring it to the schedule.
        lampSwitchedOn = lamp.$isOn.removeDuplicates().dropFirst().filter { $0 }.sink { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { self?.tick() }
        }
        observeMac()
        settingsChanged()
    }

    func settingsChanged() {
        if prefs.callLight {
            camera.start()
        } else {
            camera.stop()
            endCall()
        }
        tick()
    }

    func select(_ scene: LightScene) {
        lamp.apply(scene.setting, powerOn: true, fade: 400)
        userTookOver()
    }

    func resumeAuto() {
        overrideUntil = nil
        tick()
    }

    // MARK: - Time of day

    private func tick() {
        if let until = overrideUntil, Date() >= until { overrideUntil = nil }
        updateMode()
        guard prefs.autoEnabled, overrideUntil == nil, beforeCall == nil, !turnedOffByMac, !lamp.changedRecently else {
            return
        }
        lamp.fetch { [weak self] state in
            guard let self, let state, state.isOn, self.overrideUntil == nil, self.beforeCall == nil else { return }
            let target = self.prefs.schedule.setting(at: Self.minuteOfDay())
            let now = LightSetting(brightness: state.brightness, temperature: state.temperature ?? target.temperature)
            guard target.differsNoticeably(from: now) else { return }
            Log.debug("auto: \(target.brightness)% \(target.temperature)K")
            self.lamp.apply(target)
        }
    }

    private func userTookOver() {
        guard prefs.autoEnabled, beforeCall == nil else { return }
        let minutes = prefs.schedule.minutesUntilNextPhase(at: Self.minuteOfDay())
        overrideUntil = Date().addingTimeInterval(minutes * 60)
        updateMode()
    }

    private func updateMode() {
        if beforeCall != nil {
            mode = .call
        } else if !prefs.autoEnabled {
            mode = .off
        } else if let until = overrideUntil {
            mode = .manual(until: until)
        } else {
            mode = .auto(prefs.schedule.phase(at: Self.minuteOfDay()))
        }
    }

    private var scheduledSetting: LightSetting {
        prefs.schedule.setting(at: Self.minuteOfDay())
    }

    private static func minuteOfDay() -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        return Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) + Double(parts.second ?? 0) / 60
    }

    // MARK: - Mac lock and sleep

    private func observeMac() {
        let distributed = DistributedNotificationCenter.default()
        let workspace = NSWorkspace.shared.notificationCenter
        let pairs: [(NotificationCenter, Notification.Name, (Autopilot) -> Void)] = [
            (distributed, .init("com.apple.screenIsLocked"), { $0.macLocked() }),
            (distributed, .init("com.apple.screenIsUnlocked"), { $0.macCameBack() }),
            (workspace, NSWorkspace.willSleepNotification, { $0.macSleeping() }),
            (workspace, NSWorkspace.didWakeNotification, { $0.macWoke() }),
        ]
        for (center, name, action) in pairs {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                if let self { action(self) }
            }
            observers.append((center, token))
        }
    }

    private func macLocked() {
        guard prefs.followMac, !turnedOffByMac else { return }
        lamp.fetch(force: true) { [weak self] state in
            guard let self, state?.isOn == true, !self.turnedOffByMac else { return }
            self.turnedOffByMac = true
            Log.debug("mac locked: lamp off")
            self.lamp.powerOff()
        }
    }

    private func macSleeping() {
        guard prefs.followMac, !turnedOffByMac else { return }
        if lamp.powerOffNow() {
            turnedOffByMac = true
            Log.debug("mac sleeping: lamp off")
        }
    }

    private func macWoke() {
        // A locked Mac wakes to the lock screen and the lamp returns on unlock; without a
        // lock screen no unlock ever comes, so check once the session has settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if !Self.screenIsLocked() { self?.macCameBack() }
        }
    }

    private func macCameBack() {
        guard turnedOffByMac else { return }
        turnedOffByMac = false
        // Wi-Fi needs a moment after wake.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            Log.debug("mac back: lamp on")
            let auto = self.prefs.autoEnabled && self.overrideUntil == nil
            self.lamp.apply(auto ? self.scheduledSetting : self.lamp.current, powerOn: true, fade: 500)
        }
    }

    private static func screenIsLocked() -> Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return session?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    // MARK: - Camera

    private func cameraChanged(_ active: Bool) {
        guard prefs.callLight else { return }
        active ? startCall() : endCall()
    }

    private func startCall() {
        guard beforeCall == nil else { return }
        lamp.fetch(force: true) { [weak self] state in
            guard let self, self.camera.isActive, self.beforeCall == nil else { return }
            self.beforeCall = (state?.isOn ?? self.lamp.isOn, self.lamp.current)
            Log.debug("call light on")
            self.lamp.apply(LightScene.call.setting, powerOn: true, fade: 500)
            self.updateMode()
        }
    }

    private func endCall() {
        guard let before = beforeCall else { return }
        beforeCall = nil
        Log.debug("call light off")
        if !before.isOn {
            lamp.powerOff()
        } else if prefs.autoEnabled, overrideUntil == nil {
            lamp.apply(scheduledSetting, fade: 500)
        } else {
            lamp.apply(before.setting, fade: 500)
        }
        updateMode()
    }
}
