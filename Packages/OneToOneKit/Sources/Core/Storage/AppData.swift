import Foundation

/// Все данные приложения одной структурой. Целиком сохраняется в `Store`.
public struct AppData: Codable, Equatable, Sendable {
    public var couple: Couple?
    /// Кто из пары пользуется этим телефоном.
    public var meID: UUID?

    // Трекер
    public var sexEntries: [SexEntry] = []
    public var periodDays: Set<DayKey> = []
    public var herMoods: [DayKey: HerMood] = [:]

    // Фильмы
    public var watchlist: [WatchlistItem] = []
    public var sessions: [PickSession] = []
    public var swipes: [Swipe] = []
    /// Id фильмов Кинопоиска, которые уже посмотрели.
    public var watched: Set<Int> = []
    public var movieCache: [Int: Movie] = [:]

    public init() {}
}
