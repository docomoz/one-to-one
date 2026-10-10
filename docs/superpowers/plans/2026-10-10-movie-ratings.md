# Оценка просмотренных фильмов (#56): план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** на следующий день после «Смотрим» под карточкой вечера плашка «Как вам «…»?» с 👍 / 👎 / ✕. 👍 делает фильм затравкой «похожих», 👎 убирает его «похожие» из рекомендаций.

**Architecture:** данные и правила — в `Core/Movies` (`MovieRating`, дата «Смотрим», `AppData+Rating`), колода получает набор исключённых id. `DeckLoader.similar` в `MovieAPI` достаёт «похожие» на фильмы с 👎. `AppModel` кэширует исключения на подбор, как `recommendationsByPick`. Новая вью `RateMovieBanner` встраивается в `MoviesView` под `PickCard`.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-10-movie-ratings-design.md`

## Global Constraints
- Новых зависимостей нет.
- Запросов к Кинопоиску на подбор не больше 9: 5 затравок + 1 `discover` (как сейчас) + до 3 фильмов с 👎.
- Затравок по-прежнему не больше 5. Фильтр 👎 — по 3 последним фильмам с 👎 от любого из пары.
- Списки «хочу посмотреть» идут первыми и фильтром 👎 не режутся. «Похожие» на 👍 встают раньше других рекомендаций, но после списков.
- Новые поля `AppData` читаются из старого файла по умолчанию пустыми (`decodeIfPresent ... ?? [:]` / `?? []`).
- Даты дней — через `DayKey` (Core). Core не зовёт `.now` сам: время приходит параметром.
- Тексты: «Как вам «{title}»?»; подписи кнопок для VoiceOver: «Понравился», «Не понравился», «Не оценивать».
- Комментарии и сообщения коммитов на русском.

## Review Focus
1. **Фильм отметили «Смотрим» до этой фичи** (в `watched` есть, в `watchedAt` нет) — плашки нет, ничего не падает. Тест `noBannerForWatchedWithoutDate` (задача 1).
2. **Фильма нет в `movieCache`** (отметили, кэш потерян) — плашки нет. Тест `noBannerWhenMovieNotCached` (задача 1).
3. **«Смотрим» нажали повторно или позже на втором телефоне** — дата остаётся самой ранней, плашка не «переезжает» на завтра. Тест `markWatchedKeepsEarliestDate` (задача 1).
4. **Партнёр ответил, я нет** — у меня плашка остаётся. Тест `partnerRatingDoesNotHideMine` (задача 1).
5. **Есть 👎, но нет сети** — колода собирается, пустой фильтр не запоминается, при сети спросим снова. Тест `dislikeFilterRetriesAfterNoNetwork` (задача 3).

---

### Задача 1. Оценка и дата «Смотрим» в данных

**Files:**
- Create: `Packages/OneToOneKit/Sources/Core/Movies/MovieRating.swift`
- Create: `Packages/OneToOneKit/Sources/Core/Movies/AppData+Rating.swift`
- Modify: `Packages/OneToOneKit/Sources/Core/Storage/AppData.swift`: поля и `init(from:)`
- Modify: `Packages/OneToOneKit/Sources/Core/Movies/AppData+Pick.swift`: `markWatched`
- Modify: вызовы `markWatched(movieID:)` в `Tests/CoreTests/Movies/{PickTests,CurrentPickTests}.swift` — добавить `at:`
- Test: `Packages/OneToOneKit/Tests/CoreTests/Movies/RatingTests.swift`

**Interfaces:**
- Produces:
  - `public enum MovieVerdict: String, Codable, Sendable { case like, dislike, skip }` (`skip` — нажали ✕)
  - `public struct MovieRating: Codable, Equatable, Sendable { public let movieID: Int; public let personID: UUID; public let verdict: MovieVerdict; public let date: Date }` + public init
  - `AppData.watchedAt: [Int: Date] = [:]`, `AppData.ratings: [MovieRating] = []`
  - `mutating func markWatched(movieID: Int, at date: Date)` — кладёт в `watched`; в `watchedAt` пишет дату, только если её нет или новая раньше.
  - `mutating func rate(movieID: Int, _ verdict: MovieVerdict, by personID: UUID, at date: Date)` — заменяет прежнюю оценку этого человека этому фильму, иначе добавляет.
  - `func movieToRate(me personID: UUID, now: Date, calendar: Calendar = .current) -> Movie?`

`movieToRate`: берёт фильм с самой поздней датой в `watchedAt`; `nil`, если `DayKey(watchDate, calendar) >= DayKey(now, calendar)`, если у `personID` уже есть оценка этого фильма, если в `sessions` есть подбор с `startedAt > watchDate`, или фильма нет в `movieCache`.

- [ ] **Step 1: тесты** в `RatingTests.swift` (помощники как в `PickTests.swift`: `man`, `woman`, `movie(_:)`, `pairedData()`, `at(hours:)`; календарь в тестах — григорианский с `TimeZone(identifier: "UTC")`, чтобы `at(hours:)` попадал в предсказуемые дни):
  - `noBannerOnWatchDay`: смотрели в `at(hours: 20)`, `now = at(hours: 23)` → `nil`.
  - `bannerNextDay`: тот же фильм, `now = at(hours: 30)` → фильм.
  - `onlyLastWatchedAsked`: фильмы 1 (час 20) и 2 (час 21), `now = at(hours: 30)` → фильм 2.
  - `anyVerdictHidesBanner`: для каждого из `.like`, `.dislike`, `.skip` после `rate(... by: man.id ...)` → `nil` для `man`.
  - `partnerRatingDoesNotHideMine`: `woman` поставила `.like` → для `man` фильм по-прежнему есть.
  - `newPickHidesBanner`: после «Смотрим» `startPick(... at: at(hours: 25))` → `nil`.
  - `noBannerForWatchedWithoutDate`: `data.watched = [1]`, `movieCache[1]` есть, `watchedAt` пуст → `nil`.
  - `noBannerWhenMovieNotCached`: `markWatched(movieID: 99, at:)`, фильма 99 в кэше нет → `nil`.
  - `markWatchedKeepsEarliestDate`: `markWatched(1, at: hours 20)`, потом `(1, at: hours 30)` → `watchedAt[1] == at(hours: 20)`; и обратный порядок тоже даёт `at(hours: 20)`.
  - `rateReplacesMyPreviousVerdict`: `.like`, потом `.dislike` от `man` → в `ratings` одна запись `.dislike`; оценка `woman` не тронута.
  - `oldDataWithoutRatingsDecodes`: `JSONEncoder` от `AppData()` → удалить ключи `watchedAt` и `ratings` из словаря (`JSONSerialization`) → `JSONDecoder` даёт пустые поля без ошибки.

- [ ] **Step 2:** `cd Packages/OneToOneKit && swift test --filter RatingTests` — FAIL (нет типов).
- [ ] **Step 3:** реализовать `MovieRating.swift`, поля и декодирование в `AppData`, `markWatched(movieID:at:)`, `AppData+Rating.swift` (`rate`, `movieToRate`). Поправить старые вызовы `markWatched` в тестах Core, передавая `at(hours: …)` / `.now` по смыслу теста.
- [ ] **Step 4:** `swift test` — всё зелёное (приложение пока не собирается из-за `markWatched`, это чинит задача 3).
- [ ] **Step 5: коммит** «Добавить оценку фильмов и дату просмотра в данные».

### Задача 2. 👍 в затравках, 👎 в колоде

**Files:**
- Modify: `Packages/OneToOneKit/Sources/Core/Movies/AppData+Pick.swift` (`recommendationSeeds`, `deck`)
- Modify: `Packages/OneToOneKit/Sources/Core/Movies/AppData+Rating.swift` (`dislikedMovies`)
- Modify: `Packages/OneToOneKit/Sources/Core/Movies/DeckBuilder.swift`
- Test: `Tests/CoreTests/Movies/RatingTests.swift`, `Tests/CoreTests/Movies/DeckBuilderTests.swift`

**Interfaces:**
- Consumes: `MovieRating`, `MovieVerdict`, `AppData.ratings` из задачи 1.
- Produces:
  - `func dislikedMovies(limit: Int = 3) -> [Int]` — фильмы с `.dislike` от любого, по дате оценки, свежие первыми, без повторов.
  - `recommendationSeeds(limit: Int = 5) -> [Int]` — новое правило ниже.
  - `DeckBuilder.build(lists:recommendations:mood:watched:swipedByMe:excluded: Set<Int> = [], limit: Int = 40)` — `excluded` убирает фильмы только из `recommendations`, списки не трогает.
  - `AppData.deck(for:recommendations:me:excluded: Set<Int> = [])` — передаёт `excluded` в `DeckBuilder`.

Правило затравок:
```
понравившиеся = фильмы, у которых есть .like и нет ни одного .dislike
оба = понравившиеся, где .like поставили ≥ 2 разных человека; порядок — по последней дате .like, свежие первыми
остальные = ♥-свайпы (как сейчас) + списки (как сейчас) + понравившиеся не из «оба» (дата — последний .like), по дате, свежие первыми
результат = оба + остальные, без повторов, без просмотренных — кроме понравившихся, первые `limit`
```

- [ ] **Step 1: тесты.**
  - `RatingTests`: `likedWatchedMovieBecomesSeed` (фильм просмотрен, у `man` `.like` → он в `recommendationSeeds()`); `likedByBothGoesFirst` (свежий ♥-свайп на 2 и фильм 1 с `.like` от обоих, но раньше по времени → `[1, 2]`); `mixedVerdictIsNotSeed` (`.like` от `man`, `.dislike` от `woman` → не в затравках, но в `dislikedMovies()`); `skipDoesNothing` (`.skip` → ни в затравках, ни в `dislikedMovies()`); `dislikedMoviesLastThree` (4 фильма с `.dislike` в часы 1…4 → `[4, 3, 2]`); `seedsStillLimitFive` (7 источников → 5).
  - `DeckBuilderTests`: `excludedRemovesRecommendationsNotLists` (`lists: [1]`, `recommendations: [10, 11]`, `excluded: [1, 10]` → `[1, 11]`); `excludedAlsoDropsLocalTail` (рекомендации `[10, 20]`, где 20 — «с телефона», `excluded: [20]` → `[10]`).
- [ ] **Step 2:** `swift test` — новые тесты FAIL.
- [ ] **Step 3:** реализовать `dislikedMovies`, новое `recommendationSeeds`, параметр `excluded` в `DeckBuilder.build` и `AppData.deck`. Старые тесты `recommendationSeeds…` должны остаться зелёными без правок.
- [ ] **Step 4:** `swift test` — всё зелёное.
- [ ] **Step 5: коммит** «Учитывать оценки фильмов в затравках и колоде».

### Задача 3. «Похожие» на 👎 и действия в AppModel

**Files:**
- Modify: `Packages/OneToOneKit/Sources/MovieAPI/DeckLoader.swift`
- Modify: `App/OneToOne/AppModel.swift` (поле `excludedByPick`)
- Modify: `App/OneToOne/AppModel+Movies.swift`
- Test: `Packages/OneToOneKit/Tests/MovieAPITests/DeckLoaderTests.swift`, `App/OneToOneTests/AppModelRatingTests.swift` (новый)

**Interfaces:**
- Consumes: `dislikedMovies()`, `AppData.deck(...excluded:)`, `rate`, `movieToRate`, `markWatched(movieID:at:)` из задач 1–2.
- Produces:
  - `public static func similar(to ids: [Int], catalog: some MovieCatalog) async -> Set<Int>` в `DeckLoader` — id «похожих» на каждый из `ids`, запросы параллельно, упавший ничего не добавляет. Пустой `ids` — ни одного запроса.
  - `AppModel`: `@ObservationIgnored var excludedByPick: [UUID: Set<Int>] = [:]`; `func markWatched(movieID: Int)` (передаёт `.now`); `func rate(movieID: Int, _ verdict: MovieVerdict)` (без «я» ничего не делает); `var movieToRate: Movie?` (`data.movieToRate(me:now: .now)`, без «я» — `nil`).
  - `AppModel.deck(for:catalog:)`: исключения = `excludedByPick[session.id]` или, если нет, `await DeckLoader.similar(to: data.dislikedMovies(), catalog:)` — параллельно с рекомендациями (`async let`). В кэш кладём только непустой набор. Передаём `excluded:` в `data.deck`.

- [ ] **Step 1: тесты.**
  - `DeckLoaderTests`: `similarCollectsAllIds` (`similar = [1: [10, 11], 2: [11, 12]]` → `[10, 11, 12]`); `similarSkipsFailures` (`failing = true` → `[]`); `similarWithoutIdsAsksNothing` (`asked.isEmpty`).
  - `AppModelRatingTests` (помощники как в `AppModelPickTests.swift`; каталог-заглушка отвечает «похожими» по словарю и считает запросы): `rateSaves` (оценка в `store.load().ratings`); `deckDropsSimilarToDisliked` (фильм 5 с `.dislike`, `similar[5] = [2]`, `discover` даёт `[2, 3]` → в колоде нет 2, есть 3); `dislikeFilterAskedOncePerPick` (два вызова `deck` → `recommendations(for: 5)` спрошен один раз); `dislikeFilterRetriesAfterNoNetwork` (первый вызов без сети, второй с сетью → во втором 2 нет); `movieToRateWithoutMeIsNil`.
- [ ] **Step 2:** `swift test --filter DeckLoaderTests` FAIL; приложение: `xcodegen generate && xcodebuild test -project OneToOne.xcodeproj -scheme OneToOne -destination 'platform=iOS Simulator,name=iPhone 17'` FAIL.
- [ ] **Step 3:** реализовать `DeckLoader.similar`, поля и методы `AppModel`. Вызовы `model.markWatched(movieID:)` во вью не меняются.
- [ ] **Step 4:** обе команды из шага 2 — зелёные, `swift test` целиком тоже.
- [ ] **Step 5: коммит** «Убирать из колоды похожие на непонравившиеся фильмы».

### Задача 4. Плашка на вкладке «Фильмы» и документы

**Files:**
- Create: `App/OneToOne/Features/Movies/RateMovieBanner.swift`
- Modify: `App/OneToOne/Features/Movies/MoviesView.swift` (`header`)
- Modify: `docs/spec.md:46`, `docs/decisions.md`, `docs/plan.md` («Карта модулей», раздел `// Movies` и `AppData`)

**Interfaces:**
- Consumes: `AppModel.movieToRate`, `AppModel.rate(movieID:_:)`, `MovieVerdict`.
- Produces: `struct RateMovieBanner: View { let movie: Movie; let onRate: (MovieVerdict) -> Void }`.

Вид: строка «Как вам «{title}»?» (`.subheadline`, до 2 строк), справа круглые кнопки 👍 и 👎 и ✕ (`xmark`, вторичный цвет). Фон — `.fill.tertiary` в `RoundedRectangle(cornerRadius: 16, style: .continuous)`, отступы 12/14 (**решение плана**: в макете плашка белая на сером, но `WatchlistView` — `.plain`-список на белом, белая плашка там пропадёт; заливка видна в обеих темах). В `MoviesView.header` — своя `Section` сразу после секции `PickCard`, с теми же `listRowInsets`/`listRowBackground(.clear)`/`listRowSeparator(.hidden)`, только `if let movie = model.movieToRate`. Кнопкам — `.buttonStyle(.borderless)`, иначе в строке `List` нажатие любой срабатывает как все сразу. Исчезновение — `withAnimation`.

- [ ] **Step 1:** `RateMovieBanner` с `#Preview` (длинное и короткое название), встроить в `MoviesView`.
- [ ] **Step 2:** проверить вручную в симуляторе: DEBUG-переключателем пройти подбор до «Смотрим»; чтобы не ждать день, в превью/отладке выставить `watchedAt` на вчера. Плашка видна, каждая из трёх кнопок её убирает, VoiceOver читает подписи. Скриншоты светлой и тёмной темы для PR.
- [ ] **Step 3: документы.**
  - `docs/spec.md:46` — вместо «После просмотра ничего оценивать не нужно (так решили вы).»: «На следующий день после «Смотрим» под карточкой вечера можно оценить фильм 👍 / 👎 (необязательно): 👍 поднимает «похожие» на него среди рекомендаций, 👎 их убирает (решили при обсуждении #56).»
  - `docs/decisions.md` — строка: «2026-10-10: Оценка просмотренных фильмов: плашка 👍 / 👎 / ✕ под карточкой вечера со следующего дня после «Смотрим», каждый за себя. 👍 делает фильм затравкой «похожих» (👍 от обоих — первой), 👎 убирает «похожие» на 3 последних таких фильма из рекомендаций (не из списков), жанры не трогаем. Причина: подбор подстраивается под вкус без лишних запросов (до 9 на подбор) и не навязывает оценку; решили при обсуждении #56.»
  - `docs/plan.md`, «Карта модулей»: добавить `MovieVerdict`, `MovieRating`, параметр `excluded` у `DeckBuilder.build`, поля `watchedAt`, `ratings` у `AppData`.
- [ ] **Step 4:** тесты приложения (команда из задачи 3) и `swift test` зелёные.
- [ ] **Step 5: коммит** «Добавить плашку оценки фильма на вкладку Фильмы».
