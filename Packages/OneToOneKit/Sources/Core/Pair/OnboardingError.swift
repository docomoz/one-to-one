/// Почему знакомство не пускает дальше. `message` показываем на экране как есть.
public enum OnboardingError: Error, Equatable, Sendable {
    case emptyName, noBirthDate, tooYoung, sameSex

    public var message: String {
        switch self {
        case .emptyName: "Введи имя"
        case .noBirthDate: "Выбери дату рождения"
        case .tooYoung: "Приложением можно пользоваться с \(PersonDraft.minimumAge) лет"
        case .sameSex: "Пара — это мужчина и женщина"
        }
    }
}
