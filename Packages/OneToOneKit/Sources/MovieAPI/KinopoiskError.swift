/// Ошибки каталога Кинопоиска.
public enum KinopoiskError: Error, Equatable {
    /// 401: ключа нет или он неверный.
    case unauthorized
    /// 403: доступ запрещён. Чаще всего закончились бесплатные 200 запросов на сегодня.
    case forbidden
    /// Любой другой неуспешный ответ сервера.
    case http(status: Int)
    /// Сервер ответил, но не тем, что мы умеем читать.
    case badResponse
}
