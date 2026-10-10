# Вид для него и подсказка дня (#17) — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** у Максюши есть вкладка «Цикл»: подсказка дня и календарь, где каждый день закрашен цветом фазы.

**Architecture:** логика подсказки и фазы на день лежит в `Core` (пакет `OneToOneKit`, тесты `swift test`). Экраны в `App/OneToOne/Features/Cycle/` переиспользуют `MonthGridView` из #16.

**Tech Stack:** Swift 6, SwiftUI, iOS 26, Swift Testing.

**Spec:** «Задача 9» в `docs/plan.md` и описание, согласованное в чате 2026-10-10 (ниже, в «Решениях»).

## Решения из обсуждения
- Каждый день в его календаре закрашен мягким цветом фазы: месячные `BrandColor.pink`, фолликулярная `.orange`, овуляция `.purple`, лютеиновая `.blue`. Дни, которые она отметила как месячные, залиты ярким кружком (`BrandGradient.primary`), как у неё. Будущие дни закрашены по прогнозу. Под сеткой легенда.
- Ссылки «Что видит он» у неё **нет** (отказ пользователя: и так всё обсуждаем). Записать в `docs/decisions.md`, убрать из `docs/plan.md` и критериев issue #17.
- У него: без её настроения по дням, без симптомов, дни не нажимаются (решение Claude).
- Подсказка по фазе `unknown` без «как я сегодня» — `isEstimate = false`, это не прогноз (решение Claude).

## Global Constraints
- Имена из «Карты модулей»: `struct Tip: Equatable { let text: String; let isEstimate: Bool }`, `enum TipProvider { static func tip(forecast: CycleForecast, herMood: HerMood?) -> Tip }`.
- Цвета только из `DesignSystem`. Интерфейс на русском. Даты через `DayKey`.

## Review Focus
1. Одни месячные без истории (одна отметка) — фаза и подсказка по 28 дням, без падений: покрыто `CycleCalculatorTests`, плюс `phaseOnFutureDay`.
2. Дни до первой отметки в календаре — без цвета (`unknown`): тест `phaseBeforeFirstMarkIsUnknown`.
3. Она отметила «как я сегодня», но месячных нет — подсказка по настроению: тест `herMoodOverridesUnknown`.
4. Полночь и возврат в приложение — «сегодня» пересчитывается, как в `HerCalendarView`.
5. Тёмная тема — мягкие цвета фаз читаются, цифры видны: проверить на скриншоте.

---

### Task 1: Подсказка дня

**Files:**
- Create: `Packages/OneToOneKit/Sources/Core/Tracker/TipProvider.swift` (`Tip` и `TipProvider`)
- Test: `Packages/OneToOneKit/Tests/CoreTests/Tracker/TipProviderTests.swift`

**Interfaces:**
- Consumes: `CycleForecast`, `CyclePhase`, `HerMood` (уже в `Core`).
- Produces: `public struct Tip: Equatable, Sendable { public let text: String; public let isEstimate: Bool }`, `public enum TipProvider { public static func tip(forecast: CycleForecast, herMood: HerMood?) -> Tip }`.

- [ ] **Step 1: тесты** (`forecast(_ phase:, day:)` — помощник, собирает `CycleForecast(phase:dayOfCycle:averageLength: 28, nextPeriodStart:)`)
  - `herMoodOverridesPhase`: при `.ovulation` и `herMood: .leaveMeAlone` → `Tip(text: "Сегодня лучше не подходить. Серьёзно.", isEstimate: false)`; `.wants` → «Она сама сказала, что хочет 😏»; `.neutral` → «Обычный день. Действуй по обстановке».
  - `herMoodOverridesUnknown`: `.unknown` + `.wants` → «Она сама сказала, что хочет 😏», `isEstimate == false`.
  - `estimateFlagForPhase`: для каждой из четырёх фаз без настроения `isEstimate == true` и текст не пустой.
  - `unknownPhaseText`: `.unknown`, `dayOfCycle: nil` → `Tip(text: "Пусть она отметит цикл, и тут появятся подсказки", isEstimate: false)`.
  - `sameDaySameText`: два вызова с одинаковым прогнозом дают одинаковый `Tip`; дни 1, 2, 3 одной фазы дают три разных текста.
- [ ] **Step 2:** `cd Packages/OneToOneKit && swift test --filter TipProviderTests` — FAIL (нет `TipProvider`).
- [ ] **Step 3: реализация.** Настроение главнее фазы. По фазе — массив из 3 текстов, индекс `dayOfCycle % 3`. Тексты:
  - месячные: «Месячные. Чай, плед и шоколадка — твой выход.» / «Сейчас не до подвигов. Обнимашки — да.» / «Тяжёлые дни. Будь мягким, как плед.»
  - фолликулярная: «Энергии всё больше. Самое время позвать её на свидание.» / «Хорошие дни: она бодрая и весёлая. Не упусти.» / «Настроение на подъёме. Предложи что-нибудь новенькое.»
  - овуляция: «Скорее всего, она хочет. Действуй 😏» / «Пик формы. Комплимент сработает вдвойне.» / «Самые жаркие дни цикла. Не теряйся 🔥»
  - лютеиновая: «Терпение и вкусняшки. Она может быть чуть на взводе.» / «Скоро месячные. Меньше споров, больше заботы.» / «Время сюрпризов: цветы или её любимая еда.»
- [ ] **Step 4:** `swift test` — всё зелёное.
- [ ] **Step 5:** коммит «Добавить подсказку дня для него».

### Task 2: Фаза на любой день

**Files:**
- Modify: `Packages/OneToOneKit/Sources/Core/Tracker/CycleCalculator.swift`
- Test: `Packages/OneToOneKit/Tests/CoreTests/Tracker/CycleCalculatorTests.swift`

**Interfaces:**
- Produces: `CycleCalculator.phase(on day: DayKey, periodDays: Set<DayKey>) -> CyclePhase` (public). Если после дня уже были следующие месячные и цикл 21–40 дней — по настоящей длине цикла; иначе `forecast(periodDays:today: day).phase`. Тесты ещё `pastDayUsesActualNextStart`, `pastDayWithMissedPeriodFallsBackToForecast` (добавлены после ревью).

- [ ] **Step 1: тесты**
  - `phaseBeforeFirstMarkIsUnknown`: отметки 1–4 октября, `phase(on: 30 сентября)` → `.unknown`.
  - `phaseOnFutureDay`: отметки 1–4 октября; 2 октября → `.menstruation`; 10 октября → `.follicular`; 14 октября → `.ovulation` (день 14 из 28: окно 12…16); 20 октября → `.luteal`; 29 октября → `.menstruation` (прогноз нового цикла).
- [ ] **Step 2:** `swift test --filter CycleCalculatorTests` — FAIL.
- [ ] **Step 3:** реализовать одной строкой через `forecast`.
- [ ] **Step 4:** `swift test` — зелёное.
- [ ] **Step 5:** коммит «Считать фазу цикла на любой день».

### Task 3: Экран «Цикл» для него

**Files:**
- Create: `App/OneToOne/Features/Cycle/HisCalendarView.swift`, `App/OneToOne/Features/Cycle/TipCard.swift`
- Modify: `App/OneToOne/Features/Cycle/MonthGridView.swift`, `App/OneToOne/Features/Cycle/HerCalendarView.swift` (вызов сетки), `App/OneToOne/Features/Cycle/Cycle+Titles.swift` (цвет и короткое название фазы), `App/OneToOne/OneToOneApp.swift`
- Docs: `docs/decisions.md`, `docs/plan.md` (задача 9), issue #17

**Interfaces:**
- Consumes: `TipProvider.tip(forecast:herMood:)`, `CycleCalculator.phase(on:periodDays:)`.
- `MonthGridView`: выбор дня становится необязательным (`selected: Binding<DayKey>?`, `nil` — дни не нажимаются), новый параметр `phases: [DayKey: CyclePhase] = [:]` — мягкая заливка клетки цветом фазы (прозрачность ~0.25). У неё поведение не меняется.
- `CyclePhase.color: Color?` (nil для `unknown`) и `CyclePhase.shortTitle` («Месячные», «Фолликулярная», «Овуляция», «Лютеиновая») для легенды.

- [ ] **Step 1:** `TipCard(tip: Tip)` — карточка `Card`, заголовок «Подсказка дня», текст; если `isEstimate`, ниже подпись «Это прогноз по циклу» (secondary).
- [ ] **Step 2:** `HisCalendarView` — `NavigationStack`, заголовок «Цикл»; `TipCard` с подсказкой на сегодня (`herMoods[today]`), `MonthGridView` без выбора с `phases` для дней месяца, легенда из четырёх фаз. Пересчёт «сегодня» в полночь и при возврате в приложение, как в `HerCalendarView`. Превью с отметками.
- [ ] **Step 3:** в `OneToOneApp` вкладка «Цикл» у обоих: у неё `HerCalendarView`, у него `HisCalendarView`.
- [ ] **Step 4:** документы: строка в `decisions.md` про отказ от «Что видит он»; в `docs/plan.md` задача 9 без ссылки; в issue #17 критерий заменить.
- [ ] **Step 5:** `xcodegen generate && xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17'` — зелёное; скриншоты его вкладки в светлой и тёмной теме.
- [ ] **Step 6:** коммит «Добавить вкладку цикла для него».
