import Foundation
import Security
import Sync

/// Где лежит ключ пары: на телефоне — Keychain, в тестах и превью — память.
protocol CoupleKeyStoring: Sendable {
    func save(_ key: CoupleKey, coupleID: String) throws
    func load(coupleID: String) -> CoupleKey?
    func delete(coupleID: String)
}

/// Ключ пары в Keychain этого телефона: только после первой разблокировки и без iCloud Keychain
/// (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), чтобы ключ не уехал в облако Apple. Одна запись на пару.
struct KeychainKeyStore: CoupleKeyStoring {
    struct SaveFailed: Error {
        let status: OSStatus
    }

    private static let service = "com.docomoz.onetoone.couple-key"

    private func query(coupleID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: coupleID,
        ]
    }

    func save(_ key: CoupleKey, coupleID: String) throws {
        delete(coupleID: coupleID)
        var item = query(coupleID: coupleID)
        item[kSecValueData as String] = key.rawRepresentation
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        item[kSecAttrSynchronizable as String] = false
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw SaveFailed(status: status) }
    }

    func load(coupleID: String) -> CoupleKey? {
        var query = query(coupleID: coupleID)
        query[kSecReturnData as String] = true
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let raw = result as? Data else {
            return nil
        }
        return try? CoupleKey(rawRepresentation: raw)
    }

    func delete(coupleID: String) {
        SecItemDelete(query(coupleID: coupleID) as CFDictionary)
    }
}

/// Ключи в памяти: для тестов и превью.
final class InMemoryKeyStore: CoupleKeyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var keys: [String: CoupleKey] = [:]

    func save(_ key: CoupleKey, coupleID: String) {
        lock.withLock { keys[coupleID] = key }
    }

    func load(coupleID: String) -> CoupleKey? {
        lock.withLock { keys[coupleID] }
    }

    func delete(coupleID: String) {
        lock.withLock { keys[coupleID] = nil }
    }
}
