/// Почему не получилось войти, словами для человека.
enum AuthError: Error, Equatable {
    case wrongCode, invalidEmail, tooManyAttempts, signedOut, network, server

    /// На каком шаге входа пришла ошибка сервера: одна и та же ошибка значит разное.
    enum Step { case sendCode, confirm, other }

    /// Ошибка Appwrite по коду ответа и её типу (`user_invalid_token` и т. п.).
    init(status: Int?, type: String?, step: Step) {
        switch (step, status, type) {
        case (_, 429, _), (_, _, "general_rate_limit_exceeded"):
            self = .tooManyAttempts
        // Неверный, просроченный или не из шести цифр код.
        case (.confirm, 400, _), (.confirm, 401, _):
            self = .wrongCode
        case (.sendCode, 400, _):
            self = .invalidEmail
        // Сессию удалили на сервере или она истекла: нужно войти заново.
        case (.other, 401, _):
            self = .signedOut
        default:
            self = .server
        }
    }

    var message: String {
        switch self {
        case .wrongCode: "Код не подходит. Проверьте цифры из письма или отправьте код ещё раз."
        case .invalidEmail: "Похоже, в адресе почты ошибка. Проверьте его."
        case .tooManyAttempts: "Слишком много попыток. Подождите пару минут и попробуйте снова."
        case .signedOut: "Вы вышли из аккаунта. Войдите по почте ещё раз."
        case .network: "Нет связи с сервером. Проверьте интернет и попробуйте ещё раз."
        case .server: "Сервер не смог выполнить запрос. Попробуйте ещё раз чуть позже."
        }
    }
}
