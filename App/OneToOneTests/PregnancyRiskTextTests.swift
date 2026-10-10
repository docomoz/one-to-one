import Core
import Testing
@testable import OneToOne

@Test func riskTitlesAndDetails() {
    #expect(PregnancyRisk.high.title == "Высокий риск забеременеть")
    #expect(PregnancyRisk.high.detail == "Близко к овуляции: за один раз без защиты шанс до 1 из 3. Надевай презерватив")
    #expect(PregnancyRisk.medium.title == "Средний риск")
    #expect(PregnancyRisk.medium.detail == "Прогноз тут не уверен. Лучше с презервативом")
    #expect(PregnancyRisk.late.title == "Средний риск")
    #expect(PregnancyRisk.late.detail == "Месячные задерживаются, прогноз ненадёжен. Лучше с презервативом")
    #expect(PregnancyRisk.low.title == "Низкий риск, но не ноль")
    #expect(PregnancyRisk.low.detail == "Если прогноз верный, шанс небольшой. Но овуляция может сдвинуться")
    #expect(PregnancyRisk.unknown.title == "Риск неизвестен")
    #expect(PregnancyRisk.unknown.detail == "Отметьте месячные во вкладке „Цикл“. Пока лучше с презервативом")
}

@Test func riskShortTitles() {
    #expect(PregnancyRisk.high.shortTitle == "высокий")
    #expect(PregnancyRisk.medium.shortTitle == "средний")
    #expect(PregnancyRisk.late.shortTitle == "средний, задержка")
    #expect(PregnancyRisk.low.shortTitle == "низкий")
    #expect(PregnancyRisk.unknown.shortTitle == "неизвестен")
}

/// Зелёный не красит дни: полоска только у высокого и среднего (в т. ч. задержки).
@Test func onlyHighAndMediumMarkDays() {
    #expect(PregnancyRisk.high.markColor != nil)
    #expect(PregnancyRisk.medium.markColor != nil)
    #expect(PregnancyRisk.late.markColor != nil)
    #expect(PregnancyRisk.low.markColor == nil)
    #expect(PregnancyRisk.unknown.markColor == nil)
}

@Test func riskDayAccessibility() {
    #expect(PregnancyRisk.high.dayAccessibility == "высокий риск беременности")
    #expect(PregnancyRisk.medium.dayAccessibility == "средний риск беременности")
    #expect(PregnancyRisk.late.dayAccessibility == "средний риск беременности")
    #expect(PregnancyRisk.low.dayAccessibility == nil)
    #expect(PregnancyRisk.unknown.dayAccessibility == nil)
}

/// Календарь получает риск на каждый день месяца, тот же, что считает Core.
@Test func monthRisksCoverEveryDay() {
    let today = DayKey(year: 2026, month: 10, day: 10)
    let periodDays: Set<DayKey> = [DayKey(year: 2026, month: 9, day: 28)]
    let month = Month(today)
    let risks = month.pregnancyRisks(periodDays: periodDays, today: today)

    let days = month.cells.compactMap { $0 }
    #expect(risks.count == days.count)
    for day in days {
        #expect(risks[day] == PregnancyRiskCalculator.risk(on: day, periodDays: periodDays, today: today))
    }
}
