/// Настроение вечера, под которое подбираем фильм.
public enum Mood: String, Codable, CaseIterable, Sendable {
    case laugh, light, thrill, cry, immerse, romance

    /// Жанры Кинопоиска, которые подходят настроению.
    public var genres: [String] {
        switch self {
        case .laugh: ["комедия"]
        case .light: ["комедия", "семейный", "мультфильм"]
        case .thrill: ["триллер", "ужасы"]
        case .cry: ["драма"]
        case .immerse: ["фантастика", "детектив", "приключения"]
        case .romance: ["мелодрама"]
        }
    }
}
