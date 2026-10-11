import CryptoKit
import Foundation

/// Шифрование одной записи пары ключом пары.
public enum RecordCipher {
    /// Конверт: [0x01] + AES.GCM combined (nonce 12 + шифротекст + тег 16). AAD = utf8("\(coupleID)/\(documentID)").
    /// AAD привязывает конверт к документу и паре: сервер не может переставить его в другой документ.
    /// `documentID` — всегда id из `RecordIDHasher` (32 hex), в id пары Appwrite нет `/`: склейка однозначна.
    public static func seal(_ plaintext: Data, documentID: String, coupleID: String, key: CoupleKey) throws(CryptoError) -> Data {
        try seal(plaintext, documentID: documentID, coupleID: coupleID, key: key, nonce: AES.GCM.Nonce())
    }

    public static func open(_ envelope: Data, documentID: String, coupleID: String, key: CoupleKey) throws(CryptoError) -> Data {
        try Envelope.open(envelope, key: key.symmetricKey, aad: aad(documentID: documentID, coupleID: coupleID))
    }

    /// С заданным nonce: только для тестовых векторов. В приложении nonce всегда случайный.
    static func seal(_ plaintext: Data, documentID: String, coupleID: String, key: CoupleKey, nonce: AES.GCM.Nonce) throws(CryptoError) -> Data {
        try Envelope.seal(plaintext, key: key.symmetricKey, aad: aad(documentID: documentID, coupleID: coupleID), nonce: nonce)
    }

    private static func aad(documentID: String, coupleID: String) -> Data {
        Data("\(coupleID)/\(documentID)".utf8)
    }
}
