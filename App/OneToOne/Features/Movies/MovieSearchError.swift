import Foundation
import MovieAPI

/// Что сказать человеку, если поиск фильмов не удался.
enum MovieSearchError {
    static func message(for error: Error) -> String {
        switch error {
        case KinopoiskError.unauthorized:
            "Нет ключа Кинопоиска. Впишите его в Config/Secrets.xcconfig."
        case KinopoiskError.forbidden:
            "Бесплатные запросы к Кинопоиску на сегодня закончились. Попробуйте завтра."
        case is URLError:
            "Нет интернета. Проверьте связь и попробуйте ещё раз."
        default:
            "Кинопоиск не ответил. Попробуйте ещё раз."
        }
    }
}
