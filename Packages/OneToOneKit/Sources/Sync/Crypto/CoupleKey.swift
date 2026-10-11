import CryptoKit
import Foundation

/// Общий ключ пары: 256 бит для AES-GCM. Живёт только на устройствах партнёров (Keychain),
/// на сервер уходит только завёрнутым для конкретного устройства (`KeyExchange.wrap`).
public struct CoupleKey: Sendable, Equatable {
    let symmetricKey: SymmetricKey

    /// Новый случайный ключ.
    public init() {
        symmetricKey = SymmetricKey(size: .bits256)
    }

    public init(rawRepresentation: Data) throws(CryptoError) {
        guard rawRepresentation.count == 32 else { throw .invalidKey }
        symmetricKey = SymmetricKey(data: rawRepresentation)
    }

    /// 32 байта ключа: так он хранится в Keychain.
    public var rawRepresentation: Data {
        symmetricKey.withUnsafeBytes { Data($0) }
    }
}

public enum CryptoError: Error, Equatable {
    /// Ключ неверной длины или открытый ключ, с которым нельзя договориться.
    case invalidKey
    /// Конверт обрезан или испорчен так, что его не разобрать.
    case invalidEnvelope
    /// Конверт другой версии формата: например, от более новой версии приложения.
    case unsupportedVersion
    /// Чужой ключ, чужой документ или подделка: AES-GCM не сошёлся.
    case authenticationFailed
}

extension Data {
    /// Байты строчными hex-цифрами: «0a1b…».
    var hexString: String {
        let digits = Array("0123456789abcdef".utf8)
        return String(decoding: flatMap { [digits[Int($0 >> 4)], digits[Int($0 & 0x0f)]] }, as: UTF8.self)
    }
}
