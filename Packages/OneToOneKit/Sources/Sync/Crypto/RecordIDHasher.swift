import CryptoKit
import Foundation

/// Id документа на сервере, по которому не понять вид и дату записи.
public enum RecordIDHasher {
    /// Непрозрачный id документа: первые 16 байт HMAC-SHA256(ключ = HKDF(coupleKey, info: "one-to-one record-id v1"), recordID) в hex (32 символа).
    /// Один и тот же `recordID` в одной паре всегда даёт один и тот же id, поэтому правки записи попадают в тот же документ.
    public static func documentID(for recordID: String, key: CoupleKey) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: Data(recordID.utf8), using: idKey(for: key))
        return Data(mac).prefix(16).hexString
    }

    /// Отдельный ключ для id, чтобы ключ пары не использовался в двух алгоритмах сразу.
    static func idKey(for key: CoupleKey) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: key.symmetricKey,
            salt: Data(),
            info: Data("one-to-one record-id v1".utf8),
            outputByteCount: 32
        )
    }
}
