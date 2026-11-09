import NordvaDeskLampCore
import SwiftUI

struct LampPanel: View {
    @ObservedObject var lamp: Lamp
    @ObservedObject var autopilot: Autopilot
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            scenes
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
            automationStatus
            Divider()
            HStack {
                Button("Settings…", action: openSettings)
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

    private var scenes: some View {
        HStack(spacing: 6) {
            ForEach([LightScene.work, .reading, .evening, .night], id: \.self) { scene in
                Button {
                    autopilot.select(scene)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: scene.symbol).font(.system(size: 14))
                        Text(scene.title).font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(lamp.status != .online)
    }

    @ViewBuilder private var automationStatus: some View {
        switch autopilot.mode {
        case .off:
            EmptyView()
        case let .auto(phase):
            Label("Auto: \(phase.title.lowercased()) light", systemImage: "clock")
                .font(.caption).foregroundStyle(.secondary)
        case let .manual(until):
            HStack {
                Label("Manual until \(until.formatted(date: .omitted, time: .shortened))", systemImage: "hand.raised")
                Spacer()
                Button("Back to auto") { autopilot.resumeAuto() }.buttonStyle(.borderless)
            }
            .font(.caption).foregroundStyle(.secondary)
        case .call:
            Label("Call light while the camera is on", systemImage: "video")
                .font(.caption).foregroundStyle(.secondary)
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
}

extension LightScene {
    var title: String {
        switch self {
        case .work: return "Work"
        case .reading: return "Reading"
        case .evening: return "Evening"
        case .night: return "Night"
        case .call: return "Call"
        }
    }

    var symbol: String {
        switch self {
        case .work: return "laptopcomputer"
        case .reading: return "book"
        case .evening: return "sunset"
        case .night: return "moon.stars"
        case .call: return "video"
        }
    }
}

extension DayPhase {
    var title: String {
        switch self {
        case .day: return "Day"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }
}
