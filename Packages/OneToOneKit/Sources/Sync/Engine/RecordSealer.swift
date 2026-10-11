import Foundation

/// `SyncRecord` целиком в конверте: сервер не видит ни вида, ни времени правки, ни удаления. Формат в `docs/crypto.md`.
enum RecordSealer {
    /// Документ для отправки. `updatedAt` — время отправки: сервер всё равно ставит своё и знает, когда пришёл запрос.
    static func seal(_ record: SyncRecord, coupleID: String, key: CoupleKey) throws(CryptoError) -> EncryptedRecord {
        let documentID = RecordIDHasher.documentID(for: record.id, key: key)
        let envelope = try seal(record, documentID: documentID, coupleID: coupleID, key: key)
        return EncryptedRecord(documentID: documentID, updatedAt: Date(), envelope: envelope)
    }

    static func seal(_ record: SyncRecord, documentID: String, coupleID: String, key: CoupleKey) throws(CryptoError) -> Data {
        try RecordCipher.seal(plaintext(record), documentID: documentID, coupleID: coupleID, key: key)
    }

    /// `nil` — чужой ключ, подмена, мусор или запись лежит не в своём документе. Такой документ пропускаем.
    static func open(_ envelope: Data, documentID: String, coupleID: String, key: CoupleKey) -> SyncRecord? {
        guard let plaintext = try? RecordCipher.open(envelope, documentID: documentID, coupleID: coupleID, key: key),
              let record = try? JSONDecoder().decode(SyncRecord.self, from: plaintext),
              // Своим ключом конверт мог создать только телефон пары, но и его ошибку в чужом документе не берём.
              RecordIDHasher.documentID(for: record.id, key: key) == documentID
        else { return nil }
        return record
    }

    /// `{"id":…,"payload":base64 или null,"updatedAt":секунды от 1 января 2001}` с ключами по алфавиту.
    private static func plaintext(_ record: SyncRecord) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        // Ошибку даёт только нечисловое время, а `Date` всегда число.
        return try! encoder.encode(Plaintext(record))
    }

    /// Как синтезированный `Codable` у `SyncRecord`, но у удалённой записи пишет `"payload":null`, а не пропускает ключ:
    /// так формат проще повторить на Android и в вебе. Читается обычным `SyncRecord`.
    private struct Plaintext: Encodable {
        let record: SyncRecord

        init(_ record: SyncRecord) { self.record = record }

        enum CodingKeys: String, CodingKey { case id, updatedAt, payload }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(record.id, forKey: .id)
            try container.encode(record.updatedAt, forKey: .updatedAt)
            try container.encode(record.payload, forKey: .payload)
        }
    }
}
