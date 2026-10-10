import Foundation
import Testing
@testable import Core

/// AppData, где заполнено каждое поле: так проверяем, что сохраняется всё, а не только пара.
private func filledData() throws -> AppData {
    let man = Person(name: "Максим", sex: .male)
    let woman = Person(name: "Даша", sex: .female)
    let day = DayKey(year: 2026, month: 3, day: 14)
    let date = Date(timeIntervalSince1970: 1_773_500_000)
    let movie = Movie(id: 326, title: "Побег из Шоушенка", year: 1994, genres: ["драма"],
                      overview: "Банкир попадает в тюрьму.", posterURL: URL(string: "https://example.com/p.jpg"),
                      imdbID: "tt0111161", ratings: Ratings(imdb: 9.3, kinopoisk: 9.1))
    let session = PickSession(id: UUID(), mood: .cry, startedBy: woman.id, startedAt: date)

    var data = AppData()
    data.couple = try Couple.make(man, woman)
    data.meID = man.id
    data.sexEntries = [SexEntry(id: UUID(), day: day, types: [.vaginal, .cunnilingus],
                                orgasmsMan: 1, orgasmsWoman: 2, createdBy: man.id)]
    data.periodDays = [day, day.adding(days: 1)]
    data.herMoods = [day: .wants]
    data.symptoms = [day: [.preset(.headache), .custom("Мигрень")]]
    data.watchlist = [WatchlistItem(movie: movie, ownerID: man.id, addedAt: date, fromLater: false)]
    data.sessions = [session]
    data.swipes = [Swipe(sessionID: session.id, personID: man.id, movieID: movie.id, action: .yes, date: date)]
    data.watched = [movie.id]
    data.movieCache = [movie.id: movie]
    return data
}

/// Новая пустая временная папка, которой ещё нет на диске.
private func tempDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "OneToOneTests-\(UUID().uuidString)")
}

@Test func localStoreRoundTrip() throws {
    let directory = tempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = try filledData()

    try LocalStore(directory: directory).save(data)
    let loaded = try LocalStore(directory: directory).load()

    #expect(loaded == data)
}

@Test func localStoreEmptyWhenNoFile() throws {
    let loaded = try LocalStore(directory: tempDirectory()).load()

    #expect(loaded == AppData())
}

@Test func localStoreOverwritesPreviousSave() throws {
    let directory = tempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = LocalStore(directory: directory)

    try store.save(try filledData())
    try store.save(AppData())

    #expect(try store.load() == AppData())
}

@Test func inMemoryStoreRoundTrip() throws {
    let store = InMemoryStore()
    let data = try filledData()

    #expect(try store.load() == AppData())
    try store.save(data)
    #expect(try store.load() == data)
}

@Test func emptyAppDataHasNothing() {
    let data = AppData()

    #expect(data.couple == nil)
    #expect(data.meID == nil)
    #expect(data.sexEntries.isEmpty)
    #expect(data.periodDays.isEmpty)
    #expect(data.herMoods.isEmpty)
    #expect(data.watchlist.isEmpty)
    #expect(data.sessions.isEmpty)
    #expect(data.swipes.isEmpty)
    #expect(data.watched.isEmpty)
    #expect(data.movieCache.isEmpty)
}

@Test func appDataDecodesFileWithMissingFields() throws {
    // Старый файл, сохранённый до того, как в AppData появились новые поля.
    let old = Data(#"{"watched": [326]}"#.utf8)

    let data = try JSONDecoder().decode(AppData.self, from: old)

    var expected = AppData()
    expected.watched = [326]
    #expect(data == expected)
}

@Test func appDataIsPairedOnlyWithOwnMeID() throws {
    let man = Person(name: "Максим", sex: .male)
    let woman = Person(name: "Даша", sex: .female)
    var data = AppData()
    #expect(!data.isPaired)
    data.couple = try Couple.make(man, woman)
    #expect(!data.isPaired)
    data.meID = UUID()
    #expect(!data.isPaired)
    data.meID = woman.id
    #expect(data.isPaired)
}

@Test func localStoreKeepsUnreadableFileAside() throws {
    let directory = tempDirectory()
    let broken = Data("не JSON".utf8)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try broken.write(to: directory.appending(path: "AppData.json"))
    let store = LocalStore(directory: directory)

    #expect(throws: (any Error).self) { try store.load() }
    try store.save(AppData())

    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
    let backups = names.filter { $0.hasPrefix("AppData-unreadable-") }
    #expect(backups.count == 1)
    let backup = try #require(backups.first)
    #expect(try Data(contentsOf: directory.appending(path: backup)) == broken)
}
