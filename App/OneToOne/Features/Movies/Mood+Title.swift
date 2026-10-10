import Core

extension Mood {
    /// Подпись на плитке настроения и в заголовке подбора.
    var title: String {
        switch self {
        case .laugh: "Посмеяться"
        case .light: "Что-то лёгкое"
        case .thrill: "Пощекотать нервы"
        case .cry: "Поплакать"
        case .immerse: "Залипнуть"
        case .romance: "Романтика"
        }
    }

    var emoji: String {
        switch self {
        case .laugh: "😂"
        case .light: "🍿"
        case .thrill: "😱"
        case .cry: "😢"
        case .immerse: "🌀"
        case .romance: "💞"
        }
    }
}
