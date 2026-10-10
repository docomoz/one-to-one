import Foundation
import Testing
@testable import Core

private let today = DayKey(year: 2026, month: 10, day: 10)

/// Данные с парой, где «я» — он, и днём рождения у неё `herBirthday` (месяц, число).
private func data(herBirthday: (Int, Int)? = nil, togetherSince: DayKey? = nil)
    -> (data: AppData, woman: Person) {
    let man = Person(name: "Максюша", sex: .male)
    let woman = Person(name: "Даша", sex: .female,
                       birthDate: herBirthday.map { DayKey(year: 1995, month: $0.0, day: $0.1) })
    var data = AppData()
    if herBirthday != nil {
        data.couple = try! Couple.make(man, woman)
        data.meID = man.id
    }
    data.togetherSince = togetherSince
    return (data, woman)
}

@Test func emptyDataHasNoEvents() {
    #expect(UpcomingEvents.list(AppData(), today: today).isEmpty)
}

@Test func anniversaryWithoutCouple() {
    let events = UpcomingEvents.list(data(togetherSince: DayKey(year: 2023, month: 10, day: 22)).data, today: today)
    #expect(events == [.anniversary(UpcomingAnniversary(years: 3, daysLeft: 12))])
}

@Test func nearestFirst() {
    let sample = data(herBirthday: (10, 30), togetherSince: DayKey(year: 2023, month: 10, day: 15))
    #expect(UpcomingEvents.list(sample.data, today: today) == [
        .anniversary(UpcomingAnniversary(years: 3, daysLeft: 5)),
        .birthday(UpcomingBirthday(person: sample.woman, isMe: false, daysLeft: 20)),
    ])
}

@Test func birthdayFirstOnSameDay() {
    let sample = data(herBirthday: (10, 15), togetherSince: DayKey(year: 2023, month: 10, day: 15))
    #expect(UpcomingEvents.list(sample.data, today: today) == [
        .birthday(UpcomingBirthday(person: sample.woman, isMe: false, daysLeft: 5)),
        .anniversary(UpcomingAnniversary(years: 3, daysLeft: 5)),
    ])
}

@Test func eventDaysLeftComesFromWrappedValue() {
    #expect(UpcomingEvent.anniversary(UpcomingAnniversary(years: 3, daysLeft: 7)).daysLeft == 7)
}
