import CryptoKit
import Foundation

/// Общий формат конверта для записей и завёрнутого ключа:
/// байт версии `0x01`, затем AES-256-GCM combined (nonce 12 байт + шифротекст + тег 16 байт).
/// Подробно в `docs/crypto.md`.
enum Envelope {
    static let version: UInt8 = 0x01
    private static let nonceSize = 12
    private static let tagSize = 16

    static func seal(_ plaintext: Data, key: SymmetricKey, aad: Data, nonce: AES.GCM.Nonce = AES.GCM.Nonce()) throws(CryptoError) -> Data {
        let box: AES.GCM.SealedBox
        do {
            box = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad)
        } catch {
            // AES.GCM.seal падает только при неверном ключе: у нас ключ всегда 32 байта.
            throw .invalidKey
        }
        // `combined` пуст только при nonce нестандартной длины, а у нас всегда 12 байт.
        guard let combined = box.combined else { throw .invalidEnvelope }
        return Data([version]) + combined
    }

    static func open(_ envelope: Data, key: SymmetricKey, aad: Data) throws(CryptoError) -> Data {
        guard let first = envelope.first else { throw .invalidEnvelope }
        guard first == version else { throw .unsupportedVersion }
        let body = envelope.dropFirst()
        guard body.count >= nonceSize + tagSize,
              let box = try? AES.GCM.SealedBox(combined: body)
        else { throw .invalidEnvelope }
        do {
            return try AES.GCM.open(box, using: key, authenticating: aad)
        } catch {
            throw .authenticationFailed
        }
    }
}
