import Core
import Foundation

/// Id записей синхронизации: "<вид>:<ключ>". На сервер уходит только непрозрачным (`RecordIDHasher`).
enum SyncRecordID {
    static let couple = "couple:main"
    static let togetherSince = "togetherSince:main"

    static func sex(_ entry: SexEntry) -> String { "sex:\(entry.id.uuidString)" }
    static func period(_ day: DayKey) -> String { "period:\(string(day))" }
    static func herMood(_ day: DayKey) -> String { "herMood:\(string(day))" }
    static func symptoms(_ day: DayKey) -> String { "symptoms:\(string(day))" }
    static func watchlist(_ item: WatchlistItem) -> String { "watchlist:\(item.ownerID.uuidString):\(item.movie.id)" }
    static func session(_ session: PickSession) -> String { "session:\(session.id.uuidString)" }
    static func swipe(_ swipe: Swipe) -> String {
        "swipe:\(swipe.sessionID.uuidString):\(swipe.personID.uuidString):\(swipe.movieID)"
    }
    static func watched(_ movieID: Int) -> String { "watched:\(movieID)" }
    static func rating(_ rating: MovieRating) -> String { "rating:\(rating.personID.uuidString):\(rating.movieID)" }

    /// "herMood:2026-10-11" → ("herMood", "2026-10-11"). Ключ может сам содержать двоеточия.
    static func split(_ id: String) -> (kind: Substring, key: Substring)? {
        guard let colon = id.firstIndex(of: ":") else { return nil }
        return (id[..<colon], id[id.index(after: colon)...])
    }

    /// День в id: "2026-03-14", с нулями, чтобы один день всегда давал один id.
    static func string(_ day: DayKey) -> String {
        String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
    }

    static func day(_ string: Substring) -> DayKey? {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false).compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return DayKey(year: parts[0], month: parts[1], day: parts[2])
    }
}
