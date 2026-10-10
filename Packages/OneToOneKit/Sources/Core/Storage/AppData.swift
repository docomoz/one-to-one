import Foundation

/// Все данные приложения одной структурой. Целиком сохраняется в `Store`.
public struct AppData: Codable, Equatable, Sendable {
    public var couple: Couple?
    /// Кто из пары пользуется этим телефоном.
    public var meID: UUID?
    /// С какого дня пара вместе. Нужен для годовщины; без даты плашки годовщины нет.
    public var togetherSince: DayKey?

    // Трекер
    public var sexEntries: [SexEntry] = []
    public var periodDays: Set<DayKey> = []
    public var herMoods: [DayKey: HerMood] = [:]
    public var symptoms: [DayKey: Set<Symptom>] = [:]

    // Фильмы
    public var watchlist: [WatchlistItem] = []
    public var sessions: [PickSession] = []
    public var swipes: [Swipe] = []
    /// Id фильмов Кинопоиска, которые уже посмотрели.
    public var watched: Set<Int> = []
    public var movieCache: [Int: Movie] = [:]

    public init() {}

    /// Пара создана и понятно, кто из неё «я». Пока нет — показываем знакомство.
    public var isPaired: Bool {
        guard let couple, let meID else { return false }
        return meID == couple.man.id || meID == couple.woman.id
    }

    /// Этим телефоном пользуется она: ей виден полный календарь цикла.
    public var meIsWoman: Bool {
        meID != nil && meID == couple?.woman.id
    }

    /// Поля, которых нет в файле, берём по умолчанию. Иначе после добавления нового поля
    /// старый файл не прочитается, и данные пользователя пропадут. Новое поле добавляй и сюда.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        couple = try container.decodeIfPresent(Couple.self, forKey: .couple)
        meID = try container.decodeIfPresent(UUID.self, forKey: .meID)
        togetherSince = try container.decodeIfPresent(DayKey.self, forKey: .togetherSince)
        sexEntries = try container.decodeIfPresent([SexEntry].self, forKey: .sexEntries) ?? []
        periodDays = try container.decodeIfPresent(Set<DayKey>.self, forKey: .periodDays) ?? []
        herMoods = try container.decodeIfPresent([DayKey: HerMood].self, forKey: .herMoods) ?? [:]
        symptoms = try container.decodeIfPresent([DayKey: Set<Symptom>].self, forKey: .symptoms) ?? [:]
        watchlist = try container.decodeIfPresent([WatchlistItem].self, forKey: .watchlist) ?? []
        sessions = try container.decodeIfPresent([PickSession].self, forKey: .sessions) ?? []
        swipes = try container.decodeIfPresent([Swipe].self, forKey: .swipes) ?? []
        watched = try container.decodeIfPresent(Set<Int>.self, forKey: .watched) ?? []
        movieCache = try container.decodeIfPresent([Int: Movie].self, forKey: .movieCache) ?? [:]
    }
}
