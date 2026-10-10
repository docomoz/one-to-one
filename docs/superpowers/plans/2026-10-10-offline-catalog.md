# Офлайн-каталог фильмов (#55): план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** колода собирается без сети и при лимите Кинопоиска: из базы `movies.json` и кэша на телефоне, который сам пополняется.

**Architecture:** всё новое — в `MovieAPI`. `CachingCatalog` (actor) оборачивает `KinopoiskCatalog`: кладёт ответы в кэш-файл, раз в день догружает топ и новинки и отдаёт локальные фильмы по жанрам. `MovieCatalog` получает два метода с пустой реализацией по умолчанию, поэтому остальной код и тестовые каталоги не меняются. `AppModel.deck` добавляет локальные фильмы после сетевых рекомендаций.

**Tech Stack:** Swift 6, Swift Testing, SwiftPM-ресурсы (`Bundle.module`), XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-10-offline-catalog-design.md`

## Global Constraints
- Новых внешних зависимостей нет.
- Запросов к Кинопоиску на подбор не больше, чем сейчас (6), догрузка — не больше 2 в календарный день.
- Кэш — отдельный файл `MovieCatalogCache.json` в Application Support, не `AppData`. Предел 2000 фильмов, вытесняются самые давние по `addedAt`.
- Локальные фильмы по жанрам: пересечение с `mood.genres`, по убыванию `ratings.kinopoisk` (без рейтинга — в конце), не больше 40.
- Даты дней — через `DayKey` (Core).
- `movies.json` в этом PR — пустой массив `[]`.

## Review Focus
1. **Испорченный или отсутствующий файл кэша** — старт с пустым кэшем, без падения. Тест `unreadableCacheStartsEmpty` (задача 2).
2. **Пустой `movies.json`** (так в этом PR) — локальный каталог работает только на кэше. Тест `emptyBaseUsesCacheOnly` (задача 2).
3. **Догрузка при 401/403/без сети** — дата не сдвигается, страница не растёт. Тест `refillFailureKeepsDate` (задача 3).
4. **Офлайн с первого открытия, потом сеть** — сетевые рекомендации не залипают пустыми: локальные фильмы не попадают в `recommendationsByPick`. Тест `localMoviesNotCachedAsRecommendations` (задача 4).
5. **Страница топа кончилась** (пустой ответ) — `nextTopPage` возвращается к 1. Тест `emptyTopPageWrapsToFirst` (задача 3).

---

### Задача 1. Запросы «топ» и «новинки года»

**Files:**
- Modify: `Packages/OneToOneKit/Sources/MovieAPI/KinopoiskCatalog.swift`
- Create: `Packages/OneToOneKit/Sources/MovieAPI/MovieFeed.swift`
- Test: `Packages/OneToOneKit/Tests/MovieAPITests/KinopoiskCatalogTests.swift` (фикстура `discover.json` подходит как ответ)

**Interfaces:**
- Produces: `public protocol MovieFeed: Sendable { func top(page: Int) async throws -> [Movie]; func newReleases(year: Int) async throws -> [Movie] }`; `KinopoiskCatalog: MovieFeed`. Оба — `GET movie` с `type`×3, `isSeries=false`, `sortField=votes.kp`, `sortType=-1`, `limit=50`, `selectFields` как в `discover`; `top` добавляет `page=<page>`, `newReleases` — `year=<year>`.

- [ ] **Step 1: тесты** `topSendsPageAndSort` (в запросе `page=4`, `limit=50`, `sortField=votes.kp`, `isSeries=false`, три `type`; фильмы распарсились), `newReleasesSendsYear` (`year=2026`, `sortField=votes.kp`).
- [ ] **Step 2:** `swift test --filter KinopoiskCatalogTests` — не компилируется.
- [ ] **Step 3:** реализовать; общий набор параметров `discover`/`top`/`newReleases` вынести в один приватный помощник.
- [ ] **Step 4:** `swift test` — зелёное.
- [ ] **Step 5:** коммит «Добавить запросы топа и новинок Кинопоиска».

### Задача 2. База и кэш каталога

**Files:**
- Create: `Sources/MovieAPI/Resources/movies.json` (`[]`), `Sources/MovieAPI/BaseCatalog.swift`, `Sources/MovieAPI/CatalogCache.swift`, `Sources/MovieAPI/CatalogCacheFile.swift`
- Modify: `Packages/OneToOneKit/Package.swift` (`MovieAPI` — `resources: [.copy("Resources/movies.json")]`)
- Test: `Tests/MovieAPITests/CatalogCacheTests.swift`

**Interfaces:**
- Produces:
  - `public enum BaseCatalog { public static func load(from url: URL? = Bundle.module.url(forResource: "movies", withExtension: "json")) -> [Movie] }` — ошибка чтения → `[]`.
  - `public struct CatalogCache: Codable, Equatable, Sendable { var entries: [Int: Entry]; var lastRefill: DayKey?; var nextTopPage: Int = 4 }`, `struct Entry: Codable, Equatable, Sendable { var movie: Movie; var addedAt: Date }`.
  - `mutating func add(_ movies: [Movie], at date: Date, limit: Int = 2000)` — новая запись или замена фильма (старый `addedAt` сохраняется); сверх `limit` удаляются самые давние.
  - `func movies(genres: [String], base: [Movie], limit: Int = 40) -> [Movie]` — база + кэш (кэш перекрывает базу по id), пересечение жанров, сортировка по `ratings.kinopoisk` убыв., `nil` в конце, при равенстве по id.
  - `public final class CatalogCacheFile: Sendable { init(url: URL); func load() -> CatalogCache; func save(_ cache: CatalogCache) }`, `static var defaultURL: URL` (Application Support / `MovieCatalogCache.json`). Ошибка чтения → `CatalogCache()`, ошибка записи — молча (кэш необязателен).

- [ ] **Step 1: тесты**
  - `baseLoadsBundledFile`: `BaseCatalog.load()` возвращает массив (в этом PR пустой) без ошибки; `baseLoadsMovies`: из временного файла с двумя `Movie` → 2 фильма; `baseMissingFileIsEmpty`.
  - `addReplacesWithoutDuplicates`: добавить фильм 1 дважды с разным рейтингом → одна запись, рейтинг новый, `addedAt` первый.
  - `addEvictsOldest`: `limit: 2`, три фильма в разное время → остались два свежих.
  - `moviesFilterByGenreAndSortByRating`: жанры `["комедия"]`, фильмы с рейтингами 7, nil, 8 и драма → `[8, 7, nil]` по id, драмы нет.
  - `moviesRespectLimit`, `cacheOverridesBase` (одинаковый id → берётся из кэша).
  - `emptyBaseUsesCacheOnly`.
  - `cacheFileRoundTrip`, `unreadableCacheStartsEmpty` (мусор в файле → `CatalogCache()`).
- [ ] **Step 2:** `swift test --filter CatalogCacheTests` — не компилируется.
- [ ] **Step 3:** реализовать.
- [ ] **Step 4:** `swift test` — зелёное.
- [ ] **Step 5:** коммит «Добавить базу и кэш каталога фильмов».

### Задача 3. Каталог с кэшем и догрузкой

**Files:**
- Modify: `Sources/MovieAPI/MovieCatalog.swift`
- Create: `Sources/MovieAPI/CachingCatalog.swift`
- Test: `Tests/MovieAPITests/CachingCatalogTests.swift`

**Interfaces:**
- Consumes: задачи 1–2.
- Produces:
  - В `MovieCatalog`: `func localMovies(genres: [String]) async -> [Movie]` и `func refillIfNeeded() async`; в `extension MovieCatalog` по умолчанию `[]` и ничего.
  - `public actor CachingCatalog: MovieCatalog { public init(remote: some MovieCatalog & MovieFeed, file: CatalogCacheFile, base: [Movie], now: @escaping @Sendable () -> Date = { .now }) }`.
  - `search` / `recommendations` / `discover`: ответ `remote` → `cache.add` → `file.save` → вернуть; ошибка пробрасывается, кэш не трогается.
  - `localMovies(genres:)` = `cache.movies(genres:base:)`.
  - `refillIfNeeded()`: если `cache.lastRefill == DayKey(now())` — ничего. Иначе `top(page: nextTopPage)` и `newReleases(year: <год now()>)` параллельно. Успешные ответы — в кэш. `top` успешен: непустой → `nextTopPage += 1`, пустой → `nextTopPage = 1`. Оба успешны → `lastRefill = сегодня`. Сохранить файл.

- [ ] **Step 1: тесты** (фейковый `remote` считает вызовы; файл — во временной папке; `now` подставляется)
  - `searchResultsGoToCache`, `recommendationsAndDiscoverGoToCache` (потом `localMovies` их возвращает).
  - `failedRequestThrowsAndKeepsCache`.
  - `refillOncePerDay`: два вызова в один день → `top` спрошен 1 раз, `newReleases` 1 раз; на следующий день — ещё по разу, страница 4 → 5 → 6.
  - `refillFailureKeepsDate` — `remote` бросает 401 → `lastRefill == nil`, `nextTopPage == 4`; на следующем вызове спрашивает снова.
  - `emptyTopPageWrapsToFirst`.
  - `cacheSurvivesRestart`: новый `CachingCatalog` с тем же файлом видит прежние фильмы.
  - `defaultLocalMoviesEmpty`: у обычного каталога (фейк из `DeckLoaderTests`) `localMovies` → `[]`.
- [ ] **Step 2:** `swift test --filter CachingCatalogTests` — не компилируется.
- [ ] **Step 3:** реализовать.
- [ ] **Step 4:** `swift test` — зелёное.
- [ ] **Step 5:** коммит «Кэшировать ответы Кинопоиска и догружать каталог раз в день».

### Задача 4. Колода с локальными фильмами в приложении

**Files:**
- Modify: `App/OneToOne/AppModel+Movies.swift` (`deck(for:catalog:)`), `App/OneToOne/Features/Movies/MovieCatalog+Environment.swift`, `Sources/MovieAPI/DeckLoader.swift`
- Test: `App/OneToOneTests/AppModelPickTests.swift`, `Tests/MovieAPITests/DeckLoaderTests.swift`

**Interfaces:**
- Consumes: задача 3.
- Produces:
  - `DeckLoader.recommendations` дополнительно ждёт `catalog.refillIfNeeded()` в той же группе задач (параллельно, результат не используется).
  - `AppModel.deck`: `recommendations` (сетевые, кэш на подбор как сейчас) + `await catalog.localMovies(genres: session.mood.genres)` в конец → `data.deck`. Локальные в `recommendationsByPick` не кладутся.
  - Окружение: один общий каталог `enum AppCatalog { static let shared: any MovieCatalog }` = `CachingCatalog(remote: KinopoiskCatalog(apiKey: …), file: CatalogCacheFile(url: CatalogCacheFile.defaultURL), base: BaseCatalog.load())`; `@Entry var movieCatalog: any MovieCatalog = AppCatalog.shared`.

- [ ] **Step 1: тесты**
  - `DeckLoaderTests.refillRequestedWithRecommendations` — фейк считает `refillIfNeeded`, вызван 1 раз.
  - `AppModelPickTests.deckAddsLocalMoviesOffline`: каталог без сети, `localMovies` отдаёт комедию 7 → колода `[7]`.
  - `deckLocalAfterNetwork`: сеть отдаёт 2, локально 7 → `[2, 7]`.
  - `localMoviesNotCachedAsRecommendations`: офлайн → колода из локальных; потом сеть → в колоде появились сетевые.
- [ ] **Step 2:** тесты пакета и приложения — не компилируются / красные.
- [ ] **Step 3:** реализовать.
- [ ] **Step 4:** `swift test` и `xcodebuild test … iPhone 17` — зелёное.
- [ ] **Step 5:** руками в симуляторе в режиме без сети (ключа нет — Кинопоиск отвечает 401): колода собирается, без минутного ожидания.
- [ ] **Step 6:** коммит «Добавлять в колоду фильмы из каталога на телефоне».

### Задача 5. Скрипт обновления и документы

**Files:**
- Create: `Packages/OneToOneKit/Sources/UpdateMovies/main.swift`
- Modify: `Package.swift` (`.executableTarget(name: "UpdateMovies", dependencies: ["MovieAPI"])`), `CLAUDE.md` (раздел «Стек»), `docs/decisions.md`, `docs/plan.md` («Карта модулей»: `MovieFeed`, `CachingCatalog`, `CatalogCache`, `BaseCatalog`)

**Interfaces:**
- Consumes: `KinopoiskCatalog.top(page:)`.
- Produces: `cd Packages/OneToOneKit && swift run UpdateMovies` — ключ из `KINOPOISK_API_KEY` или строки `KINOPOISK_API_KEY = …` в `../../Config/Secrets.xcconfig` (путь от `#filePath`); страницы 1–3; без дублей; сортировка по id; `JSONEncoder` с `.prettyPrinted, .sortedKeys`; запись в `Sources/MovieAPI/Resources/movies.json`; печать «Записано N фильмов». Без ключа — понятная ошибка и код выхода 1.

- [ ] **Step 1:** реализовать скрипт (проверяется сборкой и запуском без ключа: сообщение и код 1; логика запросов уже покрыта тестами задачи 1).
- [ ] **Step 2:** `swift build` и `swift run UpdateMovies` без ключа — ожидаемое сообщение.
- [ ] **Step 3:** документы: строка в `decisions.md`; в `CLAUDE.md` «Обновить базовый каталог фильмов: `cd Packages/OneToOneKit && swift run UpdateMovies` (нужен ключ в `Config/Secrets.xcconfig`)»; «Карта модулей».
- [ ] **Step 4:** `swift test`, `xcodegen generate && xcodebuild test …` — зелёное; `/code-review`; PR `Closes #55` с автослиянием.
