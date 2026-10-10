/// Ошибки каталога Кинопоиска.
public enum KinopoiskError: Error, Equatable {
    /// 401: ключа нет или он неверный.
    case unauthorized
    /// 403: закончились бесплатные 200 запросов на сегодня.
    case dailyLimitReached
    /// Любой другой неуспешный ответ сервера.
    case http(status: Int)
}
