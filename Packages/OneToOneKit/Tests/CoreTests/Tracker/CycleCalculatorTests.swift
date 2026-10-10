import Testing
@testable import Core

private func day(_ month: Int, _ day: Int, year: Int = 2026) -> DayKey {
    DayKey(year: year, month: month, day: day)
}

@Test func noMarksIsUnknown() {
    let forecast = CycleCalculator.forecast(periodDays: [], today: day(10, 10))

    #expect(forecast == CycleForecast(phase: .unknown, dayOfCycle: nil, averageLength: 28, nextPeriodStart: nil))
}

@Test func singleStartUses28() {
    let marks: Set = [day(10, 1), day(10, 2), day(10, 3), day(10, 4)]

    let forecast = CycleCalculator.forecast(periodDays: marks, today: day(10, 10))

    #expect(forecast == CycleForecast(phase: .follicular, dayOfCycle: 10, averageLength: 28, nextPeriodStart: day(10, 29)))
}

@Test func averageOfTwoCycles() {
    let marks: Set = [day(8, 1), day(8, 2), day(8, 31), day(9, 1), day(9, 30), day(10, 1)]

    let forecast = CycleCalculator.forecast(periodDays: marks, today: day(10, 10))

    #expect(forecast.averageLength == 30)
    #expect(forecast.dayOfCycle == 11)
    #expect(forecast.nextPeriodStart == day(10, 30))
}

@Test func clampsLength() {
    let sixtyDaysApart: Set = [day(8, 1), day(9, 30)]
    let fifteenDaysApart: Set = [day(9, 15), day(9, 30)]

    #expect(CycleCalculator.forecast(periodDays: sixtyDaysApart, today: day(10, 10)).averageLength == 40)
    #expect(CycleCalculator.forecast(periodDays: fifteenDaysApart, today: day(10, 10)).averageLength == 21)
}

@Test func markedDayIsMenstruation() {
    // Месячные отмечены 7 дней подряд: 7-й день больше прогнозных 1–5, но отмечен.
    let marks: Set = [day(10, 4), day(10, 5), day(10, 6), day(10, 7), day(10, 8), day(10, 9), day(10, 10)]

    let forecast = CycleCalculator.forecast(periodDays: marks, today: day(10, 10))

    #expect(forecast.dayOfCycle == 7)
    #expect(forecast.phase == .menstruation)
}

@Test func forecastDaysOneToFiveAreMenstruation() {
    // Отмечен только первый день, а сегодня третий.
    let forecast = CycleCalculator.forecast(periodDays: [day(10, 8)], today: day(10, 10))

    #expect(forecast.dayOfCycle == 3)
    #expect(forecast.phase == .menstruation)
}

@Test func ovulationWindow() {
    let start = day(10, 1)
    func phase(onDay dayOfCycle: Int) -> CyclePhase {
        CycleCalculator.forecast(periodDays: [start], today: start.adding(days: dayOfCycle - 1)).phase
    }

    #expect(phase(onDay: 11) == .follicular)
    for ovulationDay in 12...16 {
        #expect(phase(onDay: ovulationDay) == .ovulation)
    }
    #expect(phase(onDay: 17) == .luteal)
    #expect(phase(onDay: 28) == .luteal)
}

@Test func wrapsAroundWhenPeriodNotMarked() {
    // Последнее начало 1 августа, потом отметок нет: 70 дней = 2 круга по 28 и ещё 14.
    let forecast = CycleCalculator.forecast(periodDays: [day(8, 1)], today: day(10, 10))

    #expect(forecast.dayOfCycle == 15)
    #expect(forecast.phase == .ovulation)
    #expect(forecast.nextPeriodStart == day(10, 24))
}

@Test func ignoresMarksAfterToday() {
    let forecast = CycleCalculator.forecast(periodDays: [day(10, 1), day(10, 20)], today: day(10, 10))

    #expect(forecast == CycleForecast(phase: .follicular, dayOfCycle: 10, averageLength: 28, nextPeriodStart: day(10, 29)))
}

@Test func onlyFutureMarksIsUnknown() {
    let forecast = CycleCalculator.forecast(periodDays: [day(10, 20)], today: day(10, 10))

    #expect(forecast.phase == .unknown)
}

@Test func forgottenDayInsidePeriodIsSamePeriod() {
    // 3 октября забыли отметить: это всё ещё одни месячные, а не новый цикл.
    let marks: Set = [day(9, 3), day(10, 1), day(10, 2), day(10, 4), day(10, 5)]

    let forecast = CycleCalculator.forecast(periodDays: marks, today: day(10, 10))

    #expect(forecast == CycleForecast(phase: .follicular, dayOfCycle: 10, averageLength: 28, nextPeriodStart: day(10, 29)))
}

@Test func shortCycleKeepsMenstruationOverOvulation() {
    // При длине 21 окно овуляции 5–9 задевает 5-й день месячных.
    let marks: Set = [day(9, 1), day(9, 22)]

    #expect(CycleCalculator.forecast(periodDays: marks, today: day(9, 26)).phase == .menstruation)
    #expect(CycleCalculator.forecast(periodDays: marks, today: day(9, 27)).phase == .ovulation)
}
