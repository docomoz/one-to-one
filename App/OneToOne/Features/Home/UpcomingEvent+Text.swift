import Core

extension UpcomingAnniversary {
    /// Текст плашки годовщины: «Годовщина через 12 дней», «Годовщина завтра», в сам день — поздравление.
    var text: String {
        switch daysLeft {
        case 0: "💞 \(yearsText(years)) вместе! С годовщиной!"
        case 1: "💞 Годовщина завтра"
        default: "💞 Годовщина через \(daysText(daysLeft))"
        }
    }
}

extension UpcomingEvent {
    /// Текст плашки любого ближайшего события.
    var text: String {
        switch self {
        case .birthday(let birthday): birthday.text
        case .anniversary(let anniversary): anniversary.text
        }
    }
}
