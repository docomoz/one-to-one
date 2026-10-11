import Core
import Foundation

/// JSON значений в записях. Типы те же, что в `AppData.json` (даты — секунды от 1 января 2001),
/// ключи по алфавиту, множества — отсортированными массивами: одно значение всегда даёт одни и те же байты,
/// иначе движок синхронизации увидит правку там, где её не было.
enum SyncJSON {
    /// Бросить может только нечисловой Double, а такой не сохранился бы и в `AppData.json`.
    static func encode(_ value: some Encodable) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try! encoder.encode(value)
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

/// `SexEntry` с видами секса по алфавиту. Множество `types` в обычном JSON идёт в случайном порядке.
struct SortedSexEntry: Encodable {
    let entry: SexEntry

    func encode(to encoder: Encoder) throws {
        try entry.encode(to: encoder)
        // Тот же контейнер: поле `types` записываем заново, уже отсортированным.
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(entry.types.map(\.rawValue).sorted(), forKey: .types)
    }

    private enum Key: String, CodingKey { case types }
}
