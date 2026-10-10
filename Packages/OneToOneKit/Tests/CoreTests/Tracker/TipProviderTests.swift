import Testing
@testable import Core

private func forecast(_ phase: CyclePhase, day: Int? = 10) -> CycleForecast {
    CycleForecast(phase: phase, dayOfCycle: day, averageLength: 28,
                  nextPeriodStart: day == nil ? nil : DayKey(year: 2026, month: 10, day: 29))
}

@Test func herMoodOverridesPhase() {
    let ovulation = forecast(.ovulation, day: 14)

    #expect(TipProvider.tip(forecast: ovulation, herMood: .leaveMeAlone)
        == Tip(text: "Сегодня лучше не подходить. Серьёзно.", isEstimate: false))
    #expect(TipProvider.tip(forecast: ovulation, herMood: .wants)
        == Tip(text: "Она сама сказала, что хочет 😏", isEstimate: false))
    #expect(TipProvider.tip(forecast: ovulation, herMood: .neutral)
        == Tip(text: "Обычный день. Действуй по обстановке", isEstimate: false))
}

@Test func herMoodOverridesUnknown() {
    let tip = TipProvider.tip(forecast: forecast(.unknown, day: nil), herMood: .wants)

    #expect(tip == Tip(text: "Она сама сказала, что хочет 😏", isEstimate: false))
}

@Test(arguments: [CyclePhase.menstruation, .follicular, .ovulation, .luteal])
func estimateFlagForPhase(_ phase: CyclePhase) {
    let tip = TipProvider.tip(forecast: forecast(phase), herMood: nil)

    let threeDays = (1...3).map { TipProvider.tip(forecast: forecast(phase, day: $0), herMood: nil).text }

    #expect(tip.isEstimate)
    #expect(!tip.text.isEmpty)
    #expect(Set(threeDays).count == 3)
}

@Test func unknownPhaseText() {
    let tip = TipProvider.tip(forecast: forecast(.unknown, day: nil), herMood: nil)

    #expect(tip == Tip(text: "Пусть она отметит цикл, и тут появятся подсказки", isEstimate: false))
}

@Test func sameDaySameText() {
    let first = TipProvider.tip(forecast: forecast(.menstruation, day: 2), herMood: nil)
    let again = TipProvider.tip(forecast: forecast(.menstruation, day: 2), herMood: nil)
    let threeDays = (1...3).map { TipProvider.tip(forecast: forecast(.menstruation, day: $0), herMood: nil).text }

    #expect(first == again)
    #expect(Set(threeDays).count == 3)
}
