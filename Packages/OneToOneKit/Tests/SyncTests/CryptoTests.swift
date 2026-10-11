import CryptoKit
import Foundation
import Testing
@testable import Sync

private let plaintext = Data(#"{"flow":"medium"}"#.utf8)
private let coupleID = "6708f1c2a9b3e4d5c6f7"

// MARK: - Конверт записи

@Test func sealOpenRoundTrip() throws {
    let key = CoupleKey()
    let envelope = try RecordCipher.seal(plaintext, documentID: "doc1", coupleID: coupleID, key: key)

    #expect(try RecordCipher.open(envelope, documentID: "doc1", coupleID: coupleID, key: key) == plaintext)
    #expect(envelope.count == 1 + 12 + plaintext.count + 16)
}

@Test func sealUsesFreshNonceEachTime() throws {
    let key = CoupleKey()
    let first = try RecordCipher.seal(plaintext, documentID: "doc1", coupleID: coupleID, key: key)
    let second = try RecordCipher.seal(plaintext, documentID: "doc1", coupleID: coupleID, key: key)

    #expect(first != second)
}

@Test func openWithOtherKeyFails() throws {
    let envelope = try RecordCipher.seal(plaintext, documentID: "doc1", coupleID: coupleID, key: CoupleKey())

    #expect(throws: CryptoError.authenticationFailed) {
        try RecordCipher.open(envelope, documentID: "doc1", coupleID: coupleID, key: CoupleKey())
    }
}

@Test func openWithOtherDocumentIDFails() throws {
    // Сервер не может переставить конверт в другой документ или в другую пару.
    let key = CoupleKey()
    let envelope = try RecordCipher.seal(plaintext, documentID: "doc1", coupleID: coupleID, key: key)

    #expect(throws: CryptoError.authenticationFailed) {
        try RecordCipher.open(envelope, documentID: "doc2", coupleID: coupleID, key: key)
    }
    #expect(throws: CryptoError.authenticationFailed) {
        try RecordCipher.open(envelope, documentID: "doc1", coupleID: "other-couple", key: key)
    }
}

@Test func tamperedEnvelopeFails() throws {
    let key = CoupleKey()
    var envelope = try RecordCipher.seal(plaintext, documentID: "doc1", coupleID: coupleID, key: key)
    envelope[envelope.count - 20] ^= 0x01

    #expect(throws: CryptoError.authenticationFailed) {
        try RecordCipher.open(envelope, documentID: "doc1", coupleID: coupleID, key: key)
    }
}

@Test func envelopeStartsWithVersion1() throws {
    let envelope = try RecordCipher.seal(plaintext, documentID: "doc1", coupleID: coupleID, key: CoupleKey())

    #expect(envelope.first == 0x01)
}

@Test func unknownVersionRejected() throws {
    let key = CoupleKey()
    var envelope = try RecordCipher.seal(plaintext, documentID: "doc1", coupleID: coupleID, key: key)
    envelope[envelope.startIndex] = 0x02

    #expect(throws: CryptoError.unsupportedVersion) {
        try RecordCipher.open(envelope, documentID: "doc1", coupleID: coupleID, key: key)
    }
}

@Test func truncatedEnvelopeRejected() {
    let key = CoupleKey()

    #expect(throws: CryptoError.invalidEnvelope) {
        try RecordCipher.open(Data(), documentID: "doc1", coupleID: coupleID, key: key)
    }
    #expect(throws: CryptoError.invalidEnvelope) {
        try RecordCipher.open(Data([0x01]) + Data(count: 27), documentID: "doc1", coupleID: coupleID, key: key)
    }
}

// MARK: - Ключ пары

@Test func coupleKeyIs32RandomBytes() throws {
    let key = CoupleKey()

    #expect(key.rawRepresentation.count == 32)
    #expect(key != CoupleKey())
    #expect(try CoupleKey(rawRepresentation: key.rawRepresentation) == key)
}

@Test func coupleKeyOfWrongLengthRejected() {
    #expect(throws: CryptoError.invalidKey) { try CoupleKey(rawRepresentation: Data(count: 16)) }
    #expect(throws: CryptoError.invalidKey) { try CoupleKey(rawRepresentation: Data(count: 33)) }
}

// MARK: - Непрозрачный id документа

@Test func sameRecordIDSameDocumentID() {
    let key = CoupleKey()

    #expect(RecordIDHasher.documentID(for: "period:2026-10-11", key: key)
        == RecordIDHasher.documentID(for: "period:2026-10-11", key: key))
    #expect(RecordIDHasher.documentID(for: "period:2026-10-11", key: key)
        != RecordIDHasher.documentID(for: "period:2026-10-12", key: key))
}

@Test func documentIDDiffersBetweenCouples() {
    #expect(RecordIDHasher.documentID(for: "period:2026-10-11", key: CoupleKey())
        != RecordIDHasher.documentID(for: "period:2026-10-11", key: CoupleKey()))
}

@Test func documentIDIs32Hex() {
    let id = RecordIDHasher.documentID(for: "period:2026-10-11", key: CoupleKey())

    #expect(id.count == 32)
    #expect(id.allSatisfy { "0123456789abcdef".contains($0) })
}

@Test func documentIDDoesNotContainRecordID() {
    let id = RecordIDHasher.documentID(for: "period:2026-10-11", key: CoupleKey())

    #expect(!id.contains("period"))
    #expect(!id.contains("2026"))
}

// MARK: - Обмен ключами

@Test func wrapUnwrapDeliversSameKey() throws {
    let coupleKey = CoupleKey()
    let partner = KeyExchangePair()
    let newPhone = KeyExchangePair()

    let wrapped = try KeyExchange.wrap(coupleKey, from: partner, to: newPhone.publicKey)

    #expect(try KeyExchange.unwrap(wrapped, with: newPhone, from: partner.publicKey) == coupleKey)
    #expect(!wrapped.contains(coupleKey.rawRepresentation))
}

@Test func unwrapByStrangerFails() throws {
    let partner = KeyExchangePair()
    let newPhone = KeyExchangePair()
    let wrapped = try KeyExchange.wrap(CoupleKey(), from: partner, to: newPhone.publicKey)

    #expect(throws: CryptoError.authenticationFailed) {
        try KeyExchange.unwrap(wrapped, with: KeyExchangePair(), from: partner.publicKey)
    }
}

@Test func keyExchangePairRestoresFromPrivateKey() throws {
    let pair = KeyExchangePair()
    let restored = try KeyExchangePair(rawPrivateKey: pair.rawPrivateKey)

    #expect(restored.publicKey == pair.publicKey)
    #expect(pair.publicKey.count == 32)
    #expect(throws: CryptoError.invalidKey) { try KeyExchangePair(rawPrivateKey: Data(count: 31)) }
}

@Test func wrapForInvalidPublicKeyRejected() {
    #expect(throws: CryptoError.invalidKey) {
        try KeyExchange.wrap(CoupleKey(), from: KeyExchangePair(), to: Data(count: 5))
    }
}

@Test func verificationCodeSameOnBothSides() {
    let a = KeyExchangePair().publicKey
    let b = KeyExchangePair().publicKey
    let code = KeyExchange.verificationCode(a, b)

    #expect(code == KeyExchange.verificationCode(b, a))
    #expect(code.count == 6)
    #expect(code.allSatisfy(\.isASCII) && code.allSatisfy(\.isNumber))
}

@Test func verificationCodeKeepsLeadingZeros() {
    // Ищем пару ключей, чей код меньше 100000: на 1000 попыток такая находится почти наверняка.
    let a = Data(repeating: 0x01, count: 32)
    let code = (0..<1000)
        .lazy
        .map { KeyExchange.verificationCode(a, Data(count: 30) + Data([UInt8($0 / 256), UInt8($0 % 256)])) }
        .first { $0.hasPrefix("0") }

    #expect(code?.count == 6)
}

@Test func substitutedPublicKeyGivesDifferentCode() {
    // Сервер подменил открытый ключ партнёра `b` своим `c`: коды на телефонах не совпадут.
    let a = KeyExchangePair().publicKey
    let b = KeyExchangePair().publicKey
    let c = KeyExchangePair().publicKey

    #expect(KeyExchange.verificationCode(a, b) != KeyExchange.verificationCode(a, c))
}

// MARK: - Тестовые векторы из docs/crypto.md

/// Строки вида `имя = значение` из блоков с векторами в `docs/crypto.md`.
private func docVectors() throws -> [String: String] {
    let doc = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SyncTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // OneToOneKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // корень репозитория
        .appending(path: "docs/crypto.md")
    let text = try String(contentsOf: doc, encoding: .utf8)
    var vectors: [String: String] = [:]
    for line in text.split(separator: "\n") {
        let parts = line.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { continue }
        let name = parts[0].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name.allSatisfy({ $0.isLowercase || $0 == "_" || $0.isNumber }) else { continue }
        vectors[name] = parts[1].trimmingCharacters(in: .whitespaces)
    }
    return vectors
}

private func hex(_ string: String?) throws -> Data {
    let digits = Array(try #require(string))
    try #require(digits.count.isMultiple(of: 2))
    return Data(try stride(from: 0, to: digits.count, by: 2).map { index in
        try #require(UInt8(String(digits[index...index + 1]), radix: 16))
    })
}

@Test func testVectorsMatchDocs() throws {
    let v = try docVectors()

    // Запись.
    let coupleKey = try CoupleKey(rawRepresentation: hex(v["couple_key"]))
    let coupleID = try #require(v["couple_id"])
    let recordID = try #require(v["record_id"])
    #expect(RecordIDHasher.idKey(for: coupleKey).withUnsafeBytes { Data($0) }.hexString == v["record_id_key"])
    let documentID = RecordIDHasher.documentID(for: recordID, key: coupleKey)
    #expect(documentID == v["document_id"])

    let plaintext = Data(try #require(v["plaintext"]).utf8)
    let nonce = try AES.GCM.Nonce(data: hex(v["nonce"]))
    let envelope = try RecordCipher.seal(plaintext, documentID: documentID, coupleID: coupleID, key: coupleKey, nonce: nonce)
    #expect(envelope.hexString == v["envelope"])
    #expect(try RecordCipher.open(hex(v["envelope"]), documentID: documentID, coupleID: coupleID, key: coupleKey) == plaintext)

    // Обмен ключами: пары из RFC 7748, раздел 6.1.
    let a = try KeyExchangePair(rawPrivateKey: hex(v["private_a"]))
    let b = try KeyExchangePair(rawPrivateKey: hex(v["private_b"]))
    #expect(a.publicKey.hexString == v["public_a"])
    #expect(b.publicKey.hexString == v["public_b"])
    let shared = try a.privateKey.sharedSecretFromKeyAgreement(with: .init(rawRepresentation: b.publicKey))
    #expect(shared.withUnsafeBytes { Data($0) }.hexString == v["shared_secret"])
    #expect(try KeyExchange.wrapKey(from: a, to: b.publicKey).withUnsafeBytes { Data($0) }.hexString == v["wrap_key"])
    #expect(KeyExchange.verificationCode(a.publicKey, b.publicKey) == v["verification_code"])

    let wrapNonce = try AES.GCM.Nonce(data: hex(v["wrap_nonce"]))
    let wrapped = try KeyExchange.wrap(coupleKey, from: a, to: b.publicKey, nonce: wrapNonce)
    #expect(wrapped.hexString == v["wrapped_key"])
    #expect(try KeyExchange.unwrap(hex(v["wrapped_key"]), with: b, from: a.publicKey) == coupleKey)
}
