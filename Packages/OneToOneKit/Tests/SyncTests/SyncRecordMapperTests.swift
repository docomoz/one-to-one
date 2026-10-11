import Core
import Foundation
import Testing
@testable import Sync

private let man = Person(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!,
                         name: "Максим", sex: .male, birthDate: DayKey(year: 1990, month: 5, day: 1))
private let woman = Person(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!,
                           name: "Даша", sex: .female)
private let day = DayKey(year: 2026, month: 3, day: 14)
private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
private let sexID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!

private func at(_ seconds: Double) -> Date { Date(timeIntervalSince1970: 1_773_500_000 + seconds) }

private func movie(_ id: Int) -> Movie {
    Movie(id: id, title: "Фильм \(id)", year: 1994, genres: ["драма", "криминал"], overview: "Описание",
          posterURL: URL(string: "https://example.com/\(id).jpg"), imdbID: "tt\(id)",
          ratings: Ratings(imdb: 9.3, kinopoisk: 9.1))
}

/// AppData, где заполнено каждое поле. Массивы в том порядке, в каком их собирает `apply`:
/// по времени (секс — по дню), так данные из записей совпадают с исходными.
private func filledData() throws -> AppData {
    let first = PickSession(id: sessionID, mood: .cry, startedBy: woman.id, startedAt: at(0))
    let second = PickSession(mood: .laugh, startedBy: man.id, startedAt: at(100))

    var data = AppData()
    data.couple = try Couple.make(man, woman)
    data.meID = man.id
    data.togetherSince = DayKey(year: 2020, month: 2, day: 29)
    data.sexEntries = [
        SexEntry(id: sexID, day: day, types: [.vaginal, .cunnilingus, .anal, .blowjob],
                 orgasmsMan: 1, orgasmsWoman: 2, condom: false, finish: .inside, createdBy: man.id),
        SexEntry(day: day.adding(days: 3), types: [.anal], orgasmsMan: 0, orgasmsWoman: 0, createdBy: woman.id),
    ]
    data.periodDays = [day, day.adding(days: 1)]
    data.herMoods = [day: .wants, day.adding(days: 1): .leaveMeAlone]
    data.symptoms = [day: [.preset(.headache), .custom("Мигрень"), .preset(.cramps)], day.adding(days: 2): []]
    data.watchlist = [
        WatchlistItem(movie: movie(326), ownerID: man.id, addedAt: at(10), fromLater: false),
        WatchlistItem(movie: movie(326), ownerID: woman.id, addedAt: at(20), fromLater: true),
    ]
    data.sessions = [first, second]
    data.swipes = [
        Swipe(sessionID: first.id, personID: man.id, movieID: 326, action: .yes, date: at(30)),
        Swipe(sessionID: first.id, personID: woman.id, movieID: 326, action: .yes, date: at(40)),
        Swipe(sessionID: second.id, personID: man.id, movieID: 435, action: .later, date: at(110)),
    ]
    data.watched = [326, 435]
    data.watchedAt = [326: at(50)]
    data.ratings = [
        MovieRating(movieID: 326, personID: man.id, verdict: .like, date: at(60)),
        MovieRating(movieID: 326, personID: woman.id, verdict: .dislike, date: at(70)),
    ]
    data.movieCache = [326: movie(326), 435: movie(435)]
    return data
}

/// Только синхронизируемая часть: локальные поля пустые.
private func syncedPart(of data: AppData) -> AppData {
    var result = data
    result.meID = nil
    result.movieCache = [:]
    return result
}

private func json(_ data: Data?) -> String { String(decoding: data ?? Data(), as: UTF8.self) }

@Test func fullAppDataRoundTrips() throws {
    let data = try filledData()

    let restored = SyncRecordMapper.apply(SyncRecordMapper.payloads(from: data), to: AppData())

    #expect(restored == syncedPart(of: data))
}

/// Иначе новое поле попадёт в `syncedFields`, но тест выше его не проверит.
@Test func fixtureFillsEverySyncedField() throws {
    let filled = Dictionary(uniqueKeysWithValues: Mirror(reflecting: try filledData()).children
        .map { ($0.label!, String(describing: $0.value)) })
    let empty = Dictionary(uniqueKeysWithValues: Mirror(reflecting: AppData()).children
        .map { ($0.label!, String(describing: $0.value)) })

    for field in SyncRecordMapper.syncedFields {
        #expect(filled[field] != empty[field], "Заполни \(field) в filledData()")
    }
}

@Test func movieCacheAndMeIDNotSynced() throws {
    let data = try filledData()
    let payloads = SyncRecordMapper.payloads(from: data)
    let everything = payloads.map { $0.key + json($0.value) }.joined()

    #expect(!everything.contains("movieCache"))
    #expect(!everything.contains("meID"))
    // Описание фильма есть только в кэше и в списках; без списков его в записях нет.
    var withoutLists = data
    withoutLists.watchlist = []
    #expect(!SyncRecordMapper.payloads(from: withoutLists).values.map { json($0) }.joined().contains("Описание"))

    var local = AppData()
    local.meID = woman.id
    local.movieCache = [1: movie(1)]
    let applied = SyncRecordMapper.apply(payloads, to: local)
    #expect(applied.meID == woman.id)
    #expect(applied.movieCache == [1: movie(1)])
}

/// Падает, когда в `AppData` добавили поле и не решили, синхронизировать ли его.
@Test func everyAppDataFieldIsClassified() {
    let fields = Set(Mirror(reflecting: AppData()).children.compactMap(\.label))

    #expect(fields == SyncRecordMapper.syncedFields.union(SyncRecordMapper.localFields))
    #expect(SyncRecordMapper.syncedFields.isDisjoint(with: SyncRecordMapper.localFields))
    #expect(SyncRecordMapper.localFields == ["meID", "movieCache"])
}

@Test func removedSexEntryDisappearsFromPayloads() throws {
    var data = try filledData()
    #expect(SyncRecordMapper.payloads(from: data)["sex:\(sexID.uuidString)"] != nil)

    data.sexEntries.removeAll { $0.id == sexID }

    let payloads = SyncRecordMapper.payloads(from: data)
    #expect(payloads["sex:\(sexID.uuidString)"] == nil)
    #expect(payloads.keys.filter { $0.hasPrefix("sex:") }.count == 1)
}

@Test func periodDayIDsAreStable() {
    var a = AppData()
    a.periodDays = [DayKey(year: 2026, month: 10, day: 1)]
    var b = AppData()
    b.periodDays = [DayKey(Date(timeIntervalSince1970: 1_791_000_000)), DayKey(year: 2026, month: 10, day: 1)]

    let idsA = Set(SyncRecordMapper.payloads(from: a).keys)
    let idsB = Set(SyncRecordMapper.payloads(from: b).keys)

    #expect(idsA == ["period:2026-10-01"])
    #expect(idsA.isSubset(of: idsB))
    #expect(SyncRecordMapper.payloads(from: a)["period:2026-10-01"] == SyncRecordMapper.payloads(from: b)["period:2026-10-01"])
}

@Test func recordIDsFollowPlan() throws {
    let ids = Set(SyncRecordMapper.payloads(from: try filledData()).keys)
    let m = man.id.uuidString, w = woman.id.uuidString, s = sessionID.uuidString

    let expected: Set<String> = [
        "couple:main", "togetherSince:main", "sex:\(sexID.uuidString)",
        "period:2026-03-14", "period:2026-03-15",
        "herMood:2026-03-14", "herMood:2026-03-15",
        "symptoms:2026-03-14", "symptoms:2026-03-16",
        "watchlist:\(m):326", "watchlist:\(w):326",
        "session:\(s)",
        "swipe:\(s):\(m):326", "swipe:\(s):\(w):326",
        "watched:326", "watched:435",
        "rating:\(m):326", "rating:\(w):326",
    ]
    #expect(expected.isSubset(of: ids))
    // Вторая запись секса, второй подбор и свайп в нём: id со случайными UUID.
    #expect(ids.subtracting(expected).map { $0.prefix { $0 != ":" } }.sorted() == ["session", "sex", "swipe"])
}

/// Движок синхронизации сравнивает байты: одно и то же значение всегда даёт одни и те же байты,
/// в каком бы порядке ни лежали элементы множеств.
@Test func payloadsAreDeterministic() throws {
    var a = AppData()
    a.sexEntries = [SexEntry(id: sexID, day: day, types: [.vaginal, .anal, .blowjob, .cunnilingus],
                             orgasmsMan: 1, orgasmsWoman: 1, createdBy: man.id)]
    a.symptoms = [day: [.custom("Б"), .preset(.nausea), .custom("А"), .preset(.acne)]]
    var b = AppData()
    var types = Set<SexType>(minimumCapacity: 64)
    for type in SexType.allCases.reversed() { types.insert(type) }
    b.sexEntries = [SexEntry(id: sexID, day: day, types: types, orgasmsMan: 1, orgasmsWoman: 1, createdBy: man.id)]
    var symptoms = Set<Symptom>(minimumCapacity: 64)
    for symptom in [Symptom.preset(.acne), .custom("А"), .preset(.nausea), .custom("Б")] { symptoms.insert(symptom) }
    b.symptoms = [day: symptoms]

    let payloadsA = SyncRecordMapper.payloads(from: a)
    #expect(payloadsA == SyncRecordMapper.payloads(from: b))
    #expect(json(payloadsA["sex:\(sexID.uuidString)"]).contains(#""types":["anal","blowjob","cunnilingus","vaginal"]"#))
    let sex = json(payloadsA["sex:\(sexID.uuidString)"])
    #expect(sex.ranges(of: #""types""#).count == 1)
    #expect(sex.firstRange(of: "createdBy")!.lowerBound < sex.firstRange(of: "day")!.lowerBound)
}

/// Дата «Смотрим» едет в записи `watched:<id>`; без даты — `null`.
@Test func watchedAtTravelsInsideWatched() throws {
    var data = AppData()
    data.watched = [1, 2]
    data.watchedAt = [1: at(5)]

    let payloads = SyncRecordMapper.payloads(from: data)

    #expect(Set(payloads.keys) == ["watched:1", "watched:2"])
    #expect(json(payloads["watched:2"]) == "null")
    let restored = SyncRecordMapper.apply(payloads, to: AppData())
    #expect(restored.watched == [1, 2])
    #expect(restored.watchedAt == [1: at(5)])
}

/// Передумал в том же подборе — в записи остаётся последнее решение.
@Test func repeatedSwipeKeepsLatestDecision() {
    var data = AppData()
    data.swipes = [
        Swipe(sessionID: sessionID, personID: man.id, movieID: 1, action: .no, date: at(20)),
        Swipe(sessionID: sessionID, personID: man.id, movieID: 1, action: .yes, date: at(10)),
    ]

    let restored = SyncRecordMapper.apply(SyncRecordMapper.payloads(from: data), to: AppData())

    #expect(restored.swipes.map(\.action) == [.no])
}

@Test func applyReplacesSyncedFields() throws {
    var payloads = SyncRecordMapper.payloads(from: AppData())
    payloads["period:2026-01-01"] = SyncRecordMapper.payloads(
        from: { var d = AppData(); d.periodDays = [DayKey(year: 2026, month: 1, day: 1)]; return d }()
    )["period:2026-01-01"]

    let applied = SyncRecordMapper.apply(payloads, to: try filledData())

    #expect(syncedPart(of: applied) == { var d = AppData(); d.periodDays = [DayKey(year: 2026, month: 1, day: 1)]; return d }())
}

/// Запись из будущей версии приложения или битая запись пропускается, остальные применяются.
@Test func unknownAndBrokenRecordsIgnored() throws {
    let data = try filledData()
    var payloads = SyncRecordMapper.payloads(from: data)
    payloads["future:1"] = Data("{}".utf8)
    payloads["sex:\(UUID().uuidString)"] = Data("не json".utf8)
    payloads["herMood:вчера"] = Data(#""wants""#.utf8)
    payloads["watched:abc"] = Data("null".utf8)

    let restored = SyncRecordMapper.apply(payloads, to: AppData())

    #expect(restored == syncedPart(of: data))
}

@Test func tombstoneRecordRoundTripsThroughJSON() throws {
    let record = SyncRecord(id: "sex:1", updatedAt: at(1), payload: nil)

    let decoded = try JSONDecoder().decode(SyncRecord.self, from: JSONEncoder().encode(record))

    #expect(decoded == record)
    #expect(decoded.payload == nil)
}

/// Собрали из записей и снова разобрали — те же байты, в том числе с долями секунды в датах,
/// иначе движок после каждого получения видел бы «правку» и отправлял её обратно.
@Test func payloadsSurviveApply() throws {
    var data = try filledData()
    let now = Date(timeIntervalSinceReferenceDate: 781_234_567.123_456_7)
    data.watchedAt = [326: now]
    data.ratings.append(MovieRating(movieID: 435, personID: man.id, verdict: .skip, date: now.addingTimeInterval(0.3)))
    let payloads = SyncRecordMapper.payloads(from: data)

    let again = SyncRecordMapper.payloads(from: SyncRecordMapper.apply(payloads, to: AppData()))

    #expect(again == payloads)
}

/// День в id только в одном написании: иначе один день дал бы два id, и записи спорили бы между собой.
@Test func nonCanonicalDayIDsIgnored() {
    let wants = Data(#""wants""#.utf8)
    let payloads = ["herMood:2026-3-14": wants, "herMood:+2026-03-14": wants, "herMood:2026-13-45": wants,
                    "symptoms:2026-03-14x": Data("[]".utf8), "herMood:2026-03-15": wants]

    let restored = SyncRecordMapper.apply(payloads, to: AppData())

    #expect(restored.herMoods == [DayKey(year: 2026, month: 3, day: 15): .wants])
    #expect(restored.symptoms.isEmpty)
}
