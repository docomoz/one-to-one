# Знакомство (#13): план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** при первом запуске человек по шагам вводит свой пол, имя, дату рождения и данные партнёра, создаёт пару, после чего видит вкладки.

**Architecture:** проверки (имя, дата, 18 лет, разный пол) и тексты ошибок лежат в `Core` пакета `OneToOneKit` и тестируются `swift test`. `AppModel` получает метод `createCouple`, который пишет `couple` и `meID` одним `update`. Экраны в `App/OneToOne/Features/Onboarding/` только раскладывают поля и вызывают логику. `OneToOneApp` показывает знакомство, пока `AppData.isPaired == false`.

**Tech Stack:** Swift 6, SwiftUI (iOS 26), Swift Testing, XcodeGen.

**Spec:** [docs/superpowers/specs/2026-10-10-onboarding-design.md](../specs/2026-10-10-onboarding-design.md)

## Global Constraints
- Интерфейс только на русском. Тексты ошибок дословно: «Пара — это мужчина и женщина», «Приложением можно пользоваться с 18 лет».
- Минимальный возраст 18 лет для обоих.
- Дни считаются через `DayKey`, не через `Date`.
- `AppModel.data` снаружи только для чтения, менять только через `model.update { … }`.
- Новое поле в сохраняемых данных должно читаться из старых файлов, где его нет.
- Цвета и компоненты только из `DesignSystem` (`GradientButton`, `Palette.tile`, `BrandGradient`), светлая и тёмная тема.
- Новых зависимостей нет.

## Review Focus
1. Имя из одних пробелов: кнопка «Дальше» неактивна, `validated` бросает `.emptyName` (тест в задаче 2).
2. День рождения 29 февраля: в невисокосный год возраст растёт 1 марта (тест в задаче 1).
3. Старый файл `AppData` без `birthDate` у людей читается (тест в задаче 1).
4. Пара в данных есть, а `meID` пустой или чужой: показываем знакомство (`isPaired == false`, тест в задаче 2).
5. Вернулись на шаг 1 и сменили свой пол: пол партнёра переставляется, только если его не трогали руками (проверка руками в задаче 4).

---

### Task 1: Дата рождения и возраст

**Files:**
- Modify: `Packages/OneToOneKit/Sources/Core/Pair/Person.swift`
- Modify: `Packages/OneToOneKit/Sources/Core/DayKey.swift`
- Test: `Packages/OneToOneKit/Tests/CoreTests/DayKeyTests.swift`, `Packages/OneToOneKit/Tests/CoreTests/Pair/PersonTests.swift` (новый)

**Interfaces:**
- Produces: `Person.birthDate: DayKey?`; `Person.init(id: UUID = UUID(), name: String, sex: Sex, birthDate: DayKey? = nil)`; `DayKey.age(on today: DayKey) -> Int` (полных лет).

- [ ] **Step 1: Write the failing tests**

```swift
// DayKeyTests.swift
@Test func ageCountsFullYears() {
    let birth = DayKey(year: 2000, month: 5, day: 12)
    #expect(birth.age(on: DayKey(year: 2018, month: 5, day: 11)) == 17)
    #expect(birth.age(on: DayKey(year: 2018, month: 5, day: 12)) == 18)
    #expect(birth.age(on: DayKey(year: 2018, month: 12, day: 31)) == 18)
}

@Test func ageForLeapDayGrowsOnFirstOfMarch() {
    let birth = DayKey(year: 2008, month: 2, day: 29)
    #expect(birth.age(on: DayKey(year: 2026, month: 2, day: 28)) == 17)
    #expect(birth.age(on: DayKey(year: 2026, month: 3, day: 1)) == 18)
}

// PersonTests.swift
@Test func personDecodesWithoutBirthDate() throws {
    let json = #"{"id": "\#(UUID())", "name": "Аня", "sex": "female"}"#
    let person = try JSONDecoder().decode(Person.self, from: Data(json.utf8))
    #expect(person.birthDate == nil)
}

@Test func personRoundTripsBirthDate() throws {
    let person = Person(name: "Аня", sex: .female, birthDate: DayKey(year: 1996, month: 5, day: 12))
    let decoded = try JSONDecoder().decode(Person.self, from: JSONEncoder().encode(person))
    #expect(decoded == person)
}
```

- [ ] **Step 2: Run** `cd Packages/OneToOneKit && swift test` — Expected: не компилируется (`age`, `birthDate` нет).
- [ ] **Step 3: Implement** `birthDate` в `Person` (опциональное, синтезированный `Codable` сам читает отсутствующее поле как `nil`) и `age(on:)` в `DayKey`: разница лет минус 1, если `(today.month, today.day) < (month, day)`.
- [ ] **Step 4: Run** `swift test` — Expected: все тесты зелёные.
- [ ] **Step 5: Commit** «Добавить дату рождения и возраст».

### Task 2: Черновик человека, ошибки знакомства, сборка пары

**Files:**
- Create: `Packages/OneToOneKit/Sources/Core/Pair/PersonDraft.swift`, `Packages/OneToOneKit/Sources/Core/Pair/OnboardingError.swift`
- Modify: `Packages/OneToOneKit/Sources/Core/Storage/AppData.swift` (вычисляемое `isPaired`, в `Codable` не входит)
- Test: `Packages/OneToOneKit/Tests/CoreTests/Pair/PersonDraftTests.swift`, `Packages/OneToOneKit/Tests/CoreTests/Storage/StoreTests.swift`

**Interfaces:**
- Consumes: `Person.init(id:name:sex:birthDate:)`, `DayKey.age(on:)`, `Couple.make`.
- Produces:
  - `public struct PersonDraft: Equatable, Sendable { public let id: UUID; public var sex: Sex; public var name: String; public var birthDate: DayKey?; public init(id: UUID = UUID(), sex: Sex, name: String = "", birthDate: DayKey? = nil) }`
  - `PersonDraft.minimumAge = 18`
  - `PersonDraft.isFilled: Bool` — имя без пробелов по краям не пустое и дата выбрана (для активности кнопок).
  - `PersonDraft.validated(today: DayKey) throws(OnboardingError) -> Person` — `id` черновика, имя обрезано.
  - `public enum OnboardingError: Error, Equatable { case emptyName, noBirthDate, tooYoung, sameSex; public var message: String }`
  - `Couple.make(me: PersonDraft, partner: PersonDraft, today: DayKey) throws(OnboardingError) -> Couple` — сначала проверяет `me`, потом `partner`, потом пол.
  - `AppData.isPaired: Bool` — пара есть и `meID` равен `couple.man.id` или `couple.woman.id`.

- [ ] **Step 1: Write the failing tests**

```swift
// PersonDraftTests.swift
private let today = DayKey(year: 2026, month: 10, day: 10)
private let adult = DayKey(year: 1996, month: 5, day: 12)

@Test func draftTrimsName() throws {
    let draft = PersonDraft(sex: .female, name: "  Аня ", birthDate: adult)
    let person = try draft.validated(today: today)
    #expect(person == Person(id: draft.id, name: "Аня", sex: .female, birthDate: adult))
}

@Test func draftRejectsEmptyOrSpacesName() {
    #expect(throws: OnboardingError.emptyName) { try PersonDraft(sex: .male, name: "   ", birthDate: adult).validated(today: today) }
    #expect(!PersonDraft(sex: .male, name: "   ", birthDate: adult).isFilled)
}

@Test func draftRequiresBirthDate() {
    #expect(throws: OnboardingError.noBirthDate) { try PersonDraft(sex: .male, name: "Боря").validated(today: today) }
    #expect(!PersonDraft(sex: .male, name: "Боря").isFilled)
    #expect(PersonDraft(sex: .male, name: "Боря", birthDate: adult).isFilled)
}

@Test func draftRejectsUnder18() throws {
    let almost = PersonDraft(sex: .male, name: "Боря", birthDate: DayKey(year: 2008, month: 10, day: 11))
    #expect(throws: OnboardingError.tooYoung) { try almost.validated(today: today) }
    let exactly = PersonDraft(sex: .male, name: "Боря", birthDate: DayKey(year: 2008, month: 10, day: 10))
    _ = try exactly.validated(today: today)
}

@Test func coupleFromDraftsRejectsSameSex() {
    let me = PersonDraft(sex: .female, name: "Аня", birthDate: adult)
    let partner = PersonDraft(sex: .female, name: "Аня", birthDate: adult)
    #expect(throws: OnboardingError.sameSex) { try Couple.make(me: me, partner: partner, today: today) }
}

@Test func coupleFromDraftsChecksPartnerAge() {
    let me = PersonDraft(sex: .female, name: "Аня", birthDate: adult)
    let partner = PersonDraft(sex: .male, name: "Боря", birthDate: DayKey(year: 2010, month: 1, day: 1))
    #expect(throws: OnboardingError.tooYoung) { try Couple.make(me: me, partner: partner, today: today) }
}

@Test func coupleFromDraftsKeepsIDs() throws {
    let me = PersonDraft(sex: .female, name: "Аня", birthDate: adult)
    let partner = PersonDraft(sex: .male, name: "Боря", birthDate: adult)
    let couple = try Couple.make(me: me, partner: partner, today: today)
    #expect(couple.woman.id == me.id)
    #expect(couple.man.id == partner.id)
}

@Test func onboardingErrorMessages() {
    #expect(OnboardingError.sameSex.message == "Пара — это мужчина и женщина")
    #expect(OnboardingError.tooYoung.message == "Приложением можно пользоваться с 18 лет")
}

// StoreTests.swift
@Test func appDataIsPairedOnlyWithOwnMeID() throws {
    let man = Person(name: "Боря", sex: .male), woman = Person(name: "Аня", sex: .female)
    var data = AppData()
    #expect(!data.isPaired)
    data.couple = try Couple.make(man, woman)
    #expect(!data.isPaired)
    data.meID = UUID()
    #expect(!data.isPaired)
    data.meID = woman.id
    #expect(data.isPaired)
}
```

- [ ] **Step 2: Run** `swift test` — Expected: не компилируется.
- [ ] **Step 3: Implement** типы из Interfaces. Тексты `emptyName` «Введи имя», `noBirthDate` «Выбери дату рождения». `Couple.make(me:partner:today:)` переводит `CoupleError.sameSex` в `OnboardingError.sameSex`.
- [ ] **Step 4: Run** `swift test` — Expected: зелёные.
- [ ] **Step 5: Commit** «Добавить проверки знакомства и сборку пары из черновиков».

### Task 3: Создание пары в AppModel и записи в решениях

**Files:**
- Create: `App/OneToOne/AppModel+Onboarding.swift`
- Test: `App/OneToOneTests/AppModelOnboardingTests.swift`
- Modify: `docs/decisions.md` (две строки в конец)

**Interfaces:**
- Consumes: `Couple.make(me:partner:today:)`, `AppData.isPaired`.
- Produces: `AppModel.createCouple(me: PersonDraft, partner: PersonDraft, today: DayKey = DayKey(.now)) throws(OnboardingError)` — при успехе один `update`, пишет `couple` и `meID = me.id`; при ошибке данные не меняются.

- [ ] **Step 1: Write the failing tests**

```swift
private let today = DayKey(year: 2026, month: 10, day: 10)
private let adult = DayKey(year: 1996, month: 5, day: 12)

@MainActor
@Test func createCoupleSavesCoupleAndMe() throws {
    let store = InMemoryStore()
    let model = AppModel(store: store)
    let me = PersonDraft(sex: .female, name: "Аня", birthDate: adult)
    let partner = PersonDraft(sex: .male, name: "Боря", birthDate: adult)

    try model.createCouple(me: me, partner: partner, today: today)

    #expect(model.data.isPaired)
    #expect(model.data.meID == me.id)
    #expect(try store.load() == model.data)
}

@MainActor
@Test func createCoupleSameSexChangesNothing() {
    let store = InMemoryStore()
    let model = AppModel(store: store)
    let me = PersonDraft(sex: .female, name: "Аня", birthDate: adult)
    let partner = PersonDraft(sex: .female, name: "Аня", birthDate: adult)

    #expect(throws: OnboardingError.sameSex) { try model.createCouple(me: me, partner: partner, today: today) }
    #expect(model.data == AppData())
}
```

- [ ] **Step 2: Run** `xcodegen generate && xcodebuild test -project OneToOne.xcodeproj -scheme OneToOne -destination 'platform=iOS Simulator,name=iPhone 17'` — Expected: не собирается.
- [ ] **Step 3: Implement** `createCouple`.
- [ ] **Step 4: Run** ту же команду — Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Add to `docs/decisions.md`:**
  - `2026-10-10: При знакомстве спрашиваем дату рождения обоих (DayKey в Person.birthDate). Причина: персонализация потом: поздравление с днём рождения, возраст, анализ цикла и статистики по возрасту.`
  - `2026-10-10: Приложением можно пользоваться с 18 лет: знакомство не пускает дальше, если кому-то из пары меньше 18. Причина: приложение про интимную жизнь, в App Store у него рейтинг 18+.`
- [ ] **Step 6: Commit** «Создавать пару через AppModel».

### Task 4: Экраны знакомства и переключение на вкладки

**Files:**
- Create: `App/OneToOne/Features/Onboarding/OnboardingView.swift` (`NavigationStack`, хранит `@State` черновики `me`, `partner`, флаг `partnerSexTouched`, путь шагов)
- Create: `App/OneToOne/Features/Onboarding/SexStepView.swift` (шаг 1 «Кто ты?»), `SexChoiceButton.swift` (крупная кнопка: `Palette.tile` фон, выбранная — `BrandGradient.primary` и белый текст)
- Create: `App/OneToOne/Features/Onboarding/PersonFormView.swift` (шаги 2 и 3: `Form` с полем имени, `BirthDateRow`, на шаге 3 ещё сегментный выбор пола; под полями розовый текст ошибки; внизу `GradientButton`, неактивна при `!draft.isFilled`)
- Create: `App/OneToOne/Features/Onboarding/BirthDateRow.swift` (строка «Дата рождения» / «Выбрать», по нажатию раскрывает `DatePicker` `.wheel`, диапазон с 1900-01-01 до сегодня; `Date ↔ DayKey` через `DayKey(_:)` и `Calendar.current`)
- Modify: `App/OneToOne/OneToOneApp.swift` — если `model.data.isPaired`, `TabView` как сейчас, иначе `OnboardingView()`.

**Interfaces:**
- Consumes: `PersonDraft`, `OnboardingError.message`, `AppModel.createCouple(me:partner:today:)`, `AppData.isPaired`, `GradientButton(title:action:)`, `Palette.tile`, `BrandGradient.primary`.

Поведение (из спеки):
- Шаг 1: нажатие на пол ставит `me.sex` и сразу открывает шаг 2. Если `partnerSexTouched == false`, `partner.sex` = противоположный.
- Шаг 2 «Как тебя зовут?», кнопка «Дальше»: `try me.validated(today:)`; ошибка показывается текстом, иначе шаг 3.
- Шаг 3 «Партнёр», кнопка «Создать пару»: `try model.createCouple(me:partner:)`; ошибку показываем текстом. При успехе `isPaired` становится `true`, и `OneToOneApp` сам переключается на вкладки.
- Ошибка стирается, когда меняется любое поле на этом шаге.

- [ ] **Step 1: Build** `xcodegen generate && xcodebuild test …` (команда из задачи 3) — Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 2: Проверить руками в симуляторе** (чистая установка): шаги идут по порядку, «Назад» сохраняет введённое; «Дальше» неактивна с пустым именем и без даты; дата 2010 года даёт «Приложением можно пользоваться с 18 лет»; два одинаковых пола дают «Пара — это мужчина и женщина»; после создания пары видны вкладки; после перезапуска сразу вкладки. Пункт 5 из Review Focus: вернуться на шаг 1, сменить пол — пол партнёра меняется, а если его меняли руками, остаётся. Тёмная тема выглядит нормально.
- [ ] **Step 3: Скриншоты** трёх шагов и ошибки для PR.
- [ ] **Step 4: Commit** «Добавить экраны знакомства».
