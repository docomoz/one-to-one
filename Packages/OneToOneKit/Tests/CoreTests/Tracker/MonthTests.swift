import Testing
@testable import Core

@Test func monthGridStartsOnMonday() {
    // 1 октября 2026 — четверг: перед ним три пустые клетки (пн, вт, ср).
    let cells = Month(year: 2026, month: 10).cells

    #expect(cells.prefix(3) == [nil, nil, nil])
    #expect(cells[3] == DayKey(year: 2026, month: 10, day: 1))
    #expect(cells.compactMap { $0 }.count == 31)
    #expect(cells.last == DayKey(year: 2026, month: 10, day: 31))
}

@Test func monthGridMondayFirstHasNoGap() {
    // 1 июня 2026 — понедельник.
    let cells = Month(year: 2026, month: 6).cells

    #expect(cells.first == DayKey(year: 2026, month: 6, day: 1))
    #expect(cells.count == 30)
}

@Test func monthGridKnowsLeapFebruary() {
    #expect(Month(year: 2028, month: 2).cells.compactMap { $0 }.count == 29)
    #expect(Month(year: 2026, month: 2).cells.compactMap { $0 }.count == 28)
}

@Test func monthAddingCrossesYear() {
    #expect(Month(year: 2026, month: 12).adding(months: 1) == Month(year: 2027, month: 1))
    #expect(Month(year: 2026, month: 1).adding(months: -1) == Month(year: 2025, month: 12))
}

@Test func monthOfDay() {
    #expect(Month(DayKey(year: 2026, month: 10, day: 10)) == Month(year: 2026, month: 10))
}

@Test func monthTitleInRussian() {
    #expect(Month(year: 2026, month: 10).title == "Октябрь 2026")
}
