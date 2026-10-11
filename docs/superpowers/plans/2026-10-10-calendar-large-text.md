# Сетка календаря при крупном шрифте: план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Календарь месячных во вкладке «Цикл» (у неё и у него) читается и нажимается на любом размере шрифта, включая размеры Универсального доступа (#72).

**Architecture:** Колонки сетки не шире ~44–48 pt, поэтому сетку (дни недели и числа) ограничиваем размером `.xxxLarge`, а круг числа растёт вместе со шрифтом до этого предела. Шапка месяца и легенды растут без ограничений и перестраиваются, если не влезают. Новой логики нет, только вёрстка, поэтому в Core ничего не переносим.

**Tech Stack:** SwiftUI (`dynamicTypeSize`, `@ScaledMetric`).

**Spec:** issue #72 и вариант, согласованный в чате (брейншторм), записан ниже в «Global Constraints».

## Global Constraints

- Предел шрифта сетки: `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` только на `LazyVGrid` в `MonthGridView` (шапка и легенды без предела).
- Круг числа: `@ScaledMetric(relativeTo: .callout)` с базой 34, не больше 38 pt (`min(…, 38)`, с кольцом 44 pt = колонка iPhone SE). На обычном размере (`.large`) ровно 34, как сейчас.
- Точка симптомов (5×5), полоска риска (`RiskMark` 14×4), отступы ячейки и её `minHeight: 44` не меняются.
- Пунктир прогноза, обводка выбранного дня (`padding(-3)`) и заливка месячных привязаны к кругу и растут вместе с ним.
- На обычном размере шрифта вид не меняется.
- Решение записать одной строкой в `docs/decisions.md`.

## Review Focus

- iPhone SE (ширина 375): на `.xxxLarge` обводка выбранного дня (38 + 6 = 44 pt) не должна налезать на соседнее число (колонка ~44 pt плюс 4 pt промежутка).
- Размеры Универсального доступа AX1…AX5: сетка остаётся как на `.xxxLarge`, шапка месяца переносит длинное название («Сентябрь 2026») и не налезает на стрелки.
- `PhaseLegend` на AX-размерах: «Фолликулярная» не рвётся посреди слова.
- Тёмная тема: заливка фаз и цвета не меняются (вёрстку трогаем, цвета нет).
- Режим просмотра (у него, без `selected`): обведено «сегодня», нажатий нет, как раньше.

Автотестов на вёрстку в проекте нет (нет снапшот-тестов), поэтому проверка ручная: скриншоты в симуляторе через `xcrun simctl ui booted content_size …` и `appearance light/dark`.

---

### Task 1: Сетка и ячейка дня

**Files:**
- Modify: `App/OneToOne/Features/Cycle/MonthGridView.swift`
- Modify: `docs/decisions.md`

- [ ] **Step 1:** В `MonthGridView.body` на `LazyVGrid` добавить `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` с комментарием почему.
- [ ] **Step 2:** В `DayCell` добавить `@ScaledMetric(relativeTo: .callout) private var scaledCircle: CGFloat = 34` и `private var circle: CGFloat { min(scaledCircle, 38) }`; заменить `.frame(width: 34, height: 34)` на `.frame(width: circle, height: circle)`.
- [ ] **Step 3:** В шапке у `Text(month.title)` добавить `.multilineTextAlignment(.center)`.
- [ ] **Step 4:** Превью `#Preview("Крупный шрифт")` для `MonthGridView` с месячными, прогнозом, симптомами, рисками и выбранным днём, `.dynamicTypeSize(.accessibility3)`; плюс обычное превью с теми же данными.
- [ ] **Step 5:** Строка в `docs/decisions.md`.
- [ ] **Step 6:** Сборка: `xcodegen generate && xcodebuild build -project OneToOne.xcodeproj -scheme OneToOne -destination 'platform=iOS Simulator,name=iPhone 17'` → `BUILD SUCCEEDED`.
- [ ] **Step 7:** Коммит «Ограничить рост шрифта в сетке календаря».

### Task 2: Легенда фаз

**Files:**
- Modify: `App/OneToOne/Features/Cycle/HisCalendarView.swift` (`PhaseLegend`, превью)

- [ ] **Step 1:** В `PhaseLegend` читать `@Environment(\.dynamicTypeSize)`; при `isAccessibilitySize` одна колонка, иначе две, как сейчас.
- [ ] **Step 2:** Превью `HisCalendarView` с `.dynamicTypeSize(.accessibility3)`.
- [ ] **Step 3:** Сборка (команда из Task 1) → `BUILD SUCCEEDED`.
- [ ] **Step 4:** Коммит «Перестраивать легенду фаз в колонку при крупном шрифте».

### Task 3: Проверка и скриншоты

- [ ] **Step 1:** Тесты: `cd Packages/OneToOneKit && swift test` и `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17'` → все прошли.
- [ ] **Step 2:** Запустить приложение в симуляторе, вкладка «Цикл» у неё и у него; скриншоты на `content_size large` и `accessibility-extra-extra-extra-large`, светлая и тёмная тема → `docs/screenshots/`.
- [ ] **Step 3:** Сравнить обычный размер со скриншотом с `main`: вид тот же.
- [ ] **Step 4:** `/code-review`, исправить найденное, PR с `Closes #72`.
