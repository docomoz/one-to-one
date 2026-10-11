import Core
import Foundation

/// JSON значений в записях. Типы те же, что в `AppData.json` (даты — секунды от 1 января 2001),
/// ключи по алфавиту, множества — отсортированными массивами: одно значение всегда даёт одни и те же байты,
/// иначе движок синхронизации увидит правку там, где её не было.
struct SyncJSON {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    /// Бросить может только нечисловой Double, а такой не сохранился бы и в `AppData.json`.
    func encode(_ value: some Encodable) -> Data {
        try! encoder.encode(value)
    }

    /// `SexEntry` с видами секса по алфавиту: множество `types` в обычном JSON идёт в случайном порядке.
    func encodeSorted(_ entry: SexEntry) -> Data {
        // SexEntry всегда кодируется в JSON-объект, поэтому `!` не сработает.
        var object = try! JSONSerialization.jsonObject(with: encode(entry)) as! [String: Any]
        object["types"] = entry.types.map(\.rawValue).sorted()
        return try! JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
    }

    /// Битая запись или запись другой версии — `nil`, её пропускаем.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }

    /// Порядок симптомов в записи: сначала готовые, потом свои, внутри по алфавиту.
    static func sorted(_ symptoms: Set<Symptom>) -> [Symptom] {
        symptoms.sorted { order($0) < order($1) }
    }

    private static func order(_ symptom: Symptom) -> (Int, String) {
        switch symptom {
        case .preset(let preset): (0, preset.rawValue)
        case .custom(let text): (1, text)
        }
    }
}
