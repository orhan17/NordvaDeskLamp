import Testing
@testable import NordvaDeskLampCore

@Test func parsesAFullReply() {
    #expect(LampState.parse(["on", "45", "4000"]) == LampState(isOn: true, brightness: 45, temperature: 4000))
}

@Test func parsesWithoutTemperature() {
    #expect(LampState.parse(["off", "100"]) == LampState(isOn: false, brightness: 100, temperature: nil))
}

@Test func ignoresAnUnreadableTemperature() {
    #expect(LampState.parse(["on", "10", ""])?.temperature == nil)
}

@Test func rejectsGarbage() {
    #expect(LampState.parse([]) == nil)
    #expect(LampState.parse(["on"]) == nil)
    #expect(LampState.parse(["maybe", "10"]) == nil)
    #expect(LampState.parse(["on", "bright"]) == nil)
}
