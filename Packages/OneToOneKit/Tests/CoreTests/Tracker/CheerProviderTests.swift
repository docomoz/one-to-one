import Testing
@testable import Core

private func forecast(_ phase: CyclePhase, day: Int? = 10) -> CycleForecast {
    CycleForecast(phase: phase, dayOfCycle: day, averageLength: 28,
                  nextPeriodStart: day == nil ? nil : DayKey(year: 2026, month: 10, day: 29))
}

@Test(arguments: [CyclePhase.menstruation, .follicular, .ovulation, .luteal])
func cheerForEachPhase(_ phase: CyclePhase) throws {
    let cheer = try #require(CheerProvider.cheer(forecast: forecast(phase)))
    let threeDays = (1...3).compactMap { CheerProvider.cheer(forecast: forecast(phase, day: $0)) }

    #expect(!cheer.isEmpty)
    #expect(Set(threeDays).count == 3)
    #expect(CheerProvider.cheer(forecast: forecast(phase)) == cheer)
}

@Test func noCheerForUnknown() {
    #expect(CheerProvider.cheer(forecast: forecast(.unknown, day: nil)) == nil)
}
