import Core

extension UpcomingBirthday {
    /// Текст плашки «скоро». Имя не склоняем, поэтому оно стоит первым: «Даша: День рождения завтра».
    var text: String {
        if isMe {
            switch daysLeft {
            case 0: "🎉 С днём рождения!"
            case 1: "🎂 Твой день рождения завтра"
            default: "🎂 Твой день рождения через \(daysText(daysLeft))"
            }
        } else {
            switch daysLeft {
            case 0: "🎉 \(person.name): День рождения сегодня!"
            case 1: "🎂 \(person.name): День рождения завтра"
            default: "🎂 \(person.name): День рождения через \(daysText(daysLeft))"
            }
        }
    }
}
