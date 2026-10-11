import Core
import Foundation

/// Разбирает `AppData` на записи синхронизации и собирает обратно. Кэши и «кто я» не синхронизируются.
public enum SyncRecordMapper {
    /// Поля `AppData`, которые едут партнёру. `watchedAt` едет внутри записей `watched:<id>`.
    public static let syncedFields: Set<String> = [
        "couple", "togetherSince",
        "sexEntries", "periodDays", "herMoods", "symptoms",
        "watchlist", "sessions", "swipes", "watched", "watchedAt", "ratings",
    ]
    /// Поля только этого телефона: у каждого партнёра свой `meID`, `movieCache` — кэш Кинопоиска.
    public static let localFields: Set<String> = ["meID", "movieCache"]

    /// Все синхронизируемые значения: id записи → JSON. Кэши не входят.
    public static func payloads(from data: AppData) -> [String: Data] {
        var result: [String: Data] = [:]
        let json = SyncJSON()
        func put(_ id: String, _ value: some Encodable) { result[id] = json.encode(value) }

        if let couple = data.couple { put(SyncRecordID.couple, couple) }
        if let day = data.togetherSince { put(SyncRecordID.togetherSince, day) }

        for entry in data.sexEntries { result[SyncRecordID.sex(entry)] = json.encodeSorted(entry) }
        for day in data.periodDays { put(SyncRecordID.period(day), day) }
        for (day, mood) in data.herMoods { put(SyncRecordID.herMood(day), mood) }
        for (day, symptoms) in data.symptoms { put(SyncRecordID.symptoms(day), SyncJSON.sorted(symptoms)) }

        for item in data.watchlist { put(SyncRecordID.watchlist(item), item) }
        for session in data.sessions { put(SyncRecordID.session(session), session) }
        // Передумал в том же подборе — у свайпов один id, в записи остаётся последний по времени.
        let chronological = data.swipes.enumerated()
            .sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
        for (_, swipe) in chronological { put(SyncRecordID.swipe(swipe), swipe) }
        // Дата «Смотрим» без отметки «посмотрели» не бывает (`markWatched` ставит обе), её не берём.
        for movieID in data.watched { put(SyncRecordID.watched(movieID), data.watchedAt[movieID]) }
        for rating in data.ratings { put(SyncRecordID.rating(rating), rating) }
        return result
    }

    /// Подменяет в `data` все синхронизируемые поля значениями из `payloads`; локальные поля не трогает.
    /// Записи незнакомого вида (из новой версии приложения) и битые пропускает.
    public static func apply(_ payloads: [String: Data], to data: AppData) -> AppData {
        var result = data
        result.clearSyncedFields()
        for (id, payload) in payloads {
            guard let (kind, key) = SyncRecordID.split(id) else { continue }
            result.apply(kind: kind, key: key, payload: payload)
        }
        result.sortSyncedArrays()
        return result
    }
}

private extension AppData {
    // Начинаем с `data`, а не с пустого `AppData()`: новое локальное поле не сотрётся, даже если его забыли здесь.
    mutating func clearSyncedFields() {
        couple = nil
        togetherSince = nil
        sexEntries = []
        periodDays = []
        herMoods = [:]
        symptoms = [:]
        watchlist = []
        sessions = []
        swipes = []
        watched = []
        watchedAt = [:]
        ratings = []
    }

    mutating func apply(kind: Substring, key: Substring, payload: Data) {
        switch kind {
        case "couple" where key == "main":
            couple = SyncJSON.decode(Couple.self, from: payload)
        case "togetherSince" where key == "main":
            togetherSince = SyncJSON.decode(DayKey.self, from: payload)
        case "sex":
            if let entry = SyncJSON.decode(SexEntry.self, from: payload) { sexEntries.append(entry) }
        case "period":
            if let day = SyncJSON.decode(DayKey.self, from: payload) { periodDays.insert(day) }
        case "herMood":
            guard let day = SyncRecordID.day(key) else { return }
            herMoods[day] = SyncJSON.decode(HerMood.self, from: payload)
        case "symptoms":
            guard let day = SyncRecordID.day(key) else { return }
            symptoms[day] = SyncJSON.decode([Symptom].self, from: payload).map(Set.init)
        case "watchlist":
            if let item = SyncJSON.decode(WatchlistItem.self, from: payload) { watchlist.append(item) }
        case "session":
            if let session = SyncJSON.decode(PickSession.self, from: payload) { sessions.append(session) }
        case "swipe":
            if let swipe = SyncJSON.decode(Swipe.self, from: payload) { swipes.append(swipe) }
        case "watched":
            // Значение — дата «Смотрим» или `null`; `nil` здесь только у битой записи.
            guard let movieID = Int(key), let date = SyncJSON.decode(Date?.self, from: payload) else { return }
            watched.insert(movieID)
            if let date { watchedAt[movieID] = date }
        case "rating":
            if let rating = SyncJSON.decode(MovieRating.self, from: payload) { ratings.append(rating) }
        default:
            return
        }
    }

    /// Порядок записей на сервере не хранится, а в массивах он важен (`sessions.last` — текущий подбор,
    /// совпадения идут по времени свайпов). Сортируем по времени, при равенстве — по id записи.
    mutating func sortSyncedArrays() {
        sexEntries.sort(by: \.day, then: SyncRecordID.sex)
        watchlist.sort(by: \.addedAt, then: SyncRecordID.watchlist)
        sessions.sort(by: \.startedAt, then: SyncRecordID.session)
        swipes.sort(by: \.date, then: SyncRecordID.swipe)
        ratings.sort(by: \.date, then: SyncRecordID.rating)
    }
}

private extension Array {
    /// По `key`, при равенстве — по id записи (его строим только тогда, это дороже).
    mutating func sort<Key: Comparable>(by key: (Element) -> Key, then id: (Element) -> String) {
        sort { key($0) != key($1) ? key($0) < key($1) : id($0) < id($1) }
    }
}
