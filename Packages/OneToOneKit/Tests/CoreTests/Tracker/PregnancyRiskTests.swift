import Testing
@testable import Core

private func day(_ month: Int, _ day: Int, year: Int = 2026) -> DayKey {
    DayKey(year: year, month: month, day: day)
}

/// Начала 12 июня, 10 июля, 7 августа, 5 сентября: длины 28, 28, 29.
private let regular: Set = [day(6, 12), day(7, 10), day(8, 7), day(9, 5)]

/// День цикла, начавшегося 5 сентября.
private func cycleDay(_ number: Int) -> DayKey {
    day(9, 5).adding(days: number - 1)
}

@Test func riskWithoutMarksIsUnknown() {
    #expect(PregnancyRiskCalculator.risk(on: day(10, 3), periodDays: [], today: day(10, 3)) == .unknown)
}

@Test func regularCycleWindow() {
    // Окно 10–18 (28 − 18 … 29 − 11), средний 8–9 и 19–20.
    let risk = { PregnancyRiskCalculator.risk(on: cycleDay($0), periodDays: regular, today: day(10, 3)) }

    #expect(risk(1) == .low)
    #expect(risk(7) == .low)
    #expect(risk(8) == .medium)
    #expect(risk(9) == .medium)
    #expect(risk(10) == .high)
    #expect(risk(18) == .high)
    #expect(risk(19) == .medium)
    #expect(risk(20) == .medium)
    #expect(risk(21) == .low)
    #expect(risk(29) == .low)
}

@Test func fewCyclesHasNoLow() {
    // Одно начало: окно 8–19, всё остальное средний.
    let marks: Set = [day(9, 5)]
    let risk = { PregnancyRiskCalculator.risk(on: cycleDay($0), periodDays: marks, today: day(10, 3)) }

    #expect(risk(1) == .medium)
    #expect(risk(7) == .medium)
    #expect(risk(8) == .high)
    #expect(risk(19) == .high)
    #expect(risk(20) == .medium)
    #expect(risk(29) == .medium)
}

@Test func fewShortCyclesWidenWindow() {
    // Длины 22, 22: окно 8–19 расширяется до 4–19 (22 − 18).
    let marks: Set = [day(8, 1), day(8, 23), day(9, 14)]

    #expect(PregnancyRiskCalculator.risk(on: day(9, 17), periodDays: marks, today: day(9, 20)) == .high)
}

@Test func fewCyclesLateAfter32() {
    let marks: Set = [day(9, 5)]

    #expect(PregnancyRiskCalculator.risk(on: day(10, 6), periodDays: marks, today: day(10, 7)) == .medium)
    #expect(PregnancyRiskCalculator.risk(on: day(10, 7), periodDays: marks, today: day(10, 7)) == .late)
}

@Test func usesSixRecentCycles() {
    // Длины 21 и шесть по 28: старый цикл в 21 день отброшен, окно 10–17, 5-й день низкий.
    let marks: Set = [day(1, 1), day(1, 22), day(2, 19), day(3, 19), day(4, 16), day(5, 14), day(6, 11), day(7, 9)]

    #expect(PregnancyRiskCalculator.risk(on: day(7, 13), periodDays: marks, today: day(7, 20)) == .low)
}

@Test func irregularCyclesHaveNoLow() {
    // Длины 22, 35, 28: разброс 13 > 10, окно 4–24.
    let marks: Set = [day(6, 1), day(6, 23), day(7, 28), day(8, 25)]

    #expect(PregnancyRiskCalculator.risk(on: day(8, 25), periodDays: marks, today: day(9, 10)) == .medium)
    #expect(PregnancyRiskCalculator.risk(on: day(8, 28), periodDays: marks, today: day(9, 10)) == .high)
}

@Test func lateWhenPastLongestCycle() {
    // 10 октября — 36-й день, 4 октября — 30-й, а самый длинный цикл 29 дней.
    #expect(PregnancyRiskCalculator.risk(on: day(10, 10), periodDays: regular, today: day(10, 10)) == .late)
    #expect(PregnancyRiskCalculator.risk(on: day(10, 4), periodDays: regular, today: day(10, 10)) == .late)
}

@Test func futureDayFollowsForecast() {
    // Средняя длина 28: 4 октября — 2-й день нового цикла, 13 октября — 11-й.
    #expect(PregnancyRiskCalculator.risk(on: day(10, 4), periodDays: regular, today: day(10, 3)) == .low)
    #expect(PregnancyRiskCalculator.risk(on: day(10, 13), periodDays: regular, today: day(10, 3)) == .high)
}

@Test func ignoresMarksAfterDay() {
    // Начало 1 октября дало бы длину 26 и окно с 8-го дня; 12 сентября (8-й день) судим по тому, что знали тогда.
    #expect(PregnancyRiskCalculator.risk(on: day(9, 12), periodDays: regular.union([day(10, 1)]), today: day(10, 3)) == .medium)
    // Отметка в будущем не меняет прогноз.
    #expect(PregnancyRiskCalculator.risk(on: day(10, 13), periodDays: regular.union([day(10, 20)]), today: day(10, 3)) == .high)
}

@Test func skipsCyclesLongerThan40() {
    // 1 апреля → 20 мая = 49 дней, не считаем; остаются 28, 28, 28.
    let marks: Set = [day(4, 1), day(5, 20), day(6, 17), day(7, 15), day(8, 12)]

    #expect(PregnancyRiskCalculator.risk(on: day(8, 12), periodDays: marks, today: day(8, 20)) == .low)
}
