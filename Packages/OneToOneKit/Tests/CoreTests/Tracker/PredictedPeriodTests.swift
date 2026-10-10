import Testing
@testable import Core

@Test func predictedDaysAreFiveDaysOfNextThreePeriods() {
    let forecast = CycleForecast(phase: .follicular, dayOfCycle: 10, averageLength: 28,
                                 nextPeriodStart: DayKey(year: 2026, month: 10, day: 29))

    let days = forecast.predictedPeriodDays

    #expect(days.count == 15)
    #expect(days.contains(DayKey(year: 2026, month: 10, day: 29)))
    #expect(days.contains(DayKey(year: 2026, month: 11, day: 2)))
    #expect(!days.contains(DayKey(year: 2026, month: 11, day: 3)))
    #expect(days.contains(DayKey(year: 2026, month: 11, day: 26)))
    #expect(days.contains(DayKey(year: 2026, month: 12, day: 24)))
}

@Test func noPredictionWithoutMarks() {
    let forecast = CycleCalculator.forecast(periodDays: [], today: DayKey(year: 2026, month: 10, day: 10))

    #expect(forecast.predictedPeriodDays.isEmpty)
}
