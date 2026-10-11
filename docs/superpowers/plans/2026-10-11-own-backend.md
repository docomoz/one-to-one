# Свой сервер вместо iCloud: план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Аккаунты, пары со сквозным шифрованием и синхронизация между телефонами пары через свой сервер Appwrite в Timeweb, к запуску в App Store около 18 октября 2026.

**Architecture:** Сервер ничего не понимает в данных. Он хранит непрозрачные зашифрованные записи пары, доступные только членам команды Appwrite этой пары, и выполняет несколько функций (приглашения, выход, удаление аккаунта). Вся логика на телефоне, в новом модуле `Sync` пакета `OneToOneKit`: шифрование (CryptoKit), превращение `AppData` в записи и обратно, слияние «поздняя правка побеждает», очередь изменений без сети. Приложение подключает модуль к Appwrite через тонкий адаптер.

**Tech Stack:** Swift 6 / SwiftUI / CryptoKit; Appwrite (своя установка, последняя стабильная 2.x, PostgreSQL) и его Apple SDK; функции Appwrite на Node.js; Timeweb Cloud.

**Spec:** `docs/superpowers/specs/2026-10-11-own-backend-design.md`

## Global Constraints

- Записи пары на сервере, в логах и резервных копиях только зашифрованы. Сервер не видит ни содержимое, ни **вид и дату** записи: id документа непрозрачный (см. задачу 3).
- Шифрование только стандартное и описанное в `docs/crypto.md` так, чтобы Android и веб могли его повторить: AES-256-GCM, X25519, HKDF-SHA256, HMAC-SHA256. У конверта есть байт версии `1`.
- Ключ пары живёт только в Keychain устройств партнёров (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, без синхронизации iCloud Keychain). На сервер уходит только завёрнутым для конкретного устройства.
- Сервер и база только в российском дата-центре Timeweb. Приложение на старте доступно только в российском App Store.
- Вход: почта с 6-значным кодом и «Войти с Apple». Аккаунт нужен всем.
- Без сети приложение работает как сейчас, изменения уходят позже. `LocalStore` остаётся источником данных для экранов.
- Не синхронизируются: `movieCache`, `MovieCatalogCache.json`, всё отладочное.
- Каждая новая зависимость (Appwrite Apple SDK, пакеты Node для функций) записывается в `docs/decisions.md`.
- Логика с тестами в `Packages/OneToOneKit`, экраны в `App/OneToOne`. Маленькие файлы, одна ответственность.
- **Порядок урезания, если не успеваем:** 1) «Войти с Apple» (задача 10), 2) перенос старых записей в пару (шаг в задаче 8), 3) своё второе устройство (у нас только iPhone; восстановление через партнёра остаётся).

## Review Focus

1. **Новое поле `AppData` молча не синхронизируется.** Тест в задаче 4 падает, если в `AppData` появилось поле, не отнесённое ни к синхронизируемым, ни к локальным.
2. **Одновременные правки двух партнёров.** Она отмечает месячные, он записывает секс без сети, потом оба выходят в сеть: обе записи на обоих телефонах (тест в задаче 5).
3. **Pull пропускает документы с одинаковым временем на сервере.** Курсор не должен терять документы с равным `$updatedAt`, сортировка по `$updatedAt`, затем по `$id` (тест в задаче 7 на фейке и ручная проверка на сервере).
4. **Подмена ключей сервером при приглашении, включая перебор кода.** Сервер видит оба открытых ключа и мог бы перебрать ~10⁶ своих, чтобы коды совпали. Поэтому запрашивающее устройство сначала публикует только обязательство `SHA-256(свой открытый ключ)`, а сам ключ раскрывает после ответа второго; второе проверяет совпадение с обязательством (тесты в задаче 8, ручная проверка там же). Найдено на ревью #93.
6. **Откат и поддельное удаление сервером.** Время правки и признак удаления на сервере открыты, им не верим: внутри конверта зашифрована вся запись (id, время, содержимое или удаление), слияние идёт только по расшифрованному (тесты в задаче 5). Найдено на ревью #93.
5. **Бывший партнёр после выхода из пары.** Сервер не отдаёт ему документы пары, на его телефоне записи пары стёрты, новая пара получает новый ключ (задача 9).

---

## Как это раскладывается во времени

Два независимых потока с первого дня, потом сборка:

- **Поток «Сервер» (Максим + Claude):** задачи 1 → 2.
- **Поток «Телефон» (Дарья + Claude):** задачи 3 → 4 → 5. Сервер для них не нужен.
- **Сборка:** 6 (вход) → 7 (синхронизация в приложении) → 8 (пара и приглашение) → 9 (восстановление, выход, удаление) → 10 (вход с Apple, режется первым).
- **Параллельно в любое время:** 11 (юридическое и App Store).

---

### Задача 1: Сервер Appwrite в Timeweb

**Цель:** работающий Appwrite по HTTPS на своём домене, проект `one-to-one` с платформой iOS, письма с кодами доходят. Инструкция, по которой его можно поднять заново и обновить.

**Files:**
- Create: `docs/server.md`: заказ сервера, домен, установка, SMTP, резервные копии, обновление, что делать при сбое.
- Create: `Server/README.md`: короткая ссылка на `docs/server.md` и что лежит в `Server/`.
- Modify: `docs/decisions.md`: Appwrite, Timeweb, почтовый сервис.

**Руками (Максим, Claude подсказывает по шагам):**
- [ ] Сервер Timeweb Cloud в российском дата-центре, Ubuntu LTS, не меньше 2 CPU / 4 ГБ RAM / 2 ГБ swap / 40 ГБ диска, включены ежедневные снимки.
- [ ] Домен (например, `api.<домен>`) указывает на сервер, HTTPS через встроенный в Appwrite Let's Encrypt.
- [ ] Appwrite установлен официальным установщиком (Docker), база PostgreSQL. В консоли: проект `one-to-one`, платформа Apple с bundle id `com.docomoz.onetoone`, включён вход Email OTP, остальные способы выключены.
- [ ] SMTP российского почтового сервиса прописан в Appwrite. Письмо с кодом приходит на почту Gmail и на почту Яндекса (не в спам).
- [ ] Регистрация закрыта для всего, кроме нашего приложения; лимиты на попытки входа по умолчанию включены.
- [ ] Резервная копия базы снимается раз в сутки и хранится не только на этом сервере (S3 Timeweb).

**Готово, когда:** `curl https://<домен>/v1/health/version` отвечает версией. Тестовый вход по коду из консоли Appwrite работает. `docs/server.md` позволяет человеку без опыта повторить установку.

**Зависит от:** аккаунт Timeweb (есть), домен.

---

### Задача 2: Схема данных и функции сервера

**Цель:** коллекции и функции Appwrite описаны в репозитории и выкладываются одной командой Appwrite CLI. У функций есть тесты, CI их запускает.

**Files:**
- Create: `Server/appwrite.config.json`: база `main`, коллекции и функции (выкладывается `appwrite push`).
- Create: `Server/functions/create-invite/`, `accept-invite/`, `leave-couple/`, `delete-account/` (Node.js, `src/main.js` + `test/*.test.js` на `node:test`).
- Modify: `.github/workflows/*.yml`: задание `server` на ubuntu запускает `npm test` в каждой функции, если менялось `Server/`.
- Modify: `docs/server.md`: как выкладывать схему и функции.

**Interfaces (Produces):**
- Коллекция `records`, document security, права документа `Role.team(<coupleID>)` на чтение/запись. Атрибуты: `coupleId` (string 36), `updatedAt` (datetime, время правки на устройстве), `envelope` (string до 65 535, base64 конверта; пусто = удалено), `deleted` (bool). Индексы: `coupleId` + `$updatedAt` + `$id`. Id документа задаёт клиент (32 hex, задача 3).
- Коллекция `keyRequests`, права `Role.team(<coupleID>)`: `coupleId`, `requesterUserId`, `requesterPublicKey` (base64), `responderPublicKey` (base64, пусто до ответа), `wrappedKey` (base64, пусто до подтверждения), `status` (`waiting` | `answered` | `delivered` | `rejected`), `expiresAt`.
- Коллекция `invites`, без клиентских прав (только функции): `codeHash` (SHA-256 кода, hex), `coupleId`, `expiresAt`.
- Функция `create-invite` (вызывает член пары): вход `{coupleId}`, проверяет, что вызывающий в команде и в ней один человек; создаёт код из 8 символов алфавита без похожих букв (`23456789ABCDEFGHJKMNPQRSTUVWXYZ`), хранит только хэш, срок 7 дней; ответ `{code, expiresAt}`. Старые приглашения пары удаляются.
- Функция `accept-invite`: вход `{code}`; код существует, не истёк, в команде ровно один человек, вызывающий не в другой паре → добавляет вызывающего в команду (подтверждённое членство), удаляет приглашение; ответ `{coupleId}`. Ошибки: `invite_not_found`, `invite_expired`, `couple_full`, `already_paired`.
- Функция `leave-couple`: вход `{coupleId}` → удаляет членство вызывающего; если команда опустела, удаляет команду и все её `records` и `keyRequests`.
- Функция `delete-account`: делает `leave-couple` для всех пар пользователя, затем удаляет пользователя.

**Тесты (с подменой Appwrite SDK):**
- [ ] `createInviteStoresOnlyHash`: в базу попадает хэш, а не код.
- [ ] `createInviteRejectsFullCouple`.
- [ ] `acceptInviteJoinsTeamAndDeletesInvite`.
- [ ] `acceptInviteRejectsExpired`, `acceptInviteRejectsSecondPartner`, `acceptInviteRejectsUserAlreadyPaired`.
- [ ] `leaveCoupleDeletesEmptyCoupleData`.
- [ ] `deleteAccountLeavesCouplesThenDeletesUser`.

**Готово, когда:** тесты проходят локально и в CI. `appwrite push` выкладывает схему и функции на сервер из задачи 1. Вызов функций руками из консоли Appwrite даёт ожидаемые ответы.

**Зависит от:** 1.

---

### Задача 3: Шифрование пары (модуль `Sync`)

**Цель:** ключ пары, шифрование записей, непрозрачные id, обмен ключами между устройствами с проверочным кодом. Всё работает и тестируется без сервера.

**Files:**
- Modify: `Packages/OneToOneKit/Package.swift`: target `Sync` (зависит от `Core`), test target `SyncTests`.
- Create: `Packages/OneToOneKit/Sources/Sync/Crypto/CoupleKey.swift`, `RecordCipher.swift`, `RecordIDHasher.swift`, `KeyExchange.swift`.
- Create: `Packages/OneToOneKit/Tests/SyncTests/CryptoTests.swift`.
- Create: `docs/crypto.md`: точное описание алгоритмов, байтовых форматов и строк `info` для HKDF, чтобы Android и веб повторили побайтно. Там же тестовые векторы.

**Interfaces (Produces):**
```swift
public struct CoupleKey: Sendable, Equatable {
    public init()                                        // новый случайный 256-битный ключ
    public init(rawRepresentation: Data) throws(CryptoError)
    public var rawRepresentation: Data { get }           // 32 байта
}
public enum CryptoError: Error, Equatable { case invalidKey, invalidEnvelope, unsupportedVersion, authenticationFailed }

public enum RecordCipher {
    /// Конверт: [0x01] + AES.GCM combined (nonce 12 + шифротекст + тег 16). AAD = utf8("\(coupleID)/\(documentID)").
    public static func seal(_ plaintext: Data, documentID: String, coupleID: String, key: CoupleKey) throws(CryptoError) -> Data
    public static func open(_ envelope: Data, documentID: String, coupleID: String, key: CoupleKey) throws(CryptoError) -> Data
}

public enum RecordIDHasher {
    /// Непрозрачный id документа: первые 16 байт HMAC-SHA256(ключ = HKDF(coupleKey, info: "one-to-one record-id v1"), recordID) в hex (32 символа).
    public static func documentID(for recordID: String, key: CoupleKey) -> String
}

public struct KeyExchangePair: Sendable {
    public init()                                        // новая пара X25519
    public init(rawPrivateKey: Data) throws(CryptoError)
    public var rawPrivateKey: Data { get }
    public var publicKey: Data { get }                   // 32 байта
}
public enum KeyExchange {
    /// 6 цифр из SHA-256(меньший ключ || больший ключ): одинаково на обоих устройствах, порядок ключей не важен.
    public static func verificationCode(_ a: Data, _ b: Data) -> String
    /// Ключ обёртки = HKDF-SHA256(общий секрет X25519, salt: пусто, info: "one-to-one key-wrap v1"), затем AES.GCM.
    public static func wrap(_ key: CoupleKey, from: KeyExchangePair, to peerPublicKey: Data) throws(CryptoError) -> Data
    public static func unwrap(_ wrapped: Data, with: KeyExchangePair, from peerPublicKey: Data) throws(CryptoError) -> CoupleKey
}
```

- [ ] **Шаг 1: тесты (падают):**
  - `sealOpenRoundTrip`: `open(seal(x)) == x`.
  - `openWithOtherKeyFails`: `.authenticationFailed`.
  - `openWithOtherDocumentIDFails`: переставить конверт в другой документ нельзя (`.authenticationFailed`).
  - `envelopeStartsWithVersion1`, `unknownVersionRejected` (`.unsupportedVersion`).
  - `sameRecordIDSameDocumentID`, `documentIDDiffersBetweenCouples`, `documentIDIs32Hex`, `documentIDDoesNotContainRecordID` (для `"period:2026-10-11"`).
  - `wrapUnwrapDeliversSameKey`.
  - `verificationCodeSameOnBothSides`: `verificationCode(a, b) == verificationCode(b, a)`, 6 цифр, с ведущими нулями.
  - `substitutedPublicKeyGivesDifferentCode`: подмена ключа сервером (`c` вместо `b`) даёт другой код (Review Focus 4).
  - `testVectorsMatchDocs`: фиксированные ключи и nonce из `docs/crypto.md` дают ровно те байты, что записаны в документе.
- [ ] **Шаг 2:** `cd Packages/OneToOneKit && swift test --filter SyncTests`: FAIL (нет типов).
- [ ] **Шаг 3:** реализовать на CryptoKit (`AES.GCM`, `Curve25519.KeyAgreement`, `HKDF<SHA256>`, `HMAC<SHA256>`).
- [ ] **Шаг 4:** `swift test`: PASS, всё остальное тоже зелёное.
- [ ] **Шаг 5:** коммит «Добавить шифрование пары».

**Зависит от:** ничего.

---

### Задача 4: `AppData` ↔ записи синхронизации

**Цель:** разобрать `AppData` на отдельные записи и собрать обратно, без потерь и без кэшей.

**Files:**
- Create: `Packages/OneToOneKit/Sources/Sync/Records/SyncRecord.swift`, `SyncRecordMapper.swift`.
- Create: `Packages/OneToOneKit/Tests/SyncTests/SyncRecordMapperTests.swift`.

**Interfaces (Produces):**
```swift
/// Одна запись. `payload == nil` — запись удалена (надгробие), чтобы удаление дошло до партнёра.
public struct SyncRecord: Codable, Equatable, Sendable {
    public let id: String          // "<вид>:<ключ>", виден только на устройствах
    public let updatedAt: Date
    public let payload: Data?      // JSON значения
}
public enum SyncRecordMapper {
    /// Все синхронизируемые значения: id → JSON. Кэши не входят.
    public static func payloads(from data: AppData) -> [String: Data]
    /// Подменяет в `data` все синхронизируемые поля значениями из `payloads`; локальные поля не трогает.
    public static func apply(_ payloads: [String: Data], to data: AppData) -> AppData
    public static let syncedFields: Set<String>
    public static let localFields: Set<String>   // "movieCache", "meID"
}
```
Виды и ключи id (решение плана): `couple:main`, `togetherSince:main`, `sex:<uuid>`, `period:<день>`, `herMood:<день>`, `symptoms:<день>`, `watchlist:<ownerID>:<movieID>`, `session:<uuid>`, `swipe:<sessionID>:<personID>:<movieID>`, `watched:<movieID>` (значение — дата из `watchedAt` или `null`), `rating:<personID>:<movieID>`. День в формате `DayKey` как в JSON сейчас. `meID` локальный: на каждом телефоне свой.

- [ ] **Шаг 1: тесты (падают):**
  - `fullAppDataRoundTrips`: `AppData` со всеми синхронизируемыми полями заполненными → `apply(payloads(from: x), to: AppData()) == x` по синхронизируемым полям.
  - `movieCacheAndMeIDNotSynced`: их нет в `payloads`, `apply` их сохраняет.
  - `everyAppDataFieldIsClassified`: метки `Mirror(reflecting: AppData()).children` равны `syncedFields ∪ localFields`. Падает, когда в `AppData` добавили поле и забыли решить, синхронизировать ли его (Review Focus 1).
  - `removedSexEntryDisappearsFromPayloads`.
  - `periodDayIDsAreStable`: один и тот же день даёт один и тот же id.
- [ ] **Шаг 2:** `swift test --filter SyncRecordMapperTests`: FAIL.
- [ ] **Шаг 3:** реализовать.
- [ ] **Шаг 4:** `swift test`: PASS.
- [ ] **Шаг 5:** коммит «Разбирать данные на записи синхронизации».

**Зависит от:** ничего (можно параллельно с 3).

---

### Задача 5: Движок синхронизации без сервера

**Цель:** очередь локальных правок, отправка, получение, слияние «поздняя правка побеждает». Проверяется на фейковом сервере с двумя устройствами.

**Files:**
- Create: `Packages/OneToOneKit/Sources/Sync/Engine/SyncTransport.swift`, `SyncState.swift`, `SyncMerger.swift`, `SyncEngine.swift`.
- Create: `Packages/OneToOneKit/Tests/SyncTests/FakeTransport.swift`, `SyncMergerTests.swift`, `SyncEngineTests.swift`.

**Interfaces:**
- Consumes: `RecordCipher`, `RecordIDHasher`, `CoupleKey` (задача 3); `SyncRecord`, `SyncRecordMapper` (задача 4).
- Produces:
```swift
public struct EncryptedRecord: Equatable, Sendable {
    public let documentID: String
    /// Время на сервере: только подсказка для сортировки, слиянию оно не указ.
    public let updatedAt: Date
    /// Всегда есть, и у удалённых тоже: внутри зашифрован весь `SyncRecord` (id, updatedAt, payload или nil) в JSON.
    public let envelope: Data
}
public protocol SyncTransport: Sendable {
    func push(_ records: [EncryptedRecord], coupleID: String) async throws
    /// Всё, что изменилось на сервере после курсора, по порядку (`$updatedAt`, затем `$id`), и новый курсор.
    func pull(coupleID: String, after cursor: String?) async throws -> (records: [EncryptedRecord], cursor: String?)
}
public struct SyncState: Codable, Equatable, Sendable {
    public var known: [String: SyncRecord]   // последнее слитое состояние по id записи
    public var outbox: [String: SyncRecord]  // ещё не отправлено
    public var cursor: String?
}
public enum SyncMerger {
    /// Побеждает больший `updatedAt`; при равенстве — надгробие, затем больший payload побайтно. Одинаково на обоих устройствах.
    public static func winner(_ a: SyncRecord, _ b: SyncRecord) -> SyncRecord
}
public actor SyncEngine {
    public init(coupleID: String, key: CoupleKey, transport: SyncTransport, state: SyncState)
    /// Сравнивает `data` с известным и кладёт отличия в outbox с временем `now`.
    public func recordLocalChange(_ data: AppData, now: Date)
    /// Отправляет outbox, забирает новое, сливает. Возвращает данные для экранов. Без сети бросает ошибку, outbox сохраняется.
    public func sync(local: AppData) async throws -> AppData
    public var state: SyncState { get }      // приложение сохраняет его в `SyncState.json`
}
```

Правила, которые не видны из сигнатур (из ревью #91 и #93):
- Слияние верит только времени и признаку удаления **из расшифрованного** `SyncRecord`; `id` внутри конверта должен давать тот же `documentID`, иначе запись отбрасывается.
- Надгробие ставится только для id, которые этот телефон понимает (известный вид записи): более старая версия приложения не должна стирать у партнёра записи новых видов.
- Правкой считается только то, что изменилось на этом телефоне (сравнение байтов `payloads` до и после локальной правки), а не разница между `known` и пересобранными данными.
- `SyncRecordMapper.apply` заменяет все синхронизируемые поля, поэтому вызывать его можно только с полным слитым набором записей (`known` + `outbox`), никогда с частичным.

- [ ] **Шаг 1: тесты (падают):**
  - `replayedOldEnvelopeLoses`: сервер отдаёт старый конверт с новым серверным временем → у устройства остаётся новая запись.
  - `forgedDeletionIgnored`: сервер помечает документ удалённым или подменяет конверт мусором → запись на устройстве цела.
  - `unknownKindNeverTombstoned`: запись неизвестного вида от партнёра не превращается у нас в удаление.
  - `laterEditWins`, `tombstoneWinsTie`, `winnerIsSymmetric` (`winner(a,b) == winner(b,a)`).
  - `twoDevicesConcurrentEditsBothSurvive`: устройство A отмечает месячные, устройство B без сети записывает секс; оба `sync` → у обоих и то и другое (Review Focus 2).
  - `offlineChangeSentLater`: транспорт бросает ошибку → outbox не пуст; транспорт снова работает → запись дошла до второго устройства.
  - `deletionReachesPartner`: удалённая на A запись секса исчезает на B.
  - `serverSeesNoPlaintext`: в `FakeTransport` нет ни одного `documentID` или байтов, содержащих `"period"`, `"sex"`, дату или имя.
  - `undecryptableRecordSkipped`: запись, зашифрованная чужим ключом, пропускается без падения и без потери остальных.
  - `pullDoesNotLoseEqualTimestamps`: `FakeTransport` отдаёт порциями по 2 документа с одинаковым временем, все доходят (Review Focus 3).
- [ ] **Шаг 2:** `swift test --filter SyncEngineTests`: FAIL.
- [ ] **Шаг 3:** реализовать.
- [ ] **Шаг 4:** `swift test`: PASS.
- [ ] **Шаг 5:** коммит «Добавить движок синхронизации».

**Зависит от:** 3, 4.

---

### Задача 6: Вход по почте и согласие

**Цель:** при первом запуске экран входа: почта → код из письма → согласие на обработку данных → дальше знакомство. Сессия сохраняется, есть «Выйти».

**Files:**
- Modify: `project.yml`: пакет `appwrite/sdk-for-apple` (последняя версия), ключи `AppwriteEndpoint` и `AppwriteProjectID` в Info.plist из `Config/App.xcconfig`. Это не секреты: адрес и id проекта видны в приложении.
- Create: `App/OneToOne/Backend/BackendConfig.swift`, `AuthService.swift` (протокол), `AppwriteAuthService.swift`.
- Create: `App/OneToOne/Features/Auth/EmailSignInView.swift`, `CodeEntryView.swift`, `ConsentView.swift`.
- Modify: `App/OneToOne/OneToOneApp.swift`: нет сессии → вход; нет согласия → согласие; нет пары → знакомство; иначе вкладки.
- Modify: `docs/decisions.md`: Appwrite Apple SDK.
- Test: `App/OneToOneTests/SignInFlowTests.swift` (на `FakeAuthService`).

**Interfaces (Produces):**
```swift
protocol AuthService: Sendable {
    func sendCode(to email: String) async throws -> String      // userId для подтверждения
    func confirm(userId: String, code: String) async throws
    func currentUserID() async -> String?
    func signOut() async throws
}
```
Факт согласия и его версия (`consentVersion: Int`, дата) хранятся в настройках аккаунта Appwrite (`account.updatePrefs`), а не в `AppData`.

**Тесты:** `wrongCodeShowsError`, `consentRequiredBeforeOnboarding`, `signedInUserWithCoupleGoesToTabs`. Ручная проверка на сервере из задачи 1: письмо приходит, код подходит, после перезапуска остаёмся в аккаунте.

**Зависит от:** 1. Экранам сервер не нужен (фейк), но для готовности нужен.

---

### Задача 7: Синхронизация в приложении

**Цель:** `AppModel` после каждой правки ставит изменения в очередь и синхронизирует их, а также при запуске, возврате в приложение и раз в минуту, пока приложение открыто. Изменения партнёра появляются на экране.

**Files:**
- Create: `App/OneToOne/Backend/AppwriteTransport.swift` (`SyncTransport` через коллекцию `records`: курсор по `$updatedAt` + `$id`, порции по 100).
- Create: `App/OneToOne/Backend/SyncStateStore.swift` (`SyncState.json` в Application Support, рядом с `AppData.json`).
- Create: `App/OneToOne/AppModel+Sync.swift`: `func startSync(coupleID: String, key: CoupleKey)`, `func syncNow() async`.
- Modify: `App/OneToOne/AppModel.swift`: `update` вызывает `recordLocalChange`.
- Test: `App/OneToOneTests/AppModelSyncTests.swift` (на `FakeTransport` из задачи 5).

**Тесты:** `updateQueuesChange`, `partnerChangeAppearsAfterSync`, `syncFailureKeepsLocalData`. Ручная проверка на двух симуляторах с одним сервером (пару пока создать через консоль Appwrite и общий тестовый ключ из отладочного меню): запись секса на одном появляется на другом меньше чем за минуту, без сети — после включения сети.

**Зависит от:** 2, 5, 6.

---

### Задача 8: Пара и удалённое приглашение

**Цель:** знакомство создаёт пару на сервере и ключ. «Пригласить партнёра» даёт код и ссылку для мессенджера. Партнёр вводит код, оба видят одинаковые 6 цифр, подтверждают, и ключ переходит к нему. Он входит в пару как уже вписанный партнёр (имя можно поправить, пол уже задан).

**Files:**
- Create: `App/OneToOne/Backend/KeychainKeyStore.swift`: `save(_ key: CoupleKey, coupleID: String)`, `load(coupleID:) -> CoupleKey?`, `delete(coupleID:)`.
- Create: `App/OneToOne/Backend/PairingService.swift` (протокол) и `AppwritePairingService.swift`: `createCouple() async throws -> String`, `createInvite(coupleID:) async throws -> (code: String, expiresAt: Date)`, `acceptInvite(code:) async throws -> String`, работа с `keyRequests`.
- Create: `Packages/OneToOneKit/Sources/Sync/Pairing/KeyHandoff.swift`: чистая логика шагов передачи ключа поверх `KeyExchange` с обязательством: `waiting` (запрашивающий опубликовал только `requesterKeyCommitment = SHA-256(свой открытый ключ)`) → `answered` (отвечающий опубликовал свой открытый ключ) → `revealed` (запрашивающий раскрыл открытый ключ; отвечающий проверяет его хэш с обязательством, иначе `rejected`) → оба показывают код и подтверждают → `delivered` (отвечающий выкладывает завёрнутый ключ) или `rejected`. Тесты: `handoffDeliversKeyAfterBothConfirm`, `rejectedHandoffNeverSendsKey`, `expiredRequestIgnored`, `revealNotMatchingCommitmentRejected`, `responderKeyRequiredBeforeReveal` (запрашивающий не раскрывает ключ, пока нет ответа). Поля `keyRequests` — по схеме задачи 2 (`requesterKeyCommitment`, статус `revealed`).
- Create: `App/OneToOne/Features/Pairing/InvitePartnerView.swift`, `JoinCoupleView.swift`, `VerifyCodeView.swift`.
- Modify: `App/OneToOne/AppModel+Onboarding.swift`: после `createCouple` создать пару на сервере и ключ. Если на телефоне уже были записи, загрузить их в пару (**режется вторым**). Тот, кто входит по коду, перед заменой своих записей видит предупреждение.
- Modify: знакомство: предупреждение «Если вы оба потеряете телефоны, записи пропадут».
- Пока партнёр не вошёл, в паре на сервере один человек, и приложение работает полностью. Так и пользуются в одиночку: предупреждение «Если потеряешь телефон, записи пропадут», пригласить можно в любой момент из настроек пары.

**Готово, когда:** на двух симуляторах с разными аккаунтами можно создать пару, пригласить, сверить код и увидеть общие записи. Повторный ввод того же кода → «Приглашение уже использовано». Третий человек с кодом → «В паре уже двое». Ручная проверка Review Focus 4: если подменить `requesterPublicKey` в консоли, коды на экранах разные.

**Зависит от:** 2, 3, 7.

---

### Задача 9: Новый телефон, выход из пары, удаление аккаунта

**Цель:**
- Вход на новом телефоне показывает экран «Попроси партнёра открыть приложение и подтвердить код». Это та же передача ключа, что в задаче 8, с QR-кодом для встречи вживую.
- «Выйти из пары» в настройках пары: функция `leave-couple`, удалить ключ из Keychain, стереть записи пары и `SyncState.json`, вернуть в знакомство.
- «Удалить аккаунт» в настройках: подтверждение, функция `delete-account`, всё стереть, вернуть на вход.

**Files:**
- Create: `App/OneToOne/Features/Pairing/RestoreAccessView.swift`, `App/OneToOne/Features/Settings/AccountSection.swift`.
- Modify: `App/OneToOne/Features/Settings/PairSettingsView.swift`, `App/OneToOne/AppModel+Pair.swift`: `leaveCouple() async throws`, `deleteAccount() async throws`.
- Test: `App/OneToOneTests/LeaveCoupleTests.swift`: `leaveWipesCoupleDataAndKey`, `newCoupleAfterLeaveHasNewKeyAndNoOldRecords` (Review Focus 5).

**Готово, когда:** на симуляторе после удаления приложения, повторной установки и входа записи открываются после подтверждения кода партнёром. После выхода из пары бывший не получает новых записей (проверено на двух симуляторах). Удалённый аккаунт пропадает из консоли Appwrite.

**Зависит от:** 8.

---

### Задача 10: «Войти с Apple» (режется первым)

**Цель:** кнопка «Войти с Apple» на экране входа, нативный вход: токен Apple обменивается на сессию Appwrite.

**Files:**
- Modify: `project.yml`: возможность Sign in with Apple.
- Modify: `App/OneToOne/Backend/AuthService.swift`, `AppwriteAuthService.swift`: `func signInWithApple(idToken: String) async throws`.
- Modify: `App/OneToOne/Features/Auth/EmailSignInView.swift`.
- Руками: в Apple Developer включить Sign in with Apple для `com.docomoz.onetoone`; в Appwrite включить Apple и вписать bundle id.

**Готово, когда:** на устройстве вход с Apple создаёт аккаунт. Повторный вход попадает в тот же аккаунт. Согласие показывается так же, как при входе по почте.

**Зависит от:** 6, подписка Apple Developer.

---

### Задача 11: Юридическое и подготовка к App Store

**Цель:** всё, без чего нельзя публиковать.

**Files:**
- Create: `docs/legal/privacy-policy.md` и `docs/legal/consent.md`: черновики для юриста (что собираем, где храним — Россия, Timeweb; что зашифровано и недоступно нам; особая категория данных; как удалить аккаунт; контакты оператора).
- Create: `docs/release.md`: чек-лист публикации: страна только Россия, анкета конфиденциальности App Store, ответ про шифрование (`ITSAppUsesNonExemptEncryption` и самоклассификация), скриншоты, возрастной рейтинг, вопросы юристу (152-ФЗ, уведомление в Роскомнадзор, «организатор распространения информации»).
- Modify: `project.yml`: `ITSAppUsesNonExemptEncryption` по итогам ответа в чек-листе.
- Руками: политика опубликована по адресу на нашем домене, ссылка вставлена в `ConsentView` и в App Store Connect.

**Готово, когда:** черновики отправлены юристу; решение Максима «публикуем до ответа юриста или после» записано в `docs/decisions.md`; чек-лист `docs/release.md` пройден, кроме пунктов, ждущих юриста.

**Зависит от:** ничего (тексты), 6 (ссылка в приложении).

---

## После плана

- Задачи #24, #25, #26 закрываются со ссылкой на новые. Раздел «Синхронизация» в `docs/plan.md` заменяется ссылкой на этот план.
- В `docs/decisions.md` новая строка: свой сервер Appwrite в Timeweb со сквозным шифрованием вместо iCloud, с причиной. Старые строки про iCloud и `CKSyncEngine` помечаются «заменено (2026-10-11)».
