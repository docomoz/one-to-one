import Foundation
import Testing
@testable import Core

private let today = DayKey(year: 2026, month: 10, day: 10)

/// Пара, где «я» — он. Дни рождения задаются как (месяц, число).
private func couple(his: (Int, Int)? = nil, hers: (Int, Int)? = nil, herYear: Int = 1995)
    -> (couple: Couple, man: Person, woman: Person) {
    let man = Person(name: "Боря", sex: .male, birthDate: his.map { DayKey(year: 1990, month: $0.0, day: $0.1) })
    let woman = Person(name: "Аня", sex: .female, birthDate: hers.map { DayKey(year: herYear, month: $0.0, day: $0.1) })
    return (try! Couple.make(man, woman), man, woman)
}

@Test func noBirthDatesIsNil() {
    let pair = couple()
    #expect(BirthdayCalculator.upcoming(couple: pair.couple, meID: pair.man.id, today: today) == nil)
}

@Test func partnerBirthdayIn12Days() {
    let pair = couple(hers: (10, 22))
    #expect(BirthdayCalculator.upcoming(couple: pair.couple, meID: pair.man.id, today: today)
        == UpcomingBirthday(person: pair.woman, isMe: false, daysLeft: 12))
}

@Test func myBirthdayIsMe() {
    let pair = couple(his: (10, 11))
    #expect(BirthdayCalculator.upcoming(couple: pair.couple, meID: pair.man.id, today: today)
        == UpcomingBirthday(person: pair.man, isMe: true, daysLeft: 1))
}

@Test func birthdayTodayIsZero() {
    let pair = couple(hers: (10, 10))
    #expect(BirthdayCalculator.upcoming(couple: pair.couple, meID: pair.man.id, today: today)?.daysLeft == 0)
}

@Test func birthdayYesterdayIsHidden() {
    let pair = couple(hers: (10, 9))
    #expect(BirthdayCalculator.upcoming(couple: pair.couple, meID: pair.man.id, today: today) == nil)
}

@Test func beyondWindowIsHidden() {
    let far = couple(hers: (11, 10))
    #expect(BirthdayCalculator.upcoming(couple: far.couple, meID: far.man.id, today: today) == nil)

    let edge = couple(hers: (11, 9))
    #expect(BirthdayCalculator.upcoming(couple: edge.couple, meID: edge.man.id, today: today)?.daysLeft == 30)
}

@Test func nearestOfTwoWins() {
    let pair = couple(his: (10, 20), hers: (10, 15))
    #expect(BirthdayCalculator.upcoming(couple: pair.couple, meID: pair.man.id, today: today)
        == UpcomingBirthday(person: pair.woman, isMe: false, daysLeft: 5))
}

@Test func tieGoesToPartner() {
    let pair = couple(his: (10, 15), hers: (10, 15))
    #expect(BirthdayCalculator.upcoming(couple: pair.couple, meID: pair.man.id, today: today)?.isMe == false)
    // И с её телефона партнёр — он.
    #expect(BirthdayCalculator.upcoming(couple: pair.couple, meID: pair.woman.id, today: today)?.person == pair.man)
}

@Test func birthdayAcrossNewYear() {
    let pair = couple(hers: (1, 5))
    let december = DayKey(year: 2026, month: 12, day: 20)
    #expect(BirthdayCalculator.upcoming(couple: pair.couple, meID: pair.man.id, today: december)?.daysLeft == 16)
}

@Test func leapDayBirthdayInCommonYear() {
    let pair = couple(hers: (2, 29), herYear: 1996)
    // 2027 невисокосный: празднуем 1 марта.
    #expect(BirthdayCalculator.upcoming(couple: pair.couple, meID: pair.man.id,
                                        today: DayKey(year: 2027, month: 2, day: 20))?.daysLeft == 9)
    // 2028 високосный: 29 февраля.
    #expect(BirthdayCalculator.upcoming(couple: pair.couple, meID: pair.man.id,
                                        today: DayKey(year: 2028, month: 2, day: 20))?.daysLeft == 9)
}
