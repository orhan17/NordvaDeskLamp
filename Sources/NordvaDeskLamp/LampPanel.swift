import ServiceManagement
import SwiftUI

struct LampPanel: View {
    @ObservedObject var lamp: Lamp
    let quit: () -> Void

    @State private var showSettings = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            slider(
                value: Binding(get: { lamp.brightness }, set: lamp.setBrightness),
                range: Lamp.brightnessRange,
                low: "sun.min", high: "sun.max",
                label: "\(Int(lamp.brightness.rounded()))%"
            )
            slider(
                value: Binding(get: { lamp.temperature }, set: lamp.setTemperature),
                range: Lamp.temperatureRange,
                low: "flame", high: "snowflake",
                label: "\(Int(lamp.temperature.rounded()))K"
            )
            .tint(.orange)
            Divider()
            if showSettings {
                settings
                Divider()
            }
            HStack {
                Button(showSettings ? "Done" : "Settings…") { showSettings.toggle() }
                Spacer()
                Button("Quit", action: quit)
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: lamp.isOn ? "lamp.desk.fill" : "lamp.desk")
                .font(.system(size: 22))
                .foregroundStyle(lamp.isOn ? Color.yellow : Color.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("Desk Lamp").font(.headline)
                statusText
            }
            Spacer()
            Toggle("", isOn: Binding(get: { lamp.isOn }, set: lamp.setPower))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(lamp.status != .online)
        }
    }

    @ViewBuilder private var statusText: some View {
        switch lamp.status {
        case .idle, .connecting:
            Text("Connecting…").font(.caption).foregroundStyle(.secondary)
        case .online:
            Text(lamp.isOn ? "On" : "Off").font(.caption).foregroundStyle(.secondary)
        case let .failed(message):
            Text(message).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func slider(
        value: Binding<Double>, range: ClosedRange<Double>, low: String, high: String, label: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: low).foregroundStyle(.secondary).frame(width: 18)
            Slider(value: value, in: range)
            Image(systemName: high).foregroundStyle(.secondary).frame(width: 18)
            Text(label)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .disabled(lamp.status != .online)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lamp address").font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("192.168.1.10 or name.local", text: $lamp.host)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { lamp.refresh() }
                Button("Connect") { lamp.refresh() }
            }
            Label(
                lamp.hasToken ? "Token found in Keychain" : "No token in Keychain yet, see the README",
                systemImage: lamp.hasToken ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(lamp.hasToken ? Color.green : Color.orange)
            Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }
        }
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
