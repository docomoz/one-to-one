import Core

/// Достаёт из каталога рекомендации для колоды.
public enum DeckLoader {
    /// «Похожие» на каждый фильм из `seeds` (по порядку), потом подборка по жанрам настроения.
    /// Упавший запрос (нет сети, кончился лимит) просто ничего не добавляет: колода
    /// всё равно соберётся из списков. Дубли и фильтр по настроению убирает `DeckBuilder`.
    /// Заодно, параллельно, раз в день пополняет каталог на телефоне.
    public static func recommendations(seeds: [Int], mood: Mood, catalog: some MovieCatalog) async -> [Movie] {
        async let refill: Void = catalog.refillIfNeeded()
        let movies = await withTaskGroup(of: (Int, [Movie]).self) { group in
            for (index, seed) in seeds.enumerated() {
                group.addTask { (index, (try? await catalog.recommendations(for: seed)) ?? []) }
            }
            group.addTask { (seeds.count, (try? await catalog.discover(genres: mood.genres)) ?? []) }

            var parts: [Int: [Movie]] = [:]
            for await (index, movies) in group { parts[index] = movies }
            return parts.keys.sorted().flatMap { parts[$0]! }
        }
        await refill
        return movies
    }

    /// Id «похожих» на каждый фильм из `ids`: их убираем из колоды, если фильму поставили 👎.
    /// `nil` — не ответил ни один запрос (нет сети, лимит): тогда фильтр стоит попросить снова.
    /// Пустой набор — Кинопоиск ответил, но «похожих» нет; его можно запомнить на подбор.
    public static func similar(to ids: [Int], catalog: some MovieCatalog) async -> Set<Int>? {
        guard !ids.isEmpty else { return [] }
        return await withTaskGroup(of: [Movie]?.self) { group in
            for id in ids {
                group.addTask { try? await catalog.recommendations(for: id) }
            }
            var result: Set<Int>?
            for await movies in group {
                guard let movies else { continue }
                result = (result ?? []).union(movies.map(\.id))
            }
            return result
        }
    }
}
