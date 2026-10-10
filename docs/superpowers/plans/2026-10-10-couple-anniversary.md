# Годовщина пары (#58) — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** приложение знает дату «вместе с…» (вводится на экране «Пара») и за 30 дней до годовщины показывает на главной плашку рядом с плашкой дня рождения.

**Architecture:** расчёт годовщины и общий список ближайших событий — в `Core` с тестами, рядом с `BirthdayCalculator`. Дата хранится в `AppData.togetherSince`. Приложение: экран `PairSettingsView` по шестерёнке на главной, общая строка выбора даты `DateRow` (из `BirthDateRow`), плашки на главной из `UpcomingEvents.list`.

**Tech Stack:** Swift 6, SwiftUI (iOS 26), Swift Testing, XcodeGen.

**Spec:** описание согласовано в чате (небольшая фича, отдельного документа нет):
- Экран «Пара»: шестерёнка справа вверху на главной, «Витрина» (DEBUG) переезжает влево. Одна строка «Вместе с»: пока даты нет — «Выбрать», нажатие раскрывает колёсики, как у даты рождения. Сохраняется сразу. Кнопка «Убрать дату». Дату в будущем выбрать нельзя.
- Главная: под карточкой дня до двух плашек (день рождения и годовщина), ближайшая сверху, в один день — сверху день рождения. Каждая за 30 дней.
- Тексты: «💞 Годовщина через 12 дней», «💞 Годовщина завтра», в сам день «💞 3 года вместе! С годовщиной!».
- Первая годовщина — через год после даты; в год знакомства плашки нет. 29 февраля в невисокосный год → 1 марта. Переход через Новый год. «Сегодня» = 0 дней, «вчера» не показываем.
- Без даты плашки годовщины нет; старые данные читаются.

## Global Constraints
- Без новых зависимостей.
- Тексты только на русском, дословно как выше. Имена не склоняем, имя первым; текст дня рождения не меняется («🎂 Даша: День рождения через 12 дней»).
- Окно 30 дней (`within: Int = 30`), как у `BirthdayCalculator`.
- Новое поле `AppData` — обязательно в `init(from:)` через `decodeIfPresent`.
- Дни считаем через `DayKey`, «сегодня» приходит снаружи.
- Логика: `cd Packages/OneToOneKit && swift test`. Приложение: `xcodegen generate && xcodebuild test -project OneToOne.xcodeproj -scheme OneToOne -destination 'platform=iOS Simulator,name=<свой симулятор>'`.
- Коммиты на русском в повелительном наклонении, с `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus
1. Дата «вместе с» = сегодня или меньше года назад → плашки нет до первой полной годовщины. Тесты `anniversaryNotInFirstYear`, `anniversarySameDayAsStartIsHidden` в задаче 1.
2. Годовщина и день рождения в один день → обе плашки, день рождения сверху. Тест `birthdayFirstOnSameDay` в задаче 2.
3. Начали 29 февраля, год невисокосный → 1 марта, и число лет верное. Тест `leapDayAnniversaryInCommonYear` в задаче 1.
4. Годовщина 31 декабря, сегодня 31 декабря → 0 дней, а не год до следующей. Тест `anniversaryTodayIsZero` в задаче 1.
5. Старый файл без `togetherSince` читается, дата пустая. Тест `appDataDecodesFileWithoutTogetherSince` в задаче 2.

---

### Задача 1: дата в году и расчёт годовщины (Core)

**Files:**
- Create: `Packages/OneToOneKit/Sources/Core/DayKey+Yearly.swift`
- Create: `Packages/OneToOneKit/Sources/Core/Pair/AnniversaryCalculator.swift`
- Modify: `Packages/OneToOneKit/Sources/Core/Pair/BirthdayCalculator.swift` — убрать приватные `birthday(of:in:)` и `isLeap`, использовать `occurrence(in:)`.
- Test: `Packages/OneToOneKit/Tests/CoreTests/DayKeyTests.swift`, `Packages/OneToOneKit/Tests/CoreTests/Pair/AnniversaryCalculatorTests.swift`

**Interfaces:**
- Produces: `extension DayKey { public func occurrence(in year: Int) -> DayKey }` — тот же месяц и число в году `year`; 29 февраля в невисокосный год → 1 марта.
- Produces: `public struct UpcomingAnniversary: Equatable, Sendable { public let years: Int; public let daysLeft: Int }` (public init).
- Produces: `public enum AnniversaryCalculator { public static func upcoming(since: DayKey?, today: DayKey, within: Int = 30) -> UpcomingAnniversary? }`

- [ ] **Step 1: тесты.** `today = 2026-10-10`.
  - `occurrenceKeepsDay`: `DayKey(2000,10,22).occurrence(in: 2026) == DayKey(2026,10,22)`; `DayKey(1996,2,29).occurrence(in: 2027) == DayKey(2027,3,1)`, `in: 2028 == DayKey(2028,2,29)`.
  - `noDateIsNil`: `since: nil` → `nil`.
  - `anniversaryIn12Days`: `since 2023-10-22` → `UpcomingAnniversary(years: 3, daysLeft: 12)`.
  - `anniversaryTomorrow`: `since 2023-10-11` → `daysLeft 1`.
  - `anniversaryTodayIsZero`: `since 2023-10-10` → `(years: 3, daysLeft: 0)`; и `since 2020-12-31`, `today 2026-12-31` → `(6, 0)`.
  - `anniversaryYesterdayIsHidden`: `since 2023-10-09` → `nil`.
  - `beyondWindowIsHidden`: `since 2023-11-10` → `nil`; `since 2023-11-09` → `daysLeft 30`.
  - `anniversaryAcrossNewYear`: `since 2020-01-05`, `today 2026-12-20` → `(years: 7, daysLeft: 16)`.
  - `leapDayAnniversaryInCommonYear`: `since 2024-02-29`; `today 2027-02-20` → `(3, 9)`; `today 2028-02-20` → `(4, 9)`.
  - `anniversaryNotInFirstYear`: `since 2026-09-01` → `nil`; `since 2025-10-20` → `(1, 10)`.
  - `anniversarySameDayAsStartIsHidden`: `since 2026-10-10` → `nil`.
- [ ] **Step 2:** `swift test --filter "Anniversary|occurrence"` — FAIL (нет типов).
- [ ] **Step 3: реализовать.** Следующая годовщина = `since.occurrence(in: today.year)`, если она `>= today`, иначе в `today.year + 1`; `years = год годовщины - since.year`; `years < 1` или `daysLeft > within` → `nil`. `BirthdayCalculator.nextBirthday` перевести на `occurrence(in:)`.
- [ ] **Step 4:** `cd Packages/OneToOneKit && swift test` — всё зелёное, включая старые тесты дней рождения.
- [ ] **Step 5:** коммит «Добавить расчёт годовщины пары».

### Задача 2: дата пары в данных и список ближайших событий (Core)

**Files:**
- Modify: `Packages/OneToOneKit/Sources/Core/Storage/AppData.swift` — поле и `decodeIfPresent`.
- Create: `Packages/OneToOneKit/Sources/Core/Pair/UpcomingEvents.swift`
- Test: `Packages/OneToOneKit/Tests/CoreTests/Storage/StoreTests.swift`, `Packages/OneToOneKit/Tests/CoreTests/Pair/UpcomingEventsTests.swift`
- Modify: `docs/plan.md` — «Карта модулей»: в `// Pair` добавить `UpcomingAnniversary`, `AnniversaryCalculator`, `UpcomingEvent`, `UpcomingEvents`; у `DayKey` — `occurrence(in:)`; у `AppData` — `var togetherSince: DayKey?`.
- Modify: `docs/decisions.md` — строка о решениях (экран «Пара» по шестерёнке, обе плашки, дата в `AppData`).

**Interfaces:**
- Consumes: задача 1.
- Produces: `AppData.togetherSince: DayKey?` — «вместе с», `nil` по умолчанию.
- Produces: `public enum UpcomingEvent: Equatable, Sendable { case birthday(UpcomingBirthday); case anniversary(UpcomingAnniversary); public var daysLeft: Int }`
- Produces: `public enum UpcomingEvents { public static func list(_ data: AppData, today: DayKey) -> [UpcomingEvent] }` — день рождения (через `BirthdayCalculator`, если есть пара) и годовщина, по `daysLeft`; при равенстве день рождения первым.

- [ ] **Step 1: тесты.**
  - `appDataDecodesFileWithoutTogetherSince`: `{"watched": [326]}` → `togetherSince == nil`.
  - `appDataKeepsTogetherSince`: кодировать и раскодировать `AppData` с `togetherSince = 2023-10-22` → равны.
  - `emptyDataHasNoEvents`: `AppData()` → `[]`.
  - `anniversaryWithoutCouple`: только `togetherSince` → `[.anniversary(UpcomingAnniversary(years: 3, daysLeft: 12))]`.
  - `nearestFirst`: её ДР через 20 дней, годовщина через 5 → `[.anniversary(...5), .birthday(...20)]`.
  - `birthdayFirstOnSameDay`: оба через 5 дней → первым `.birthday`.
- [ ] **Step 2:** `swift test --filter "UpcomingEvents|TogetherSince"` — FAIL.
- [ ] **Step 3: реализовать** поле, `decodeIfPresent(DayKey.self, forKey: .togetherSince)`, `UpcomingEvents.list`: сортировать по паре `(daysLeft, вид)`, где день рождения 0, годовщина 1 (`sorted` в Swift не обещает сохранить порядок равных).
- [ ] **Step 4:** `swift test` — всё зелёное.
- [ ] **Step 5:** правки `docs/plan.md`, `docs/decisions.md`; коммит «Хранить дату пары и собирать ближайшие события».

### Задача 3: тексты плашек и сохранение даты (приложение)

**Files:**
- Create: `App/OneToOne/Features/Home/UpcomingEvent+Text.swift` (тексты годовщины и общий `text` события; `UpcomingBirthday+Text.swift` не меняется)
- Create: `App/OneToOne/AppModel+Pair.swift`
- Test: `App/OneToOneTests/UpcomingEventTextTests.swift`, `App/OneToOneTests/AppModelPairTests.swift`

**Interfaces:**
- Produces: `extension UpcomingAnniversary { var text: String }`, `extension UpcomingEvent { var text: String }`.
- Produces: `extension AppModel { func setTogetherSince(_ day: DayKey?) }` — меняет `data.togetherSince` через `update`.

- [ ] **Step 1: тесты.**
  - `anniversaryTexts`: `(3, 12)` → «💞 Годовщина через 12 дней»; `(3, 1)` → «💞 Годовщина завтра»; `(3, 0)` → «💞 3 года вместе! С годовщиной!»; `(1, 0)` → «💞 1 год вместе! С годовщиной!»; `(5, 0)` → «💞 5 лет вместе! С годовщиной!».
  - `eventTextDelegates`: `.birthday(b).text == b.text`, `.anniversary(a).text == a.text`.
  - `setTogetherSinceSaves`: после `setTogetherSince(2023-10-22)` в `store.load()` дата есть; после `setTogetherSince(nil)` — `nil`.
- [ ] **Step 2:** собрать тесты — FAIL (нет `text`, нет `setTogetherSince`).
- [ ] **Step 3: реализовать.** Склонение лет: `год/года/лет` по тем же правилам, что `daysText` (11–14 → «лет»). Вынести в Core как `public func yearsText(_ count: Int) -> String` в `DaysText.swift` с тестом `yearsPlural` (1 год, 2 года, 5 лет, 11 лет, 21 год) в `DaysTextTests.swift`, и добавить в «Карту модулей».
- [ ] **Step 4:** `xcodebuild test …` — зелёное.
- [ ] **Step 5:** коммит «Добавить тексты годовщины и сохранение даты пары».

### Задача 4: экран «Пара» и плашки на главной (приложение)

**Files:**
- Move+Modify: `App/OneToOne/Features/Onboarding/BirthDateRow.swift` → `App/OneToOne/Features/Shared/DateRow.swift`
- Modify: `App/OneToOne/Features/Onboarding/PersonFormView.swift` — `DateRow(title: "Дата рождения", date: $draft.birthDate, initial: DayKey(year: DayKey(.now).year - 25, month: 1, day: 1))`
- Create: `App/OneToOne/Features/Settings/PairSettingsView.swift`
- Modify: `App/OneToOne/Features/Home/HomeView.swift`, `App/OneToOne/Features/Home/AppData+HomePreview.swift`

**Interfaces:**
- Consumes: `UpcomingEvents.list`, `UpcomingEvent.text`, `AppModel.setTogetherSince`.
- Produces: `struct DateRow: View { let title: String; @Binding var date: DayKey?; let initial: DayKey }` — как `BirthDateRow`, подпись строки и колёсиков из `title`, при первом нажатии ставит `initial`, диапазон 1900…сегодня.
- Produces: `struct PairSettingsView: View` — `Form`, заголовок «Пара», строка `DateRow(title: "Вместе с", …, initial: сегодня)` с привязкой get `model.data.togetherSince` / set `model.setTogetherSince`; если дата есть — секция с кнопкой «Убрать дату» (`role: .destructive`).

- [ ] **Step 1:** `DateRow` вместо `BirthDateRow`, знакомство работает как раньше.
- [ ] **Step 2:** `PairSettingsView` + шестерёнка `gearshape` (`.topBarTrailing`, подпись для VoiceOver «Настройки пары») в тулбаре `HomeView` через `NavigationLink`; «Витрина» в `.topBarLeading`.
- [ ] **Step 3:** на главной вместо одной плашки `ForEach` по `UpcomingEvents.list(model.data, today: today)` → `Card { Text(event.text).font(.headline) }`. В превью-данные добавить `togetherSince` с годовщиной через 20 дней (3 года).
- [ ] **Step 4:** `xcodegen generate && xcodebuild test …` на своём симуляторе — зелёное.
- [ ] **Step 5:** скриншоты главной (светлая и тёмная) и экрана «Пара» на своём симуляторе с тестовым `AppData.json` → `docs/screenshots/`.
- [ ] **Step 6:** коммит «Добавить экран пары и плашку годовщины на главной».
