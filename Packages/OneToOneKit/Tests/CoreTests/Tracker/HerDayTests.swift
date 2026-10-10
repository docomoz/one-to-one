import Testing
@testable import Core

private let oct10 = DayKey(year: 2026, month: 10, day: 10)

@Test func togglePeriodDayMarksAndUnmarks() {
    var data = AppData()

    data.togglePeriodDay(oct10)
    #expect(data.periodDays == [oct10])

    data.togglePeriodDay(oct10)
    #expect(data.periodDays.isEmpty)
}

@Test func setHerMoodReplacesAndClears() {
    var data = AppData()

    data.setHerMood(.wants, for: oct10)
    data.setHerMood(.leaveMeAlone, for: oct10)
    #expect(data.herMoods == [oct10: .leaveMeAlone])

    data.setHerMood(nil, for: oct10)
    #expect(data.herMoods.isEmpty)
}

@Test func toggleSymptomAllowsSeveralPerDay() {
    var data = AppData()

    data.toggleSymptom(.preset(.headache), on: oct10)
    data.toggleSymptom(.custom("Хочу сладкого"), on: oct10)

    #expect(data.symptoms[oct10] == [.preset(.headache), .custom("Хочу сладкого")])
}

@Test func toggleSymptomTwiceRemovesDayWhenEmpty() {
    var data = AppData()

    data.toggleSymptom(.preset(.cramps), on: oct10)
    data.toggleSymptom(.preset(.cramps), on: oct10)

    #expect(data.symptoms[oct10] == nil)
}

@Test func customSymptomIgnoresSurroundingSpacesAndEmptyText() {
    var data = AppData()

    data.toggleSymptom(.custom("  Хочу сладкого "), on: oct10)
    data.toggleSymptom(.custom("   "), on: oct10)

    #expect(data.symptoms[oct10] == [.custom("Хочу сладкого")])
}

@Test func customSymptomsAreRememberedAcrossDays() {
    var data = AppData()
    data.toggleSymptom(.custom("Хочу сладкого"), on: oct10)
    data.toggleSymptom(.custom("Мигрень"), on: oct10.adding(days: -3))
    data.toggleSymptom(.custom("Хочу сладкого"), on: oct10.adding(days: -1))
    data.toggleSymptom(.preset(.headache), on: oct10)

    #expect(data.customSymptoms == ["Мигрень", "Хочу сладкого"])
}

@Test func presetSymptomsHaveRussianTitles() {
    #expect(Symptom.preset(.headache).title == "Болит голова")
    #expect(Symptom.preset(.cramps).title == "Тянет живот")
    #expect(Symptom.custom("Мигрень").title == "Мигрень")
    #expect(PresetSymptom.allCases.count == 10)
}
