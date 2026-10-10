# Главный экран (#18) — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** главная по наброску B: счётчик за месяц, оргазмы, серия, две плитки «Отметить секс» / «Выбрать фильм», подсказка дня (он) или фаза с подбадриванием (она), плашка ближайшего дня рождения.

**Architecture:** чистая логика (склонение «дней», ближайший день рождения, фраза для неё) — в пакете `Core` с быстрыми тестами. Экран собирается из готовых `StatsCalculator`, `TipProvider`, `TipCard`, `LogSexView`, `StatTile`, `Card`. Переход на «Фильмы» — через выбранную вкладку в `OneToOneApp`.

**Tech Stack:** Swift 6, SwiftUI (iOS), Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-10-home-screen-design.md`

## Global Constraints
- Без новых зависимостей.
- Тексты интерфейса только на русском; копирайт — как в спецификации, дословно.
- Имена не склоняем: «🎂 Даша: День рождения через 12 дней» (заглавная «День» после двоеточия — решение пользователя).
- Цифры главной — из `StatsCalculator.stats(_:today:)`, подсказка — из `TipProvider.tip(forecast:herMood:)`, без своих подсчётов.
- «Сегодня» пересчитывается через `onDayChange` (`Features/Cycle/DayChange.swift`).
- Логика: `cd Packages/OneToOneKit && swift test`. Приложение: `xcodegen generate && xcodebuild test -project OneToOne.xcodeproj -scheme OneToOne -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Коммиты на русском в повелительном наклонении, с `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus
1. День рождения через Новый год (сегодня 20 декабря, родился 5 января → 16 дней). Тест `birthdayAcrossNewYear` в задаче 1.
2. Родился 29 февраля, год невисокосный → празднуем 1 марта. Тест `leapDayBirthdayInCommonYear` в задаче 1.
3. День рождения вчера → следующий через год, плашки нет; сегодня → 0 дней, плашка есть. Тесты `birthdayTodayIsZero`, `birthdayYesterdayIsHidden` в задаче 1.
4. 11–14 → «дней», 21 → «день», 22 → «дня». Тест `daysPlural` в задаче 1.
5. Полночь при открытой главной: месяц, серия, подсказка и плашка меняются без перезапуска. Проверка руками в задаче 3 (сменить дату симулятора нельзя — достаточно, что все значения считаются от `@State today`, который обновляет `onDayChange`).

---

### Задача 1: склонение дней и ближайший день рождения (Core)

**Files:**
- Create: `Packages/OneToOneKit/Sources/Core/DaysText.swift`
- Create: `Packages/OneToOneKit/Sources/Core/Pair/BirthdayCalculator.swift`
- Test: `Packages/OneToOneKit/Tests/CoreTests/DaysTextTests.swift`, `Packages/OneToOneKit/Tests/CoreTests/Pair/BirthdayCalculatorTests.swift`
- Modify: `docs/plan.md` — «Карта модулей», блок `// Pair`: добавить `UpcomingBirthday`, `BirthdayCalculator`; в общий блок `daysText`.

**Interfaces:**
- Produces: `public func daysText(_ count: Int) -> String` — «1 день», «2 дня», «5 дней».
- Produces: `public struct UpcomingBirthday: Equatable, Sendable { public let person: Person; public let isMe: Bool; public let daysLeft: Int }`
- Produces: `public enum BirthdayCalculator { public static func upcoming(couple: Couple, meID: UUID?, today: DayKey, within: Int = 30) -> UpcomingBirthday? }`

- [ ] **Step 1: тесты**

```swift
@Test func daysPlural() {
    #expect(daysText(0) == "0 дней")
    #expect(daysText(1) == "1 день")
    #expect(daysText(2) == "2 дня")
    #expect(daysText(5) == "5 дней")
    #expect(daysText(11) == "11 дней")
    #expect(daysText(14) == "14 дней")
    #expect(daysText(21) == "21 день")
    #expect(daysText(22) == "22 дня")
    #expect(daysText(25) == "25 дней")
}
```

В `BirthdayCalculatorTests` пара `man` (Максюша) и `woman` (Даша) через `Couple.make`, `meID` = id мужчины, `today = DayKey(year: 2026, month: 10, day: 10)`:
- `noBirthDatesIsNil`: оба без `birthDate` → `nil`.
- `partnerBirthdayIn12Days`: у неё 22.10.1995 → `UpcomingBirthday(person: woman, isMe: false, daysLeft: 12)`.
- `myBirthdayIsMe`: у него 11.10.1990 → `isMe == true`, `daysLeft == 1`.
- `birthdayTodayIsZero`: у неё 10.10.1995 → `daysLeft == 0`.
- `birthdayYesterdayIsHidden`: у неё 09.10.1995 → `nil`.
- `beyondWindowIsHidden`: у неё 10.11.1995 (31 день) → `nil`; 09.11.1995 (30 дней) → `daysLeft == 30`.
- `nearestOfTwoWins`: у него 20.10, у неё 15.10 → она, 5 дней.
- `tieGoesToPartner`: у обоих 15.10 → она (`isMe == false`).
- `birthdayAcrossNewYear`: today 20.12.2026, у неё 05.01.1995 → 16 дней.
- `leapDayBirthdayInCommonYear`: today 20.02.2027, у неё 29.02.1996 → празднуем 01.03.2027, 9 дней. Today 20.02.2028 → 29.02.2028, 9 дней.

- [ ] **Step 2: запустить, убедиться, что падают**

Run: `cd Packages/OneToOneKit && swift test --filter "DaysTextTests|BirthdayCalculatorTests"`
Expected: не собирается — `daysText`, `BirthdayCalculator` не найдены.

- [ ] **Step 3: реализовать**

`daysText`: по `n % 100` в 11...14 → «дней»; иначе по `n % 10`: 1 → «день», 2...4 → «дня», остальное → «дней».
`BirthdayCalculator.upcoming`: для каждого из `[couple.woman, couple.man]` (партнёр раньше при равенстве — порядок зависит от `meID`: сначала тот, кто не я) с `birthDate` найти следующий день рождения ≥ `today`: в году `today.year`, иначе в следующем; 29 февраля в невисокосный год → 1 марта. `daysLeft = today.days(to: дата)`. Взять минимальный `daysLeft` (при равенстве — первый, т. е. партнёр), вернуть, если `daysLeft <= within`.

- [ ] **Step 4: запустить, убедиться, что проходят**

Run: `cd Packages/OneToOneKit && swift test`
Expected: все тесты пакета зелёные.

- [ ] **Step 5: коммит**

`git commit -m "Добавить расчёт ближайшего дня рождения"`

---

### Задача 2: подбадривающая фраза для неё (Core)

**Files:**
- Create: `Packages/OneToOneKit/Sources/Core/Tracker/CheerProvider.swift`
- Test: `Packages/OneToOneKit/Tests/CoreTests/Tracker/CheerProviderTests.swift`
- Modify: `docs/plan.md` — «Карта модулей», блок `// Tracker`: `enum CheerProvider { static func cheer(forecast: CycleForecast) -> String? }`.

**Interfaces:**
- Consumes: `CycleForecast`, `CyclePhase` (Core).
- Produces: `public enum CheerProvider { public static func cheer(forecast: CycleForecast) -> String? }`

- [ ] **Step 1: тесты** (хелпер `forecast(_:day:)` как в `TipProviderTests`)
- `cheerForEachPhase(phase)` с `arguments: [.menstruation, .follicular, .ovulation, .luteal]`: фраза не пустая; дни 1, 2, 3 дают 3 разные фразы; два вызова с одним днём дают одну и ту же.
- `noCheerForUnknown`: `cheer(forecast: forecast(.unknown, day: nil)) == nil`.

- [ ] **Step 2: запустить** `swift test --filter CheerProviderTests` → не собирается.

- [ ] **Step 3: реализовать** так же, как `TipProvider`: `switch` по фазе, по 3 текста, `texts[dayOfCycle % texts.count]`; `nil` для `.unknown` или пустого `dayOfCycle`. Тексты тёплые, обращение к ней на «ты», без медицинских советов, например для овуляции «Ты сегодня огонь 🔥».

- [ ] **Step 4: запустить** `cd Packages/OneToOneKit && swift test` → зелёные.

- [ ] **Step 5: коммит** `"Добавить подбадривающие фразы по фазе цикла"`

---

### Задача 3: экран «Главная» и переход на «Фильмы» (App)

**Files:**
- Create: `App/OneToOne/Features/Home/UpcomingBirthday+Text.swift` — `var text: String`.
- Create: `App/OneToOne/Features/Home/ActionTile.swift` — плитка-кнопка (иконка + подпись, градиент, отклик на нажатие как `GradientButtonStyle`).
- Create: `App/OneToOne/Features/Home/DayCard.swift` — карточка дня: `TipCard` для него или «Сегодня» + фраза для неё.
- Modify: `App/OneToOne/Features/Home/HomeView.swift` — экран целиком.
- Modify: `App/OneToOne/OneToOneApp.swift` — `enum AppTab: Hashable { case home, movies, tracker, cycle }`, `@State private var tab: AppTab = .home`, `TabView(selection: $tab)`, `Tab(..., value: .home)` и т. д., `HomeView(pickMovie: { tab = .movies })`.
- Test: `App/OneToOneTests/UpcomingBirthdayTextTests.swift`
- Modify: `docs/decisions.md` — строка про «ближайшие планы».

**Interfaces:**
- Consumes: `daysText(_:)`, `UpcomingBirthday`, `BirthdayCalculator.upcoming(couple:meID:today:within:)` (задача 1); `CheerProvider.cheer(forecast:)` (задача 2); `StatsCalculator`, `CycleCalculator.forecast`, `TipProvider.tip`, `TipCard`, `CyclePhase.title`, `LogSexView(defaults:)`, `model.orgasmDefaults`, `onDayChange`.
- Produces: `HomeView(pickMovie: @escaping () -> Void)`.

- [ ] **Step 1: тест текстов** (`UpcomingBirthdayTextTests`, `Person(name: "Даша", sex: .female)`):
  - партнёр 12 → «🎂 Даша: День рождения через 12 дней»; 1 → «🎂 Даша: День рождения завтра»; 0 → «🎉 Даша: День рождения сегодня!»;
  - я 21 → «🎂 Твой день рождения через 21 день»; 1 → «🎂 Твой день рождения завтра»; 0 → «🎉 С днём рождения!».

- [ ] **Step 2: запустить** тесты приложения (команда из Global Constraints) → не собирается.

- [ ] **Step 3: реализовать `UpcomingBirthday.text`**, запустить тесты → зелёные. Коммит `"Добавить тексты плашки дня рождения"`.

- [ ] **Step 4: собрать экран.** `HomeView` держит `@State today = DayKey(.now)`, обновляет его в `onDayChange`. Сверху вниз в `ScrollView`, отступы 20, фон `Palette.background`, без `navigationTitle` (заголовок — сам экран):
  1. «Вы вдвоём · октябрь»: месяц `today.date().formatted(.dateTime.month(.wide).locale(locale))` (одно поле месяца в ru даёт именительный «октябрь»; проверить в превью, если вышло «октября» — взять `DateFormatter` с `"LLLL"`); `.subheadline`, `.secondary`.
  2. Цифра `stats.thisMonth` и «раз в этом месяце» — как в `StatsView` (96, `.heavy`, `BrandGradient.text`).
  3. `StatTile("Оргазмы", "Он \(m) · Она \(w)")` и `StatTile("Серия", серия > 0 ? "\(daysText(n)) 🔥" : daysText(0))` рядом.
  4. `ActionTile` ❤️ «Отметить секс» (`.sheet` с `LogSexView(defaults: model.orgasmDefaults)`) и 🎬 «Выбрать фильм» (`pickMovie()`) рядом, равной ширины.
  5. `DayCard`: если `model.data.meIsWoman` — `Card` с «Сегодня» (градиентная подпись как в `TipCard`), «Овуляция, 14-й день» — `phase.title` с первой буквой в верхнем регистре (`prefix(1).uppercased() + dropFirst()`), затем `", \(day)-й день"` и фраза `CheerProvider` ниже `.secondary`; при `.unknown` — «Отметь первый день месячных во вкладке „Цикл“». Иначе `TipCard(tip: TipProvider.tip(forecast:herMood: model.data.herMoods[today]))`.
  6. Если `BirthdayCalculator.upcoming(couple:meID:today:)` не `nil` — `Card { Text(birthday.text) }`.
  Превью: пара с данными для него и для неё, тёмная тема.
  Кнопка «Витрина» (DEBUG) остаётся в тулбаре — для этого `NavigationStack` с `.toolbar`.

- [ ] **Step 5: запустить тесты приложения** → зелёные; в симуляторе пройти: «Отметить секс» открывает шторку, после сохранения цифра растёт; «Выбрать фильм» открывает вкладку «Фильмы»; переключить `meID` на неё (превью) — видна фаза.

- [ ] **Step 6: decisions.md**: `- 2026-10-10: На главной нет «ближайших планов»: календарь пары не входит в v1, планы появятся вместе с ним. Годовщина — отдельной задачей позже.`

- [ ] **Step 7: скриншоты** светлой и тёмной темы с данными (симулятор, `xcrun simctl ui booted appearance light|dark`, `xcrun simctl io booted screenshot`), сохранить вне репозитория для PR. Данные: пройти знакомство в симуляторе, добавить 2–3 отметки и дату рождения партнёра в пределах 30 дней.

- [ ] **Step 8: коммит** `"Собрать главный экран"`.
