import Testing
@testable import Core

private func day(_ month: Int, _ day: Int, year: Int = 2026) -> DayKey {
    DayKey(year: year, month: month, day: day)
}

/// Начала 12 июня, 10 июля, 7 августа, 5 сентября: длины 28, 28, 29. Окно высокого риска — дни 10–18.
private let regular: Set = [day(6, 12), day(7, 10), day(8, 7), day(9, 5)]

/// 12-й день цикла, высокий риск.
private let today = day(9, 16)

private func hint(types: Set<SexType> = [.vaginal], condom: Bool? = false, finish: SexFinish? = .inside,
                  day: DayKey = today, periodDays: Set<DayKey> = regular, today: DayKey = today) -> EmergencyHint? {
    EmergencyHint.hint(types: types, condom: condom, finish: finish, day: day, periodDays: periodDays, today: today)
}

@Test func strongWhenInsideWithoutCondom() {
    #expect(hint() == .strong)
}

@Test func softWhenOutsideOrUnknown() {
    #expect(hint(finish: .outside) == .soft)
    #expect(hint(finish: .didNotFinish) == .soft)
    #expect(hint(finish: nil) == .soft)
}

@Test func noHintWithCondomOrUnknownCondom() {
    #expect(hint(condom: true) == nil)
    #expect(hint(condom: nil) == nil)
}

@Test func noHintWithoutVaginal() {
    #expect(hint(types: [.blowjob]) == nil)
}

@Test func noHintOnLowDay() {
    // 23-й день цикла.
    #expect(hint(day: day(9, 27), today: day(9, 28)) == nil)
}

@Test func hintOnLateOrUnknownDay() {
    #expect(hint(periodDays: []) == .strong)
    // 36-й день цикла: задержка.
    #expect(hint(day: day(10, 10), today: day(10, 10)) == .strong)
}

@Test func hintUsesEntryDay() {
    // Запись 7-го дня (низкий), сегодня 10-й (высокий).
    #expect(hint(day: day(9, 11), today: day(9, 14)) == nil)
    // Запись 16-го дня (высокий), сегодня 21-й (низкий).
    #expect(hint(day: day(9, 20), today: day(9, 25)) == .strong)
}

@Test func noHintAfterFiveDays() {
    #expect(hint(day: day(9, 14), today: day(9, 19)) == .strong)
    #expect(hint(day: day(9, 14), today: day(9, 20)) == nil)
}

@Test func noHintForFutureDay() {
    #expect(hint(day: day(9, 17), today: day(9, 16)) == nil)
}
