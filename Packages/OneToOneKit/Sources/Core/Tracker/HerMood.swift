/// Настроение дня, которое отмечает она. Подписи: «Хочу», «Обычно», «Не трогать».
public enum HerMood: String, Codable, CaseIterable, Sendable {
    case wants, neutral, leaveMeAlone
}
