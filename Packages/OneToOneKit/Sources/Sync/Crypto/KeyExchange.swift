import CryptoKit
import Foundation

/// Пара ключей X25519 одного устройства для передачи ключа пары.
/// Для каждого обмена создаётся новая; закрытый ключ не покидает устройство.
public struct KeyExchangePair: Sendable {
    let privateKey: Curve25519.KeyAgreement.PrivateKey

    /// Новая случайная пара.
    public init() {
        privateKey = Curve25519.KeyAgreement.PrivateKey()
    }

    public init(rawPrivateKey: Data) throws(CryptoError) {
        guard rawPrivateKey.count == 32,
              let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: rawPrivateKey)
        else { throw .invalidKey }
        privateKey = key
    }

    public var rawPrivateKey: Data { privateKey.rawRepresentation }

    /// 32 байта: это уходит на сервер.
    public var publicKey: Data { privateKey.publicKey.rawRepresentation }
}

/// Передача ключа пары с одного устройства на другое через сервер, который не должен его узнать.
public enum KeyExchange {
    /// 6 цифр из SHA-256(меньший ключ || больший ключ): одинаково на обоих устройствах, порядок ключей не важен.
    /// Партнёры сверяют код голосом или в переписке; если сервер подменил ключи, коды разные.
    public static func verificationCode(_ a: Data, _ b: Data) -> String {
        let (low, high) = a.lexicographicallyPrecedes(b) ? (a, b) : (b, a)
        let digest = Array(SHA256.hash(data: low + high))
        // Первые 4 байта как беззнаковое число big-endian, остаток от деления на миллион.
        let number = digest.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        let code = String(number % 1_000_000)
        return String(repeating: "0", count: 6 - code.count) + code
    }

    /// Ключ обёртки = HKDF-SHA256(общий секрет X25519, salt: пусто, info: "one-to-one key-wrap v1"), затем AES.GCM.
    /// Формат результата как у конверта записи, без AAD.
    public static func wrap(_ key: CoupleKey, from: KeyExchangePair, to peerPublicKey: Data) throws(CryptoError) -> Data {
        try wrap(key, from: from, to: peerPublicKey, nonce: AES.GCM.Nonce())
    }

    public static func unwrap(_ wrapped: Data, with: KeyExchangePair, from peerPublicKey: Data) throws(CryptoError) -> CoupleKey {
        let raw = try Envelope.open(wrapped, key: wrapKey(from: with, to: peerPublicKey), aad: Data())
        return try CoupleKey(rawRepresentation: raw)
    }

    /// С заданным nonce: только для тестовых векторов. В приложении nonce всегда случайный.
    static func wrap(_ key: CoupleKey, from: KeyExchangePair, to peerPublicKey: Data, nonce: AES.GCM.Nonce) throws(CryptoError) -> Data {
        try Envelope.seal(key.rawRepresentation, key: wrapKey(from: from, to: peerPublicKey), aad: Data(), nonce: nonce)
    }

    /// Одинаковый на обоих устройствах: X25519 даёт один и тот же общий секрет с обеих сторон.
    static func wrapKey(from own: KeyExchangePair, to peerPublicKey: Data) throws(CryptoError) -> SymmetricKey {
        guard peerPublicKey.count == 32,
              let peer = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey),
              let shared = try? own.privateKey.sharedSecretFromKeyAgreement(with: peer)
        else { throw .invalidKey }
        return shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("one-to-one key-wrap v1".utf8),
            outputByteCount: 32
        )
    }
}
