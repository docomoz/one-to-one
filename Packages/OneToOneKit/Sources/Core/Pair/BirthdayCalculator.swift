import Foundation

/// Ближайший день рождения в паре: чей он и сколько до него дней.
public struct UpcomingBirthday: Equatable, Sendable {
    public let person: Person
    /// `true`, если это день рождения того, кто держит телефон.
    public let isMe: Bool
    /// 0 — сегодня, 1 — завтра.
    public let daysLeft: Int

    public init(person: Person, isMe: Bool, daysLeft: Int) {
        self.person = person
        self.isMe = isMe
        self.daysLeft = daysLeft
    }
}

/// Ищет, у кого из пары скоро день рождения. «Сегодня» приходит снаружи, чтобы тесты не зависели от часов.
public enum BirthdayCalculator {
    /// Ближайший день рождения не дальше `within` дней. Если у обоих в один день — партнёра.
    public static func upcoming(couple: Couple, meID: UUID?, today: DayKey, within: Int = 30) -> UpcomingBirthday? {
        // Партнёр первым: `min` при равенстве оставляет первый элемент.
        let people = couple.man.id == meID ? [couple.woman, couple.man] : [couple.man, couple.woman]
        let birthdays = people.compactMap { person -> UpcomingBirthday? in
            guard let birthDate = person.birthDate else { return nil }
            return UpcomingBirthday(person: person, isMe: person.id == meID,
                                    daysLeft: today.days(to: nextBirthday(of: birthDate, from: today)))
        }
        guard let nearest = birthdays.min(by: { $0.daysLeft < $1.daysLeft }), nearest.daysLeft <= within else {
            return nil
        }
        return nearest
    }

    /// Ближайший день рождения начиная с `today`: в этом году, а если уже прошёл — в следующем.
    private static func nextBirthday(of birthDate: DayKey, from today: DayKey) -> DayKey {
        let thisYear = birthDate.occurrence(in: today.year)
        return thisYear >= today ? thisYear : birthDate.occurrence(in: today.year + 1)
    }
}
