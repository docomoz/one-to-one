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

    /// Поля, которых нет в файле, берём по умолчанию. Иначе после добавления нового поля
    /// старый файл не прочитается, и данные пользователя пропадут. Новое поле добавляй и сюда.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        couple = try container.decodeIfPresent(Couple.self, forKey: .couple)
        meID = try container.decodeIfPresent(UUID.self, forKey: .meID)
        sexEntries = try container.decodeIfPresent([SexEntry].self, forKey: .sexEntries) ?? []
        periodDays = try container.decodeIfPresent(Set<DayKey>.self, forKey: .periodDays) ?? []
        herMoods = try container.decodeIfPresent([DayKey: HerMood].self, forKey: .herMoods) ?? [:]
        watchlist = try container.decodeIfPresent([WatchlistItem].self, forKey: .watchlist) ?? []
        sessions = try container.decodeIfPresent([PickSession].self, forKey: .sessions) ?? []
        swipes = try container.decodeIfPresent([Swipe].self, forKey: .swipes) ?? []
        watched = try container.decodeIfPresent(Set<Int>.self, forKey: .watched) ?? []
        movieCache = try container.decodeIfPresent([Int: Movie].self, forKey: .movieCache) ?? [:]
    }
}
