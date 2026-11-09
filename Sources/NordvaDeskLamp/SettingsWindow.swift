import AppKit
import NordvaDeskLampCore
import ServiceManagement
import SwiftUI

final class SettingsWindowController {
    private let lamp: Lamp
    private let prefs: Preferences
    private var window: NSWindow?

    init(lamp: Lamp, prefs: Preferences) {
        self.lamp = lamp
        self.prefs = prefs
    }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(lamp: lamp, prefs: prefs))
            host.sizingOptions = .preferredContentSize
            let window = NSWindow(contentViewController: host)
            window.title = "NordvaDeskLamp Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @ObservedObject var lamp: Lamp
    @ObservedObject var prefs: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Lamp") {
                HStack {
                    TextField("Address", text: $lamp.host, prompt: Text("192.168.1.10 or name.local"))
                        .onSubmit { lamp.refresh() }
                    Button("Connect") { lamp.refresh() }
                }
                LabeledContent("Status") { connection }
                LabeledContent("Token") {
                    Label(
                        lamp.hasToken ? "In the Keychain" : "Not in the Keychain yet, see the README",
                        systemImage: lamp.hasToken ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(lamp.hasToken ? Color.green : Color.orange)
                }
            }

            Section("Time of day") {
                toggle(
                    "Follow the time of day",
                    detail: "Day 4800K 100%, evening 3000K 60%, night 2500K 15%, easing in over an hour. "
                        + "Only while the lamp is on. A slider or a scene pauses it until the next phase.",
                    isOn: $prefs.autoEnabled
                )
                DatePicker("Day starts", selection: time($prefs.dayStart), displayedComponents: .hourAndMinute)
                DatePicker("Evening starts", selection: time($prefs.eveningStart), displayedComponents: .hourAndMinute)
                DatePicker("Night starts", selection: time($prefs.nightStart), displayedComponents: .hourAndMinute)
            }

            Section("Mac") {
                toggle(
                    "Turn off when the Mac locks or sleeps",
                    detail: "It comes back on when you unlock, if NordvaDeskLamp was the one that turned it off.",
                    isOn: $prefs.followMac
                )
            }

            Section("Calls") {
                toggle(
                    "Call light while a camera is on",
                    detail: "Bright, neutral light (90%, 4300K) while any app uses a camera, then back to how it was.",
                    isOn: $prefs.callLight
                )
            }

            Section("General") {
                toggle(
                    "Keep the menu bar icon up to date",
                    detail: "Checks the lamp every 10 s while the panel is closed. Off: no traffic until you open it, "
                        + "except the once-a-minute check when following the time of day.",
                    isOn: $lamp.backgroundUpdates
                )
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var connection: some View {
        switch lamp.status {
        case .idle, .connecting:
            Text("Connecting…").foregroundStyle(.secondary)
        case .online:
            Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case let .failed(message):
            Text(message).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Minutes since midnight as a time-only date for DatePicker.
    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(minutes.wrappedValue) * 60) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
