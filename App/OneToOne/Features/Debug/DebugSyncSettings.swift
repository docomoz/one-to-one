#if DEBUG
import Foundation
import Security
import Sync

/// Только в отладочной сборке, пока нет пары на сервере (#85): id пары и общий ключ, введённые руками
/// на двух симуляторах. id пары — в UserDefaults, ключ — в Keychain этого устройства (без iCloud).
/// В релизной сборке этого нет, и синхронизация не запускается.
enum DebugSyncSettings {
    private static let coupleIDDefaultsKey = "debugSync.coupleID"
    private static var keychainQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.docomoz.onetoone.debug-sync",
            kSecAttrAccount as String: "coupleKey",
        ]
    }

    /// Сохранённые id пары и ключ, если есть оба.
    static var saved: (coupleID: String, key: CoupleKey)? {
        guard let coupleID = UserDefaults.standard.string(forKey: coupleIDDefaultsKey) else { return nil }
        var query = keychainQuery
        query[kSecReturnData as String] = true
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let raw = result as? Data, let key = try? CoupleKey(rawRepresentation: raw)
        else { return nil }
        return (coupleID, key)
    }

    /// `false` — ключ не записался в Keychain: после перезапуска пару придётся ввести снова.
    @discardableResult
    static func save(coupleID: String, key: CoupleKey) -> Bool {
        clear()
        var item = keychainQuery
        item[kSecValueData as String] = key.rawRepresentation
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { return false }
        UserDefaults.standard.set(coupleID, forKey: coupleIDDefaultsKey)
        return true
    }

    static func clear() {
        SecItemDelete(keychainQuery as CFDictionary)
        UserDefaults.standard.removeObject(forKey: coupleIDDefaultsKey)
    }

    /// При запуске: если на этом симуляторе уже вводили пару, синхронизация продолжается.
    @MainActor static func restore(into model: AppModel) {
        guard !model.isSyncStarted, let saved else { return }
        model.startSync(coupleID: saved.coupleID, key: saved.key)
    }

    /// 64 hex-цифры → ключ. Пробелы, переносы и регистр не важны.
    static func key(fromHex text: String) -> CoupleKey? {
        let digits = Array(text.lowercased().filter { !$0.isWhitespace })
        // `UInt8(_:radix:)` пропустил бы «+f» и «-0».
        guard digits.count == 64, digits.allSatisfy(\.isHexDigit) else { return nil }
        var bytes = Data()
        for index in stride(from: 0, to: digits.count, by: 2) {
            guard let byte = UInt8(String(digits[index...index + 1]), radix: 16) else { return nil }
            bytes.append(byte)
        }
        return try? CoupleKey(rawRepresentation: bytes)
    }

    static func hex(_ key: CoupleKey) -> String {
        key.rawRepresentation.map { String(format: "%02x", $0) }.joined()
    }
}
#endif
