import Foundation

/// Событие пары, до которого осталось немного дней: день рождения или годовщина.
public enum UpcomingEvent: Hashable, Sendable {
    case birthday(UpcomingBirthday)
    case anniversary(UpcomingAnniversary)

    /// 0 — сегодня, 1 — завтра.
    public var daysLeft: Int {
        switch self {
        case .birthday(let birthday): birthday.daysLeft
        case .anniversary(let anniversary): anniversary.daysLeft
        }
    }

    /// Порядок в один день: день рождения выше годовщины.
    fileprivate var kindOrder: Int {
        switch self {
        case .birthday: 0
        case .anniversary: 1
        }
    }
}

/// Собирает ближайшие события пары для главного экрана.
public enum UpcomingEvents {
    /// Дни рождения и годовщина в окне 30 дней, ближайшее первым; в один день — день рождения.
    public static func list(_ data: AppData, today: DayKey) -> [UpcomingEvent] {
        var events: [UpcomingEvent] = []
        if let couple = data.couple,
           let birthday = BirthdayCalculator.upcoming(couple: couple, meID: data.meID, today: today) {
            events.append(.birthday(birthday))
        }
        if let anniversary = AnniversaryCalculator.upcoming(since: data.togetherSince, today: today) {
            events.append(.anniversary(anniversary))
        }
        // `sorted` не обещает сохранить порядок равных, поэтому вид события — часть ключа.
        return events.sorted { ($0.daysLeft, $0.kindOrder) < ($1.daysLeft, $1.kindOrder) }
    }
}
