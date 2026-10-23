# Экраны вечера с фильмом (#23): план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** экраны «настроение → свайпы → „Совпадение!“ → „Смотрим“» и карточка текущего подбора на вкладке «Фильмы».

**Architecture:** логика «текущего подбора» — в `Core` (`AppData+Pick.swift`), состояние карточки и debug-переключатель — в приложении с тестами, экраны — тонкий SwiftUI в `App/OneToOne/Features/Movies/`. Готовая логика #22 (`startPick`, `swipe`, `matches`, `likedByAnyone`, `markWatched`, `deck(for:catalog:)`) не меняется.

**Tech Stack:** SwiftUI (iOS 26), Swift 6, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-10-movie-evening-screens-design.md`

## Global Constraints
- Цвета и компоненты только из `DesignSystem` (`BrandGradient.primary`, `Palette.tile`, `Palette.background`, `GradientButton`, `Card`).
- Светлая и тёмная тема, интерфейс только на русском.
- Имена из «Карты модулей»: `MoodPickerView`, `SwipeDeckView`, `MovieCardView`, `MatchView`, `MatchesListView`.
- `AppModel.data` меняется только через `model.update { … }` или готовые методы `AppModel+Movies.swift`.
- Колоду (`model.deck(for:catalog:)`) грузим один раз на открытие экрана свайпов: до 6 запросов из 200 в день.
- Файлы маленькие, одна ответственность; новых зависимостей нет.

## Review Focus
1. **Колода пустая сразу** (нет сети и пустые списки, или я уже всё свайпнул): вместо вечного «Собираем колоду…» сразу экран конца колоды. Проверка руками в задаче 4.
2. **Двойное нажатие кнопки во время улёта карточки** не свайпает фильм дважды и не пропускает следующий. Гард в задаче 3.
3. **Совпадение на последней карточке:** после «Ещё свайпать» виден экран «Совпали», а не пустота. Задача 4.
4. **Фильма нет в `movieCache`** (старые данные): список совпадений его пропускает, без падения. Тест `moviesSkipsUnknownIDs` в задаче 1.
5. **Без постера и без рейтингов** карточка выглядит нормально: плитка со значком, строки рейтинга нет. Превью в задаче 3.

---

### Задача 1. Текущий подбор в Core

**Files:**
- Modify: `Packages/OneToOneKit/Sources/Core/Movies/AppData+Pick.swift`
- Test: `Packages/OneToOneKit/Tests/CoreTests/Movies/CurrentPickTests.swift` (хелперы `man`, `woman`, `movie`, `pairedData`, `at(hours:)` как в `PickTests.swift`)

**Interfaces:**
- Produces:
  - `public var currentPick: PickSession? { get }` — последний подбор, если ни один фильм с ♥ (последний свайп каждого, как в `MatchFinder.likedByAnyone`) в нём не в `watched`.
  - `public func hasSwiped(in session: PickSession, person: UUID) -> Bool`
  - `public func movies(_ ids: [Int]) -> [Movie]` — из `movieCache` в том же порядке, неизвестные id пропускаются.

- [ ] **Step 1: Тесты**
  - `noSessionsNoCurrentPick`: `AppData().currentPick == nil`.
  - `latestSessionIsCurrent`: два `startPick` → `currentPick == второй`.
  - `watchingLikedMovieEndsPick`: ♥ на `movie(1)` от `man`, `markWatched(movieID: 1)` → `currentPick == nil`.
  - `watchingUnlikedMovieKeepsPick`: ✕ на `movie(1)`, `markWatched(movieID: 1)` → `currentPick == session`.
  - `newPickAfterWatchedIsCurrent`: после закрытого подбора `startPick` → `currentPick == новый`.
  - `hasSwipedOnlyForThatPerson`: свайп `man` → `hasSwiped(in:person: man.id) == true`, `woman.id` → `false`.
  - `moviesSkipsUnknownIDs`: свайп кладёт `movie(1)` в кэш; `movies([2, 1]).map(\.id) == [1]`.
- [ ] **Step 2:** `cd Packages/OneToOneKit && swift test --filter CurrentPickTests` — не компилируется.
- [ ] **Step 3:** реализовать три члена в `AppData+Pick.swift` (для ♥ использовать `MatchFinder.likedByAnyone(swipes(in:))`).
- [ ] **Step 4:** `swift test` — всё зелёное.
- [ ] **Step 5:** коммит «Добавить текущий подбор».

### Задача 2. Состояние карточки вечера, настроения, переключатель «я»

**Files:**
- Create: `App/OneToOne/Features/Movies/PickCardState.swift`, `App/OneToOne/Features/Movies/Mood+Title.swift`, `App/OneToOne/AppModel+Debug.swift`
- Modify: `App/OneToOne/AppModel+Movies.swift` (`var currentPick: PickSession? { data.currentPick }`)
- Test: `App/OneToOneTests/PickCardStateTests.swift`, `App/OneToOneTests/AppModelDebugTests.swift`

**Interfaces:**
- Consumes: задача 1.
- Produces:
  - `enum PickCardState: Equatable { case noPick; case partnerStarted(partnerName: String, mood: Mood); case inProgress(session: PickSession, matchCount: Int) }`, `static func make(_ data: AppData) -> PickCardState`. `partnerStarted` — подбор начал не я и я в нём ещё не свайпал; иначе `inProgress`.
  - `extension Mood { var title: String; var emoji: String }` — тексты из спецификации: «Посмеяться», «Что-то лёгкое», «Пощекотать нервы», «Поплакать», «Залипнуть», «Романтика».
  - `#if DEBUG extension AppModel { func switchMe() }` — `meID` на другого из пары; без пары ничего не делает.

- [ ] **Step 1: Тесты**
  - `noPickState`: пара без подборов → `.noPick`.
  - `partnerStartedState`: подбор начала `woman`, я `man` без свайпов → `.partnerStarted(partnerName: "Аня", mood: .light)`.
  - `inProgressAfterMySwipe`: тот же подбор, я свайпнул → `.inProgress(session:, matchCount: 0)`.
  - `inProgressWhenIStarted`: начал я, свайпов нет → `.inProgress(..., matchCount: 0)`.
  - `matchCountCounted`: оба ♥ на одном фильме → `matchCount == 1`.
  - `switchMeTogglesAndSaves`: `switchMe()` → `meID == woman.id`, в `store.load()` тоже; второй раз → `man.id`.
- [ ] **Step 2:** `xcodegen generate && xcodebuild test -project OneToOne.xcodeproj -scheme OneToOne -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:OneToOneTests/PickCardStateTests -only-testing:OneToOneTests/AppModelDebugTests` — не компилируется.
- [ ] **Step 3:** реализовать.
- [ ] **Step 4:** те же тесты зелёные.
- [ ] **Step 5:** коммит «Добавить состояние карточки вечера и переключатель «я»».

### Задача 3. Настроение, карточка фильма, колода свайпов

**Files:**
- Create: `Features/Movies/MoodPickerView.swift`, `MovieCardView.swift`, `SwipeDeckView.swift`, `SwipeLabel.swift` (метка «ДА» / «НЕТ» / «НА БУДУЩЕЕ»), `PickFlowView.swift` (корень `fullScreenCover`: `NavigationStack`, крестик «Закрыть»).

**Interfaces:**
- Consumes: `Mood.title/emoji`, `model.startPick(mood:)`, `model.swipe(_:movie:in:) -> Bool`, `model.deck(for:catalog:)`, `@Environment(\.movieCatalog)`.
- Produces:
  - `struct PickFlowView: View { init(session: PickSession?) }` — `nil` → начинается с `MoodPickerView`, иначе сразу `SwipeDeckView(session:)`. Закрытие через `@Environment(\.dismiss)`.
  - `struct MoodPickerView: View { let onStart: (PickSession) -> Void }`
  - `struct SwipeDeckView: View { let session: PickSession }`
  - `struct MovieCardView: View { let movie: Movie }`

- [ ] **Step 1:** `MoodPickerView` — `LazyVGrid` 2 колонки, плитки `Palette.tile`, выбранная в `BrandGradient.primary` с белым текстом; `GradientButton("Свайпать")` неактивна без выбора.
- [ ] **Step 2:** `MovieCardView` — постер `AsyncImage` на всю карточку (`RoundedRectangle` 24), снизу градиент в чёрный: название (`.title2.bold()`), «год · 2 жанра», описание `lineLimit(3)`, рейтинги «IMDb 7.4 · Кинопоиск 7.8» (формат `%.1f`, пропуск пустых, нет обоих — строки нет). Превью: с постером и рейтингами; без постера и рейтингов.
- [ ] **Step 3:** `SwipeDeckView` — состояния: загрузка («Собираем колоду…»), карточки, конец колоды (пока заглушка, задача 4).
  - Колода `@State var deck: [Movie]`, грузится в `.task` один раз.
  - Видны верхняя и следующая (масштаб 0.95). `DragGesture`: смещение + поворот `offset.width / 20` градусов, порог 120 pt по горизонтали, −120 pt вверх → свайп; иначе `.spring` назад. Метка `SwipeLabel` с прозрачностью по смещению.
  - Кнопки ✕ 🔖 ♥ (круглые, ♥ в градиенте) запускают тот же улёт.
  - `@State var isAnimating` — пока карточка улетает, новые свайпы игнорируются (Review Focus 2).
  - Свайп: `model.swipe(...)`, `swipeCount += 1`; `.sensoryFeedback(.impact(weight: .light), trigger: swipeCount)`, `.sensoryFeedback(.success, trigger: matchCount)`.
  - Сверху `mood.title` и «N из M».
- [ ] **Step 4:** `PickFlowView` + временная кнопка в `MoviesView` для проверки. Сборка: `xcodebuild build -project OneToOne.xcodeproj -scheme OneToOne -destination 'platform=iOS Simulator,name=iPhone 17'` — `BUILD SUCCEEDED`; в симуляторе настроение → свайпы жестом и кнопками.
- [ ] **Step 5:** коммит «Добавить выбор настроения и колоду свайпов».

### Задача 4. Совпадение, конец колоды, вкладка «Фильмы»

**Files:**
- Create: `Features/Movies/MatchView.swift`, `MatchesListView.swift`, `DeckEndView.swift`, `PickCard.swift`
- Modify: `Features/Movies/SwipeDeckView.swift`, `MoviesView.swift`

**Interfaces:**
- Consumes: `PickCardState.make`, `model.currentPick`, `model.matches(in:)`, `model.likedByAnyone(in:)`, `model.markWatched(movieID:)`, `data.movies(_:)`, `model.switchMe()`.
- Produces:
  - `struct MatchView: View { let movie: Movie; let onWatch: () -> Void; let onContinue: () -> Void }`
  - `struct MatchesListView: View { let title: String; let movies: [Movie]; let onWatch: (Movie) -> Void }` — `Section(title)` с `MovieRow` и кнопкой «Смотрим»; встраивается в `List`.
  - `struct DeckEndView: View { let session: PickSession; let onWatch: () -> Void }`
  - `struct PickCard: View { let state: PickCardState; let onOpen: () -> Void; let onNewPick: () -> Void }`

- [ ] **Step 1:** `MatchView` — `.fullScreenCover`/`sheet` из `SwipeDeckView` при `swipe == true`: «💘 Совпадение!» (градиентный текст `BrandGradient.text`), постер, название, «Вам обоим понравилось», `GradientButton("Смотрим")` → `markWatched` и закрыть весь `PickFlowView`; «Ещё свайпать» → назад.
- [ ] **Step 2:** `DeckEndView` — `matches` не пусто → «Совпали»; иначе `likedByAnyone` не пусто → «Кто-то из вас лайкнул»; иначе `ContentUnavailableView` «Колода кончилась» / «Подождите, пока посвайпает {партнёр}, или начните новый подбор». «Смотрим» → `markWatched` + закрыть. Показывается, когда колода пуста — в том числе сразу после загрузки (Review Focus 1, 3).
- [ ] **Step 3:** `PickCard` по `PickCardState`: тексты из спецификации; градиент `BrandGradient.primary`, белая кнопка; под карточкой в `.inProgress`/`.partnerStarted` ссылка «Новый подбор».
- [ ] **Step 4:** `MoviesView` — `List`: секция `PickCard`, при совпадениях `MatchesListView("Совпали")`, ниже `WatchlistView` как раньше (без вложенного `List`: вынести содержимое или разместить карточку над ним через `safeAreaInset(edge: .top)` — выбрать то, что не ломает свайп-удаление в списке). `fullScreenCover` с `PickFlowView`. Debug: `ToolbarItem` меню «Я: {имя}» → `model.switchMe()`. Убрать временную кнопку из задачи 3.
- [ ] **Step 5:** сборка `BUILD SUCCEEDED`; руками в симуляторе весь путь за двоих: Боря выбирает настроение, ♥ на фильм → переключить на Аню → карточка «Боря выбрал…» → ♥ на тот же → «Совпадение!» → «Смотрим» → карточка «Что смотрим сегодня?». И путь без совпадения до «Кто-то из вас лайкнул».
- [ ] **Step 6:** коммит «Добавить совпадение, конец колоды и карточку вечера».

### Задача 5. Проверка, документы, PR

- [ ] **Step 1:** `cd Packages/OneToOneKit && swift test` и тесты приложения командой из `CLAUDE.md` — зелёные.
- [ ] **Step 2:** скриншоты светлой и тёмной темы (`xcrun simctl ui booted appearance light|dark`, `xcrun simctl io booted screenshot`) — `docs/design/screens/movie-{mood,deck,match,tab}-{light,dark}.png`; видео пути `xcrun simctl io booted recordVideo docs/design/screens/movie-flow.mp4` (короткое, до ~10 МБ).
- [ ] **Step 3:** `docs/decisions.md` — строка про «текущий подбор»; в `MoviesView` убрать «появится в #23».
- [ ] **Step 4:** `/code-review`, исправить найденное.
- [ ] **Step 5:** PR `Closes #23`, ссылки на скриншоты и видео; `gh pr merge --squash --delete-branch --auto`.
