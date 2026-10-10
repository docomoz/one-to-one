/// Настроение вечера, под которое подбираем фильм.
/// Жанры для каждого настроения добавит задача колоды (#21).
public enum Mood: String, Codable, CaseIterable, Sendable {
    case laugh, light, thrill, cry, immerse, romance
}
