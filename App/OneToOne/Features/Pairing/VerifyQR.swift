/// QR для сверки кода вживую: телефон без ключа показывает его рядом с 6 цифрами, телефон с ключом сканирует
/// своей камерой вместо того, чтобы сверять цифры глазами. Внутри id запроса ключа и тот же код сверки:
/// совпадение кода из QR с кодом на телефоне с ключом значит ровно то же, что совпадение цифр на экранах.
/// Сканируем только камерой внутри приложения: ссылку в мессенджере мог бы прислать кто угодно.
enum VerifyQR {
    struct Scanned: Equatable {
        let requestID: String
        let code: String
    }

    private static let prefix = "one-to-one:verify:"

    static let wrongQRMessage = "Это не тот QR-код. Отсканируй код с экрана телефона, который просит ключ, или сверьте цифры."

    /// `one-to-one:verify:<id запроса>:<6 цифр>`.
    static func payload(requestID: String, code: String) -> String {
        "\(prefix)\(requestID):\(code)"
    }

    static func parse(_ text: String) -> Scanned? {
        guard text.hasPrefix(prefix) else { return nil }
        let parts = text.dropFirst(prefix.count).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].count == 6, parts[1].allSatisfy(\.isASCII),
              parts[1].allSatisfy(\.isNumber)
        else { return nil }
        return Scanned(requestID: String(parts[0]), code: String(parts[1]))
    }
}
