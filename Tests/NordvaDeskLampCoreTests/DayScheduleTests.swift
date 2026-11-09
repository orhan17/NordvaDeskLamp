import Testing
@testable import NordvaDeskLampCore

private let schedule = DaySchedule() // day 9:00, evening 20:00, night 23:00, 60 min ramps

private func at(_ hour: Int, _ minute: Int = 0) -> Double {
    Double(hour * 60 + minute)
}

@Test func steadyPhases() {
    #expect(schedule.setting(at: at(12)) == DayPhase.day.setting)
    #expect(schedule.setting(at: at(21)) == DayPhase.evening.setting)
    #expect(schedule.setting(at: at(3)) == DayPhase.night.setting)
}

@Test func easesIntoTheEvening() {
    #expect(schedule.setting(at: at(19, 30)) == LightSetting(brightness: 80, temperature: 3900))
    #expect(schedule.setting(at: at(19)) == DayPhase.day.setting)
    #expect(schedule.setting(at: at(20)) == DayPhase.evening.setting)
}

@Test func easesIntoTheDayAcrossMidnightNight() {
    #expect(schedule.setting(at: at(8, 30)) == LightSetting(brightness: 58, temperature: 3650))
}

@Test func easesIntoTheNight() {
    #expect(schedule.setting(at: at(22, 30)) == LightSetting(brightness: 38, temperature: 2750))
}

@Test func nightCanStartAfterMidnight() {
    let late = DaySchedule(dayStart: 9 * 60, eveningStart: 20 * 60, nightStart: 60)
    #expect(late.phase(at: at(0, 30)) == .evening)
    #expect(late.setting(at: at(0, 30)) == LightSetting(brightness: 38, temperature: 2750))
    #expect(late.phase(at: at(2)) == .night)
}

@Test func phases() {
    #expect(schedule.phase(at: at(9)) == .day)
    #expect(schedule.phase(at: at(19, 59)) == .day)
    #expect(schedule.phase(at: at(20)) == .evening)
    #expect(schedule.phase(at: at(0)) == .night)
    #expect(schedule.phase(at: at(8, 59)) == .night)
}

@Test func overrideLastsUntilTheNextPhase() {
    #expect(schedule.minutesUntilNextPhase(at: at(12)) == 480)
    #expect(schedule.minutesUntilNextPhase(at: at(23, 30)) == 570)
}

@Test func rampNeverExceedsThePhase() {
    let short = DaySchedule(dayStart: 9 * 60, eveningStart: 9 * 60 + 30, nightStart: 23 * 60, ramp: 60)
    #expect(short.setting(at: at(9, 15)) == LightSetting(brightness: 80, temperature: 3900))
}

@Test func smallChangesAreNotWorthACommand() {
    let base = LightSetting(brightness: 50, temperature: 3000)
    #expect(!base.differsNoticeably(from: LightSetting(brightness: 51, temperature: 3040)))
    #expect(base.differsNoticeably(from: LightSetting(brightness: 52, temperature: 3000)))
    #expect(base.differsNoticeably(from: LightSetting(brightness: 50, temperature: 3050)))
}
