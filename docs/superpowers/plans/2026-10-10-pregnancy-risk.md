# Риск беременности и защита в отметке секса — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** светофор риска беременности на день (плашка в «Трекере», полоски в календаре месячных у обоих), два необязательных вопроса о защите при «Классике» и карточка про экстренную таблетку после незащищённого раза.

**Architecture:** расчёт риска и правило карточки — чистые функции в `Core` с быстрыми тестами. `SexEntry` получает два необязательных поля, старый JSON читается без них. Экраны только показывают готовые значения.

**Tech Stack:** Swift 6, SwiftUI (iOS), Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-10-pregnancy-risk-design.md`

## Global Constraints
- Без новых зависимостей.
- Тексты интерфейса только на русском, дословно как в спецификации.
- Нигде нет слов «безопасный день», «можно без презерватива», «защиты не нужно». Низкий риск всегда «но не ноль».
- Зелёный не красит дни календаря: полоски только у высокого и среднего (в т. ч. задержки).
- Оба вопроса о защите необязательные; «Сохранить» доступна, как раньше (нужен только вид секса).
- В карточке после секса нет дозировок и названий препаратов.
- Логика: `cd Packages/OneToOneKit && swift test`. Приложение: `xcodegen generate && xcodebuild test -project OneToOne.xcodeproj -scheme OneToOne -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Коммиты на русском в повелительном наклонении, с `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus
1. Обновление приложения со старыми записями: JSON `SexEntry` без новых ключей читается, данные не теряются. Тест `decodesOldEntryWithoutProtection` в задаче 2.
2. Секс отмечен задним числом: карточка считает риск дня записи, а не сегодняшнего, и не появляется, если прошло больше 5 дней. Тесты `hintUsesEntryDay`, `noHintAfterFiveDays` в задаче 2.
3. Выбрали защиту, потом сняли «Классику»: поля стираются при сохранении. Тест `logSexWithoutVaginalDropsProtection` в задаче 2.
4. Месячные задерживаются: сегодня не «низкий», а задержка. Тест `lateWhenPastLongestCycle` в задаче 1.
5. Листаем календарь вперёд: будущие циклы идут по прогнозу, а не сплошной задержкой. Тест `futureDayFollowsForecast` в задаче 1.

---

### Задача 1: расчёт риска (Core)

**Files:**
- Create: `Packages/OneToOneKit/Sources/Core/Tracker/PregnancyRisk.swift`
- Test: `Packages/OneToOneKit/Tests/CoreTests/Tracker/PregnancyRiskTests.swift`
- Modify: `docs/decisions.md` — строка: «2026-10-10: Риск беременности считаем календарным методом (Огино–Кнаус), низкий только при ≥3 циклах с разбросом ≤10 дней, „безопасных“ дней не показываем. Причина: прогноз не знает настоящую овуляцию, обещать безопасность нечестно.»
- Modify: `docs/plan.md` — «Карта модулей», блок `Tracker`: `PregnancyRisk`, `PregnancyRiskCalculator`.

**Interfaces:**
- Consumes: `CycleCalculator.periodStarts(_:)`, `CycleCalculator.averageLength(_:)` (internal, тот же модуль).
- Produces: `public enum PregnancyRisk: Equatable, Sendable { case high, medium, late, low, unknown }` — `late` = средний риск с подписью о задержке.
- Produces: `public enum PregnancyRiskCalculator { public static func risk(on day: DayKey, periodDays: Set<DayKey>, today: DayKey) -> PregnancyRisk }`

- [ ] **Step 1: тесты**

Хелперы как в `CycleCalculatorTests` (`day(month, day)`). Регулярный набор: начала `day(6,12)`, `day(7,10)`, `day(8,7)`, `day(9,5)` (длины 28, 28, 29); `cycleDay(n) = day(9,5).adding(days: n - 1)`.

```swift
let regular: Set = [day(6, 12), day(7, 10), day(8, 7), day(9, 5)]

@Test func noMarksIsUnknown() {
    #expect(PregnancyRiskCalculator.risk(on: day(10, 3), periodDays: [], today: day(10, 3)) == .unknown)
}

@Test func regularCycleWindow() {  // окно 10–18, средний 8–9 и 19–20
    let risk = { PregnancyRiskCalculator.risk(on: cycleDay($0), periodDays: regular, today: day(10, 3)) }
    #expect(risk(1) == .low); #expect(risk(7) == .low)
    #expect(risk(8) == .medium); #expect(risk(9) == .medium)
    #expect(risk(10) == .high); #expect(risk(18) == .high)
    #expect(risk(19) == .medium); #expect(risk(20) == .medium)
    #expect(risk(21) == .low); #expect(risk(29) == .low)
}

@Test func fewCyclesHasNoLow() {  // одно начало: окно 8–19, остальное средний
    let marks: Set = [day(9, 5)]
    let risk = { PregnancyRiskCalculator.risk(on: cycleDay($0), periodDays: marks, today: day(10, 3)) }
    #expect(risk(1) == .medium); #expect(risk(7) == .medium)
    #expect(risk(8) == .high); #expect(risk(19) == .high)
    #expect(risk(20) == .medium); #expect(risk(29) == .medium)
}

@Test func irregularCyclesHaveNoLow() {  // длины 22, 35, 28: разброс 13 > 10, окно 4–24
    let marks: Set = [day(6, 1), day(6, 23), day(7, 28), day(8, 25)]
    #expect(PregnancyRiskCalculator.risk(on: day(8, 25), periodDays: marks, today: day(9, 10)) == .medium)
    #expect(PregnancyRiskCalculator.risk(on: day(8, 28), periodDays: marks, today: day(9, 10)) == .high)
}

@Test func lateWhenPastLongestCycle() {  // 10 октября — 36-й день при длиннейшем 29
    #expect(PregnancyRiskCalculator.risk(on: day(10, 10), periodDays: regular, today: day(10, 10)) == .late)
    #expect(PregnancyRiskCalculator.risk(on: day(10, 4), periodDays: regular, today: day(10, 10)) == .late)
}

@Test func futureDayFollowsForecast() {  // средняя длина 28: 4 окт. — 2-й день, 13 окт. — 11-й
    #expect(PregnancyRiskCalculator.risk(on: day(10, 4), periodDays: regular, today: day(10, 3)) == .low)
    #expect(PregnancyRiskCalculator.risk(on: day(10, 13), periodDays: regular, today: day(10, 3)) == .high)
}

@Test func ignoresMarksAfterDay() {
    // Начало 1 окт. дало бы длину 26 и окно с 8-го дня; 12 сент. (8-й день) судим по тому, что знали тогда.
    #expect(PregnancyRiskCalculator.risk(on: day(9, 12), periodDays: regular.union([day(10, 1)]), today: day(10, 3)) == .medium)
    // Отметка в будущем не меняет прогноз.
    #expect(PregnancyRiskCalculator.risk(on: day(10, 13), periodDays: regular.union([day(10, 20)]), today: day(10, 3)) == .high)
}

@Test func skipsCyclesLongerThan40() {  // 1 апр. → 20 мая = 49 дней, не считаем; остаются 28, 28, 28
    let marks: Set = [day(4, 1), day(5, 20), day(6, 17), day(7, 15), day(8, 12)]
    #expect(PregnancyRiskCalculator.risk(on: day(8, 12), periodDays: marks, today: day(8, 20)) == .low)
}
```

- [ ] **Step 2: `swift test --filter PregnancyRisk` — падает, типа нет**

- [ ] **Step 3: реализовать `risk(on:periodDays:today:)`** по спецификации, раздел «Расчёт риска»:
  - отметки `<= min(day, today)` → `periodStarts`; нет начал → `.unknown`;
  - длины — промежутки соседних начал в 21…40, последние 6;
  - ≥3 длин: окно `(min − 18)...(max − 11)`, низкий разрешён при `max − min <= 10`, задержка после `max`; иначе окно `8...19`, низкого нет, задержка после 32;
  - день цикла: `day <= today` — `lastStart.days(to: day) + 1` без заворота, и если больше порога задержки → `.late`; `day > today` — `lastStart.days(to: day) % averageLength(starts) + 1`, без проверки задержки;
  - в окне → `.high`; за 2 дня до окна или 2 дня после → `.medium`; иначе `.low` или `.medium`, если низкий запрещён.

- [ ] **Step 4: `swift test` — всё зелёное**

- [ ] **Step 5: коммит** «Добавить расчёт риска беременности по циклу»

---

### Задача 2: защита в записи секса и правило карточки (Core + AppModel)

**Files:**
- Modify: `Packages/OneToOneKit/Sources/Core/Tracker/SexEntry.swift`
- Create: `Packages/OneToOneKit/Sources/Core/Tracker/EmergencyHint.swift`
- Test: `Packages/OneToOneKit/Tests/CoreTests/Tracker/SexEntryProtectionTests.swift`, `Packages/OneToOneKit/Tests/CoreTests/Tracker/EmergencyHintTests.swift`
- Modify: `App/OneToOne/AppModel+Tracker.swift`, `App/OneToOneTests/AppModelTrackerTests.swift`

**Interfaces:**
- Consumes: `PregnancyRiskCalculator.risk(on:periodDays:today:)` (задача 1).
- Produces: `public enum SexFinish: String, Codable, CaseIterable, Sendable { case inside, outside, didNotFinish }` (не `none`: путается с `nil`).
- Produces: в `SexEntry` — `public var condom: Bool?`, `public var finish: SexFinish?`; в `init` параметры `condom: Bool? = nil, finish: SexFinish? = nil` после `orgasmsWoman`.
- Produces: `public enum EmergencyHint: Equatable, Sendable { case strong, soft; public static func hint(types: Set<SexType>, condom: Bool?, finish: SexFinish?, day: DayKey, periodDays: Set<DayKey>, today: DayKey) -> EmergencyHint? }`
- Produces: `AppModel.logSex(types:orgasmsMan:orgasmsWoman:condom:finish:day:)` — `condom`, `finish` с `= nil`; без `.vaginal` в `types` и `logSex`, и `updateSex` сохраняют оба поля как `nil`.

- [ ] **Step 1: тесты**

```swift
@Test func decodesOldEntryWithoutProtection() throws {
    let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","day":{"year":2026,"month":10,"day":9},"types":["vaginal"],"orgasmsMan":1,"orgasmsWoman":1,"createdBy":"6F9619FF-8B86-D011-B42D-00C04FC964FF"}"#
    let entry = try JSONDecoder().decode(SexEntry.self, from: Data(json.utf8))
    #expect(entry.condom == nil); #expect(entry.finish == nil)
}
```
(`DayKey` кодируется синтезированным `Codable` как `{year, month, day}`.)

`EmergencyHintTests` на регулярном наборе из задачи 1 (`today = day(9, 16)`, 12-й день, высокий):
- `strongWhenInsideWithoutCondom`: `[.vaginal]`, `condom: false`, `finish: .inside`, `day: today` → `.strong`;
- `softWhenOutsideOrUnknown`: `finish: .outside` → `.soft`; `.didNotFinish` → `.soft`; `nil` → `.soft`;
- `noHintWithCondomOrUnknownCondom`: `condom: true` → `nil`; `condom: nil` → `nil`;
- `noHintWithoutVaginal`: `[.blowjob]`, `condom: false`, `.inside` → `nil`;
- `noHintOnLowDay`: `day: day(9, 27)` (23-й день, низкий), `today: day(9, 28)` → `nil`;
- `hintOnLateOrUnknownDay`: `periodDays: []` → `.strong`; регулярный, `day = today = day(10, 10)` (задержка) → `.strong`;
- `hintUsesEntryDay`: `day: day(9, 11)` (7-й, низкий), `today: day(9, 14)` (10-й, высокий) → `nil`; `day: day(9, 20)` (16-й, высокий), `today: day(9, 25)` (21-й, низкий) → `.strong`;
- `noHintAfterFiveDays`: `day: day(9, 14)`, `today: day(9, 19)` → `.strong`; `today: day(9, 20)` → `nil`.

`AppModelTrackerTests`:
- `logSexSavesProtection`: `logSex(types: [.vaginal], …, condom: false, finish: .inside, day:)` → в сторе `condom == false`, `finish == .inside`;
- `logSexWithoutVaginalDropsProtection`: `types: [.blowjob]`, `condom: false`, `finish: .inside` → оба `nil`; то же для `updateSex` записи с `types = [.anal]`.

- [ ] **Step 2: `swift test` и тесты приложения — падают**

- [ ] **Step 3: реализовать.** Синтезированный `Codable` сам читает отсутствующие `Optional` как `nil`, свой `init(from:)` не нужен. `hint`: `nil`, если нет `.vaginal`, `condom != false`, `day.days(to: today)` не в `0...5`, или риск дня `.low`; иначе `.strong` при `finish == .inside`, `.soft` в остальных случаях.

- [ ] **Step 4: `swift test` и `xcodebuild test` — зелёные**

- [ ] **Step 5: коммит** «Добавить защиту в запись секса и правило подсказки про экстренную таблетку»

---

### Задача 3: светофор в «Трекере» и в календарях

**Files:**
- Create: `App/OneToOne/Features/Cycle/PregnancyRisk+Text.swift` — заголовок, строка, цвет точки, цвет полоски, подпись для доступности.
- Create: `App/OneToOne/Features/Tracker/RiskCard.swift` — плашка «Сегодня».
- Create: `App/OneToOne/Features/Cycle/RiskLegend.swift`
- Modify: `App/OneToOne/Features/Tracker/TrackerView.swift` — `RiskCard` первой секцией, над `StatsView`, от `today`.
- Modify: `App/OneToOne/Features/Cycle/MonthGridView.swift` — `var risks: [DayKey: PregnancyRisk] = [:]`, полоска в `DayCell`, слова в `accessibilityText`.
- Modify: `App/OneToOne/Features/Cycle/HerCalendarView.swift`, `HisCalendarView.swift` — передать `risks` для дней месяца, `RiskLegend` под сеткой; у неё в блоке выбранного дня строка «Риск беременности: высокий».

**Interfaces:**
- Consumes: `PregnancyRiskCalculator.risk(on:periodDays:today:)`, `PregnancyRisk` (задача 1).
- Produces: `extension PregnancyRisk { var title: String; var detail: String; var dotColor: Color; var markColor: Color?; var shortTitle: String }` — `markColor` `nil` у `.low` и `.unknown`.

- [ ] **Step 1: тексты** (`title` → `detail`), дословно из спецификации:
  - `.high`: «Высокий риск забеременеть» → «Близко к овуляции: за один раз без защиты шанс до 1 из 3. Надевай презерватив»
  - `.medium`: «Средний риск» → «Прогноз тут не уверен. Лучше с презервативом»
  - `.late`: «Средний риск» → «Месячные задерживаются, прогноз ненадёжен. Лучше с презервативом»
  - `.low`: «Низкий риск, но не ноль» → «Если прогноз верный, шанс небольшой. Но овуляция может сдвинуться»
  - `.unknown`: «Риск неизвестен» → «Отметьте месячные во вкладке „Цикл“. Пока лучше с презервативом»
  - под строкой в `RiskCard` всегда, мелко: «Календарь не защищает на 100%. От инфекций защищает только презерватив.»
  - `shortTitle` для календаря и доступности: «высокий», «средний», «средний, задержка», «низкий», «неизвестен»; в `accessibilityText` дня — «высокий риск беременности» / «средний риск беременности» только при `markColor != nil`.
  - легенда: «▬ высокий риск ▬ средний риск» цветами полосок.
  - цвета: высокий — красный, средний и задержка — янтарный, низкий — зелёный (только точка плашки), неизвестно — серый. Проверить контраст в светлой и тёмной теме.

- [ ] **Step 2: `RiskCard`, полоска в `DayCell`** (короткая капсула под числом рядом с точкой симптомов; заливку фазы не трогать), легенда, строка у неё. Превью `RiskCard` во всех пяти состояниях.

- [ ] **Step 3: сборка и тесты приложения** — `xcodebuild test …` зелёный. Запустить в симуляторе, проверить: плашка в «Трекере», полоски у неё и у него, светлая и тёмная тема. Скриншоты в PR.

- [ ] **Step 4: коммит** «Показать риск беременности в трекере и календаре»

---

### Задача 4: вопросы о защите в отметке секса и карточка после сохранения

**Files:**
- Create: `App/OneToOne/Features/Tracker/ProtectionPicker.swift` — два ряда чипов.
- Create: `App/OneToOne/Features/Tracker/SexFinish+Title.swift`, `App/OneToOne/Features/Tracker/SexEntry+Protection.swift`
- Create: `App/OneToOne/Features/Tracker/EmergencyHintView.swift`
- Modify: `App/OneToOne/Features/Tracker/LogSexView.swift`, `App/OneToOne/Features/Tracker/TrackerView.swift` (`EntryRow`)
- Test: `App/OneToOneTests/SexEntryProtectionTextTests.swift`

**Interfaces:**
- Consumes: `SexFinish`, `SexEntry.condom/finish`, `EmergencyHint.hint(...)`, `AppModel.logSex(…condom:finish:day:)` (задача 2).
- Produces: `extension SexFinish { var title: String }` — «Внутрь», «Не внутрь», «Не кончил».
- Produces: `extension SexEntry { var protectionText: String? }`.

- [ ] **Step 1: тест `protectionText`** — части через « · »: «С презервативом»/«Без презерватива», затем «внутрь»/«не внутрь»/«не кончил»; обе `nil` → `nil`.
  - `condom: false, finish: .inside` → «Без презерватива · внутрь»; `condom: true, finish: nil` → «С презервативом»; `condom: nil, finish: .outside` → «Не внутрь».

- [ ] **Step 2: тест падает → реализовать → зелёный**

- [ ] **Step 3: `ProtectionPicker`** в `LogSexView` сразу под видами, только при `types.contains(.vaginal)`, внутри `Card`: подписи «Презерватив» (чипы «Был» / «Не было») и «Кончил» (три чипа `SexFinish`). `ChipButton(compact: true, surface: Palette.background)`; повторное нажатие снимает выбор. При правке записи поля берутся из `entry`. Сохранение передаёт `condom`/`finish` в `logSex`/`updateSex` (очистку без «Классики» делает модель).

- [ ] **Step 4: карточка после сохранения.** `save()` после записи считает `EmergencyHint.hint(…, periodDays: model.data.periodDays, today: DayKey(.now))`; `nil` → `dismiss()`, иначе шторка показывает `EmergencyHintView` с кнопкой «Понятно» (закрывает). Тексты дословно:
  - `.strong`: «Риск беременности выше обычного» → «Экстренная таблетка лучше всего работает в первые 72 часа, некоторые до 5 дней. Спроси в аптеке или у врача.»
  - `.soft`: «Риск небольшой, но есть» → «Сперматозоиды бывают в смазке до семяизвержения. Если волнуетесь, экстренная таблетка работает до 72 часов, некоторые до 5 дней.»

- [ ] **Step 5: `EntryRow`** — строка `protectionText` под видами, `.caption`, `.secondary`, если не `nil`.

- [ ] **Step 6: сборка и тесты приложения**, ручная проверка в симуляторе: «Классика» → появились вопросы; сняли → пропали; без презерватива внутрь в красный день → карточка; с презервативом → шторка закрылась. Скриншоты светлой и тёмной темы в PR.

- [ ] **Step 7: коммит** «Добавить вопросы о защите и подсказку про экстренную таблетку»
