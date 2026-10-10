# План версии 1

> **Для Claude в чате задачи:** прочитай `CLAUDE.md`, свою задачу ниже (её номер есть в issue) и блоки «Общие правила» и «Карта модулей». Делай по TDD (скил test-driven-development): сначала тест, потом код. Имена типов и функций бери из «Карты модулей» точно, их используют соседние задачи.

**Цель:** версия 1 из [spec.md](spec.md): выбор фильма свайпами и трекер (секс, оргазмы, цикл) для пары на двух iPhone.

**Архитектура:**
- Вся логика (модели, расчёты, колода, совпадения, статистика, цикл) лежит в локальном Swift-пакете `OneToOneKit`. Его тесты быстро гоняются командой `swift test` без симулятора.
- Приложение `OneToOne` — тонкий слой SwiftUI-экранов поверх пакета.
- Данные хранятся одной структурой `AppData`, которая лежит JSON-файлом на телефоне. Синхронизация через iCloud подключается последней, когда будет Apple Developer.

**Стек:**
- SwiftUI, iOS 26, Swift 6, Swift Testing.
- XcodeGen: проект описан текстом в `project.yml`.
- Внешние сервисы: Кинопоиск (poiskkino.dev, бывший kinopoisk.dev), OMDb.
- CloudKit через `CKSyncEngine`.

**Спецификация:** [docs/spec.md](spec.md).

## Общие правила
- Минимальная iOS 26, только iPhone, интерфейс только на русском.
- Пара — ровно двое, мужчина и женщина.
- Дизайн: направление B «Яркий градиент» (оранжевый → розовый → фиолетовый), светлая и тёмная тема. Цвета и компоненты берём только из `DesignSystem`.
- Управление как у родных приложений. Отметка секса — около 3 касаний.
- Уведомления без откровенных слов.
- Секреты (ключи API) только в `Config/Secrets.xcconfig`, он в `.gitignore`.
- Новая зависимость → строка в `docs/decisions.md`.
- Даты дней (месячные, серии, «сегодня») считаются по местному календарю через `DayKey`, а не через `Date`.

## Команды
- Логика: `cd Packages/OneToOneKit && swift test`
- Приложение: `xcodegen generate && xcodebuild test -project OneToOne.xcodeproj -scheme OneToOne -destination 'platform=iOS Simulator,name=iPhone 17'`
- `OneToOne.xcodeproj` генерируется из `project.yml` и в git не хранится. После `git pull` выполняй `xcodegen generate`.

## Что проверять особо (Review Focus)
1. **Цикл без отметок или с одной отметкой:** фаза `unknown` или прогноз по 28 дням, без падений. Тест в задаче 7.
2. **Два секса в один день** — это один день серии. Месяц считается по местному календарю. Тест в задаче 6.
3. **Нет интернета, ошибка API, нет рейтинга:** колода всё равно строится из ваших списков, карточка показывается без рейтинга. Тесты в задачах 11 и 13.
4. **Один фильм в обоих списках и в рекомендациях** даёт одну карточку. Свайпы в разное время дают одно совпадение. Тесты в задачах 13 и 14.
5. **Пара М+М или Ж+Ж** отклоняется. Тест в задаче 4.

## Карта модулей

```
project.yml                         описание Xcode-проекта (XcodeGen)
Config/Secrets.example.xcconfig     шаблон ключей (в git); Secrets.xcconfig — нет
App/OneToOne/
  OneToOneApp.swift                 точка входа, вкладки
  AppModel.swift                    @Observable, держит AppData, сохраняет через Store
  AppModel+Tracker.swift            действия трекера (поток А)
  AppModel+Movies.swift             действия фильмов (поток Б)
  Features/Onboarding|Home|Tracker|Cycle|Movies/   экраны
Packages/OneToOneKit/
  Sources/Core/Pair/                Sex, Person, Couple
  Sources/Core/Tracker/             SexEntry, Stats, Cycle, Tip
  Sources/Core/Movies/              Movie, Mood, Watchlist, Swipe, Deck, Match
  Sources/Core/Storage/             AppData, Store, LocalStore, InMemoryStore
  Sources/MovieAPI/                 KinopoiskCatalog, RatingsProvider
  Sources/DesignSystem/             цвета, градиент, компоненты
  Sources/Sync/                     CloudKit (задачи 16–18)
  Tests/…                           зеркально Sources
```

**Ключевые типы** (модуль `Core`, если не сказано иное):
```swift
// Pair
enum Sex: String, Codable { case male, female }
struct Person: Codable, Identifiable, Equatable { let id: UUID; var name: String; var sex: Sex }
struct Couple: Codable, Equatable { let man: Person; let woman: Person
  static func make(_ a: Person, _ b: Person) throws(CoupleError) -> Couple }
enum CoupleError: Error, Equatable { case sameSex }
struct UpcomingBirthday: Equatable { let person: Person; let isMe: Bool; let daysLeft: Int }
enum BirthdayCalculator { static func upcoming(couple: Couple, meID: UUID?, today: DayKey, within: Int = 30) -> UpcomingBirthday? }
struct UpcomingAnniversary: Equatable { let years: Int; let daysLeft: Int }
enum AnniversaryCalculator { static func upcoming(since: DayKey?, today: DayKey, within: Int = 30) -> UpcomingAnniversary? }
enum UpcomingEvent: Equatable { case birthday(UpcomingBirthday); case anniversary(UpcomingAnniversary); var daysLeft: Int }
enum UpcomingEvents { static func list(_ data: AppData, today: DayKey) -> [UpcomingEvent] }
func daysText(_ count: Int) -> String // «1 день», «2 дня», «5 дней»

// День без часового пояса
struct DayKey: Codable, Hashable, Comparable { let year: Int; let month: Int; let day: Int
  init(_ date: Date, calendar: Calendar = .current); func adding(days: Int) -> DayKey
  func occurrence(in year: Int) -> DayKey }

// Tracker
enum SexType: String, Codable, CaseIterable { case vaginal, anal, cunnilingus, blowjob } // «Классика», «Анал», «Куни», «Минет»
struct SexEntry: Codable, Identifiable, Equatable { let id: UUID; var day: DayKey; var types: Set<SexType>
  var orgasmsMan: Int; var orgasmsWoman: Int; let createdBy: UUID }
struct Stats: Equatable { let total: Int; let thisMonth: Int; let orgasmsMan: Int; let orgasmsWoman: Int
  let typeCounts: [SexType: Int]; let currentStreak: Int; let bestStreak: Int }
enum StatsCalculator { static func stats(_ entries: [SexEntry], today: DayKey) -> Stats }
enum HerMood: String, Codable, CaseIterable { case wants, neutral, leaveMeAlone } // «Хочу», «Обычно», «Не трогать»
enum CyclePhase: Equatable { case menstruation, follicular, ovulation, luteal, unknown }
struct CycleForecast: Equatable { let phase: CyclePhase; let dayOfCycle: Int?; let averageLength: Int
  let nextPeriodStart: DayKey? }
enum CycleCalculator { static func forecast(periodDays: Set<DayKey>, today: DayKey) -> CycleForecast }
struct Tip: Equatable { let text: String; let isEstimate: Bool }
enum TipProvider { static func tip(forecast: CycleForecast, herMood: HerMood?) -> Tip }
enum CheerProvider { static func cheer(forecast: CycleForecast) -> String? } // фраза для неё на главной

// Movies
struct Movie: Codable, Identifiable, Hashable { let id: Int /* id Кинопоиска */; let title: String; let year: Int?
  let genres: [String]; let overview: String; let posterURL: URL?; var imdbID: String?; var ratings: Ratings }
struct Ratings: Codable, Hashable { var imdb: Double?; var kinopoisk: Double? }
enum Mood: String, Codable, CaseIterable { case laugh, light, thrill, cry, immerse, romance; var genres: [String] }
struct WatchlistItem: Codable, Equatable { let movie: Movie; let ownerID: UUID; let addedAt: Date; let fromLater: Bool }
enum SwipeAction: String, Codable { case no, yes, later }
struct PickSession: Codable, Identifiable, Equatable { let id: UUID; let mood: Mood; let startedBy: UUID; let startedAt: Date }
struct Swipe: Codable, Equatable { let sessionID: UUID; let personID: UUID; let movieID: Int; let action: SwipeAction; let date: Date }
enum DeckBuilder { static func build(lists: [WatchlistItem], recommendations: [Movie], mood: Mood,
  watched: Set<Int>, swipedByMe: Set<Int>, limit: Int = 40) -> [Movie] }
enum MatchFinder { static func matches(_ swipes: [Swipe], couple: Couple) -> [Int]
  static func likedByAnyone(_ swipes: [Swipe]) -> [Int] }

// Storage
struct AppData: Codable, Equatable { var couple: Couple?; var meID: UUID?; var togetherSince: DayKey?; var sexEntries: [SexEntry]
  var periodDays: Set<DayKey>; var herMoods: [DayKey: HerMood]; var watchlist: [WatchlistItem]
  var sessions: [PickSession]; var swipes: [Swipe]; var watched: Set<Int>; var movieCache: [Int: Movie] }
protocol Store: Sendable { func load() throws -> AppData; func save(_ data: AppData) throws }
final class LocalStore: Store   // JSON в Application Support
final class InMemoryStore: Store  // для тестов и превью

// MovieAPI
protocol MovieCatalog: Sendable { func search(_ query: String) async throws -> [Movie]
  func recommendations(for id: Int) async throws -> [Movie]; func discover(genres: [String]) async throws -> [Movie] }
struct KinopoiskCatalog: MovieCatalog { init(apiKey: String, session: URLSession = .shared) }
protocol RatingsProvider: Sendable { func ratings(for movie: Movie) async -> Ratings } // ошибки → nil, не throw
struct OMDbFallbackRatingsProvider: RatingsProvider { init(omdbKey: String, session: URLSession = .shared) }
```

**Настроения → жанры Кинопоиска:** laugh «Посмеяться» [комедия] · light «Что-то лёгкое» [комедия, семейный, мультфильм] · thrill «Пощекотать нервы» [триллер, ужасы] · cry «Поплакать» [драма] · immerse «Залипнуть» [фантастика, детектив, приключения] · romance «Романтика» [мелодрама].

## Потоки и порядок

```
Фундамент (по порядку):  1 → 2 → 4 → 5        3 параллельно после 1
                                    ↓
Поток А — Трекер (Даша):   6 → 7 → 8 → 9 → 10
Поток Б — Фильмы (Максюша): 11 → 12 → 13 → 14 → 15
                                    ↓
Синхронизация (Максюша, ждёт Apple Developer): 16 → 17 → 18
```
- Потоки А и Б почти не пересекаются: свои папки в `Core/`, `Features/` и свой файл `AppModel+…`. Общие файлы (`AppData`, `OneToOneApp.swift`) правим маленькими изменениями и сразу вливаем.
- Задачи потока Б тяжелее (сеть, API), поэтому они на тарифе Max. Задачи потока А короче, они подходят для Pro.

**Как взять следующую задачу:** на доске в колонке Todo берёшь **самую верхнюю задачу своего потока**, у которой все «Зависит от» уже в Done. Если свой поток ждёт, бери задачу из фундамента или чужого потока, но скажи напарнику голосом.

---

## Фундамент

### Задача 1. Каркас проекта (#9)
**Цель:** приложение запускается в симулаторе с тремя пустыми вкладками («Главная», «Фильмы», «Трекер»), тесты пакета проходят.
**Файлы:**
- создать `project.yml`, `App/OneToOne/OneToOneApp.swift`, `Packages/OneToOneKit/Package.swift` (цели `Core`, `MovieAPI`, `DesignSystem` с тестами, платформы iOS 26 и macOS 26), `Config/Secrets.example.xcconfig` (`KINOPOISK_API_KEY`, `OMDB_API_KEY`);
- дополнить `.gitignore` строками `OneToOne.xcodeproj/` и `Config/Secrets.xcconfig`.
**Тесты:** `CoreTests/SmokeTests.swift`: `@Test func packageBuilds() { #expect(true) }`.
**Готово когда:**
- [ ] `swift test` зелёный;
- [ ] `xcodebuild test` зелёный;
- [ ] приложение открывается в симуляторе;
- [ ] в `CLAUDE.md` раздел «Стек → Сборка и тесты» заполнен командами из блока «Команды»;
- [ ] в `docs/decisions.md` записаны XcodeGen и локальный пакет.
**Руками:** `brew install xcodegen` (Claude может сделать сам).
**Зависит от:** —

### Задача 2. Проверки на GitHub (CI) (#10)
**Цель:** на каждый PR GitHub сам собирает приложение и гоняет тесты.
**Файлы:** создать `.github/workflows/ci.yml` (runner `macos-26`, шаги: `brew install xcodegen`, `swift test` в пакете, `xcodegen generate`, `xcodebuild test`). Перед `xcodegen generate` скопировать `Secrets.example.xcconfig` в `Secrets.xcconfig`.
**Готово когда:**
- [ ] в PR этой задачи проверка зелёная;
- [ ] в `docs/workflow.md` добавлена строка, что вливаем только зелёные PR.
**Руками (Максюша, владелец репо):** включить защиту `main` с обязательной проверкой `ci` (Settings → Branches).
**Зависит от:** 1

### Задача 3. Дизайн-система «Яркий градиент» (#11)
**Цель:** набор цветов и компонентов, из которых собираются все экраны.
**Файлы:** `Sources/DesignSystem/{Palette.swift, BrandGradient.swift, Components/GradientButton.swift, Components/StatTile.swift, Components/Card.swift}`, плюс экран-витрина `App/OneToOne/Features/DesignPreview.swift` (только в Debug).
**Интерфейсы:**
- `BrandGradient.primary: LinearGradient` (#FA7E1E → #D62976 → #962FBF);
- `GradientButton(title:action:)`;
- `StatTile(title:value:)`;
- `Card { content }`.
Светлая и тёмная тема через системные цвета фона.
**Готово когда:**
- [ ] витрина выглядит как вариант B из `docs/design/visual-style.html` в светлой и тёмной теме;
- [ ] есть скриншоты в PR.
**Зависит от:** 1

### Задача 4. Модели и хранилище (#12)
**Цель:** все данные приложения сохраняются на телефоне и переживают перезапуск.
**Файлы:** `Core/Pair/*.swift`, `Core/DayKey.swift`, `Core/Storage/{AppData,Store,LocalStore,InMemoryStore}.swift`, `App/OneToOne/AppModel.swift`, тесты в `CoreTests/`.
**Интерфейсы:**
- создаёт `Sex`, `Person`, `Couple`, `CoupleError`, `DayKey`, `AppData`, `Store`, `LocalStore`, `InMemoryStore` (смотри «Карту модулей»);
- поля трекера и фильмов в `AppData` объявить сразу пустыми массивами и множествами, сами типы — заглушками с полями из карты.
- `AppModel`: `@Observable @MainActor final class AppModel { var data: AppData; init(store: Store); func update(_ change: (inout AppData) -> Void) }`, `update` сразу сохраняет.
**Тесты:**
- `coupleRejectsSameSex`: `#expect(throws: CoupleError.sameSex) { try Couple.make(man1, man2) }`, то же для двух женщин;
- `coupleOrdersManWoman`: `make(woman, man)` даёт `.man == man`;
- `dayKeyIgnoresTime`: 23:59 и 00:01 одного дня дают один ключ, следующего дня — разные;
- `localStoreRoundTrip`: `save` и `load` во временную папку возвращают равный `AppData`;
- `localStoreEmptyWhenNoFile`: `load` без файла возвращает пустой `AppData()`.
**Готово когда:** тесты зелёные, приложение запускается.
**Зависит от:** 1

### Задача 5. Знакомство: имя, пол, пара (#13)
**Цель:** при первом запуске человек вводит имя и пол, потом создаёт пару: вводит имя и пол партнёра локально, до появления iCloud-приглашения в задаче 17.
**Файлы:** `App/OneToOne/Features/Onboarding/OnboardingView.swift`.
**Интерфейсы:** пишет `AppData.couple` и `AppData.meID`. Пока пары нет, вкладки не показываются.
**Готово когда:**
- [ ] при одинаковом поле показывается понятная ошибка «Пара — это мужчина и женщина», и пара не создаётся;
- [ ] после создания пары открываются вкладки;
- [ ] перезапуск онбординг не показывает.
**Зависит от:** 3, 4

## Поток А — Трекер

### Задача 6. Запись секса и статистика (#14)
**Цель:** отметить секс примерно за 3 касания и увидеть счётчики.
**Файлы:** `Core/Tracker/{SexEntry,Stats,StatsCalculator}.swift`, `App/…/AppModel+Tracker.swift`, `Features/Tracker/{LogSexView,StatsView}.swift`.
**Интерфейсы:** `AppModel.logSex(types:orgasmsMan:orgasmsWoman:day:)`, `updateSex(_:)`, `deleteSex(id:)`.
**Как работает отметка:**
- Типы — кнопки-переключатели, можно выбрать несколько, нужен хотя бы один.
- Оргазмы — степперы «Он» и «Она» с минимумом 0. По умолчанию значения как в прошлой записи, в самой первой — по 1 (**решение Claude**).
- День — сегодня, его можно поменять. Время не храним. За день может быть сколько угодно записей: каждый раз отмечаем отдельно.
- Править и удалять можно из списка записей.
**Тесты** (`StatsCalculatorTests`):
- `emptyStats`: все нули;
- `countsTotalAndMonth`: 3 записи в октябре и 1 в сентябре при today = 10 октября дают total 4, thisMonth 3;
- `sumsOrgasms`: (2,1)+(1,0) → orgasmsMan 3, orgasmsWoman 1;
- `countsTypes`: запись с {anal, blowjob} увеличивает оба;
- `twoEntriesSameDayIsOneStreakDay`: 8, 9, 9, 10 октября → currentStreak 3;
- `streakBrokenByGap`: 5, 6, 8 при today = 8 → currentStreak 1, bestStreak 2;
- `streakAliveIfYesterday`: последняя запись вчера → currentStreak засчитан, позавчера → 0.
**Готово когда:** тесты зелёные, отметка за 3 касания показана на видео или скриншотах в PR.
**Зависит от:** 4

### Задача 7. Расчёт цикла (#15)
**Цель:** по отмеченным дням месячных знать фазу сегодня и прогноз.
**Файлы:** `Core/Tracker/CycleCalculator.swift`, тесты.
**Правила (решение Claude):**
- Начало месячных — отмеченный день, перед которым день не отмечен.
- Средняя длина — среднее между соседними началами, ограничено 21–40. Если начал меньше двух, длина 28.
- Отсчёт: `dayOfCycle` = дней от последнего начала + 1. Если день `dayOfCycle` больше длины, считаем дальше по прогнозу, кругами.
- Фазы:
  - день отмечен или прогнозный день 1–5 → `menstruation`;
  - дни (L−16)…(L−12) → `ovulation`;
  - до овуляции → `follicular`, после неё → `luteal`;
  - отметок нет → `unknown`.
- `nextPeriodStart` = последнее начало + L (кругами, пока не станет позже сегодня).
**Тесты:**
- `noMarksIsUnknown`;
- `singleStartUses28`: начало 1 октября, today 10 октября → dayOfCycle 10, averageLength 28, follicular, next 29 октября;
- `averageOfTwoCycles`: начала 1 августа, 31 августа, 30 сентября → L 30;
- `markedDayIsMenstruation`;
- `ovulationWindow`: при L 28 дни 12–16 → ovulation;
- `clampsLength`: интервал 60 дней → 40.
**Зависит от:** 4

### Задача 8. Календарь для неё (#16)
**Цель:** Даша отмечает месячные и «как я сегодня», видит фазу и прогноз.
**Файлы:** `Features/Cycle/{HerCalendarView,HerMoodPicker}.swift`, дополнения в `AppModel+Tracker.swift`.
**Интерфейсы:** `togglePeriodDay(_ day: DayKey)`, `setHerMood(_ mood: HerMood?, for day: DayKey)`. Используется `CycleCalculator.forecast`.
**Готово когда:**
- [ ] в месячной сетке отмеченные дни залиты, прогнозные обведены, сегодняшняя фаза подписана;
- [ ] три кнопки «как я сегодня»;
- [ ] экран виден только женщине.
**Зависит от:** 5, 7

### Задача 9. Вид для него и подсказка дня (#17)
**Цель:** Максюша видит упрощённый календарь и подсказку дня.
**Файлы:** `Core/Tracker/TipProvider.swift`, тесты, `Features/Cycle/{HisCalendarView,TipCard}.swift`.
**Правила подсказки:**
- Если на сегодня есть `herMood`, он главнее фазы, и `isEstimate = false`:
  - `leaveMeAlone` → «Сегодня лучше не подходить. Серьёзно.»;
  - `wants` → «Она сама сказала, что хочет 😏»;
  - `neutral` → «Обычный день. Действуй по обстановке».
- Иначе по фазе, `isEstimate = true`, по 3 варианта текста на фазу, выбор по `dayOfCycle % 3`. Тексты пишет Claude в игривом тоне спецификации. Под подсказкой подпись «Это прогноз по циклу».
- `unknown` → «Пусть она отметит цикл, и тут появятся подсказки».
**Тесты:** `herMoodOverridesPhase`, `estimateFlagForPhase`, `unknownPhaseText`, `sameDaySameText`.
**Готово когда:** в упрощённом календаре только дни месячных и цвет фазы, без её настроения по дням. Ссылки «Что видит он» у Даши нет (см. `decisions.md`).
**Зависит от:** 7, 8

### Задача 10. Главный экран (#18)
**Цель:** главная как на наброске B: счётчик за месяц, оргазмы у каждого, подсказка (у него) или фаза (у неё), кнопки «Отметить секс» и «Выбрать фильм».
**Файлы:** `Features/Home/HomeView.swift`.
**Готово когда:**
- [ ] «Отметить секс» открывает экран из задачи 6;
- [ ] «Выбрать фильм» открывает выбор настроения из задачи 15 (до её готовности — вкладку «Фильмы»);
- [ ] скриншоты светлой и тёмной темы в PR.
**Зависит от:** 6, 9

## Поток Б — Фильмы

### Задача 11. Каталог фильмов (Кинопоиск) (#19)
**Цель:** искать фильмы и получать рекомендации на русском.
**Файлы:** `Sources/MovieAPI/KinopoiskCatalog.swift`, `Tests/MovieAPITests/` с JSON-образцами ответов и подменой `URLProtocol`.
**Интерфейсы:**
- `MovieCatalog`, `KinopoiskCatalog(apiKey:)`;
- база `https://api.poiskkino.dev/v1.5`, ключ в заголовке `X-API-KEY`;
- `search`: `/movie/search?query=`;
- `recommendations`: `/movie/{id}` → поле `similarMovies`;
- `discover`: `/movie?genres.name=…&type=movie&rating.kp=6-10&sortField=votes.kp&sortType=-1`;
- из ответа сразу берём `rating.kp`, `rating.imdb`, `externalId.imdb`, `poster.url`, `genres`, `shortDescription` (если пусто, `description`). Отдельный запрос за рейтингами не нужен.
- Бесплатно 200 запросов в день: просим только нужные поля (`selectFields`) и кладём фильмы в `movieCache`.
**Тесты:**
- `parsesSearch`: из образца получаются title, year, posterURL, genres, оба рейтинга, imdbID;
- `sendsAPIKeyHeader`;
- `throwsOnHTTPError`: на 401 и 403 (лимит) бросает ошибку;
- `recommendationsFromSimilarMovies`;
- `discoverSendsGenres`.
**Руками:** ключ из Telegram-бота @poiskkinodev_bot в свой `Config/Secrets.xcconfig`.
**Зависит от:** 4

### Задача 12. Рейтинги IMDb и Кинопоиска (#20)
**Цель:** у карточки есть рейтинги, а если их нет, ничего не ломается.
**Файлы:** `Sources/MovieAPI/OMDbFallbackRatingsProvider.swift`, тесты.
**Как работает:**
- оба рейтинга уже приходят с фильмом из каталога (задача 11);
- если `ratings.imdb` пустой, а `imdbID` есть, спрашиваем OMDb `?i={imdbID}` → `imdbRating`;
- на любую ошибку OMDb рейтинг IMDb просто остаётся пустым.
**Тесты:** `catalogRatingsKept` (OMDb не вызывается), `omdbFillsMissingImdb`, `omdbFailsKeepsKinopoisk`, `noImdbIDNoRequest`, `garbageRatingIsNil` («N/A» → nil).
**Руками:** ключ omdbapi.com в `Secrets.xcconfig`.
**Зависит от:** 11

### Задача 13. Списки и колода (#21)
**Цель:** свои списки «хочу посмотреть» и сборка колоды под настроение.
**Файлы:** `Core/Movies/{Movie,Mood,WatchlistItem,DeckBuilder}.swift`, `AppModel+Movies.swift` (`addToWatchlist(_:)`, `removeFromWatchlist(movieID:)`), `Features/Movies/{WatchlistView,MovieSearchView}.swift`.
**Правила колоды:**
- Сначала фильмы из обоих списков, без дублей: те, у кого есть жанр настроения, идут раньше.
- Потом рекомендации с жанром настроения.
- Без просмотренных и без тех, что я уже свайпнул в этом подборе.
- Не больше `limit`.
**Тесты:**
- `listsComeFirst`;
- `moodSortsListsNotFilters`: фильм из списка без жанра настроения всё равно в колоде, но после подходящих;
- `recommendationsFilteredByMood`;
- `dedupesAcrossListsAndRecs`;
- `excludesWatchedAndSwiped`;
- `worksWithNoRecommendations` (нет интернета);
- `respectsLimit`.
**Готово когда:** видны мой список и список партнёра, добавление идёт через поиск.
**Зависит от:** 11

### Задача 14. Подбор, свайпы, совпадения: логика (#22)
**Цель:** вся логика вечера с фильмом, без экранов.
**Файлы:** `Core/Movies/{PickSession,Swipe,MatchFinder}.swift`, дополнения в `AppModel+Movies.swift`.
**Интерфейсы:**
- `startPick(mood:) -> PickSession?` (nil, пока не пройдено знакомство);
- `swipe(_ action: SwipeAction, movie: Movie, in session: PickSession) -> Bool` (true — случилось совпадение);
- `markWatched(movieID:)`;
- `later` добавляет фильм в мой список с `fromLater = true`;
- `deck(for session: PickSession, catalog: MovieCatalog) async -> [Movie]`: рекомендации = `catalog.recommendations` для 5 последних фильмов, которые получили ♥ или добавлены в списки, плюс `catalog.discover(genres: mood.genres)`. Если сеть упала, рекомендаций нет, и колода строится из списков. Всё это идёт в `DeckBuilder.build`.
**Тесты:**
- `matchWhenBothYes`;
- `noMatchWhenOneNo`;
- `matchAcrossDifferentTimes`: свайпы с разницей 6 часов;
- `multipleMatchesKept`;
- `laterAddsToMyWatchlist`;
- `likedByAnyoneFallback`;
- `watchedExcludedFromNextDeck`.
**Зависит от:** 13

### Задача 15. Экраны вечера с фильмом (#23)
**Цель:** настроение → свайпы → «Совпадение!» → «Смотрим», как на наброске `docs/design/movie-flow.html`, в стиле B.
**Файлы:** `Features/Movies/{MoodPickerView,SwipeDeckView,MovieCardView,MatchView,MatchesListView}.swift`.
**Как работает:**
- Карточка: постер, название, год, жанр, описание, рейтинги (если есть).
- Свайп влево ✕, вправо ♥, вверх или кнопка 🔖 — «на будущее». Лёгкая вибрация на свайпе и сильнее на совпадении.
- Колода кончилась без совпадения → экран «Кто-то из вас лайкнул» со списком из `likedByAnyone`.
**Готово когда:** весь путь пройден в симуляторе на двух локальных людях (переключатель «я — он / она» в Debug), видео в PR.
**Зависит от:** 3, 12, 14

## Синхронизация (после Apple Developer)

### Задача 16. iCloud: хранилище пары (#24)
**Цель:** данные сохраняются в iCloud и восстанавливаются на новом телефоне.
**Файлы:** `Sources/Sync/CloudSync.swift` на `CKSyncEngine`, своя зона `Couple`, по типу записи на каждый тип из `AppData`; включение iCloud в `project.yml`.
**Тесты:** преобразование каждого типа в `CKRecord` и обратно (`recordRoundTrip…`).
**Руками:** создать контейнер iCloud в Apple Developer.
**Зависит от:** 4, Apple Developer

### Задача 17. Приглашение партнёра через iCloud (#25)
**Цель:** заменить локальную пару из задачи 5 настоящей: один отправляет приглашение (CKShare по ссылке в мессенджер), второй принимает его, выбирает имя и пол, и данные становятся общими.
**Готово когда:**
- [ ] на двух телефонах запись секса появляется у второго;
- [ ] пара М+М или Ж+Ж не создаётся.
**Зависит от:** 5, 16

### Задача 18. Уведомления (#26)
**Цель:**
- партнёр запустил подбор → «Пора выбрать фильм 🍿»;
- совпадение → «У вас совпадение! 💘».
Без откровенных слов.
**Файлы:** подписки CloudKit, `Sources/Sync/Notifications.swift`.
**Зависит от:** 14, 17
