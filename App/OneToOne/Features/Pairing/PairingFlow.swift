import Core
import Foundation
import Observation
import OSLog
import Sync

/// Шаг передачи ключа на экране сверки кода.
enum HandoffStep: Equatable {
    /// Ждём второй телефон.
    case waiting
    /// Оба телефона показывают этот код, человек сверяет.
    case verify(code: String)
    /// Этот подтвердил, ждём партнёра.
    case waitingForPartner
    case done
    case failed(PairingError)
}

/// Пара на сервере: создание, приглашение, вход по коду и передача ключа.
/// Экраны только показывают состояние и зовут методы; данные пары меняет `AppModel`.
///
/// Создатель: знакомство → `coupleCreated` (пара на сервере, ключ в Keychain, синхронизация) → приглашение →
/// `checkIncoming`/`pollIncoming` отвечают на запрос ключа → сверка кода → `confirmIncoming` отдаёт ключ.
/// Вошедший по коду: `join` → `pollJoin` раскрывает ключ после ответа → сверка → `confirmJoin` → ключ получен,
/// свои записи заменены записями пары, своя пара без партнёра покинута → выбирает себя в паре (`awaitsProfile`).
/// Новый телефон (`PairingFlow+Account`): вход → `prepareAccount` находит пару на сервере → ключа нет —
/// `restoringCoupleID`, тот же запрос ключа, что у вошедшего по коду → выбирает себя в паре.
@Observable @MainActor
final class PairingFlow {
    // Состояние меняют только методы этого класса (в том числе из файлов-расширений PairingFlow+…),
    // экраны его только читают.

    /// Пара этого телефона (id команды Appwrite). Пишется в `PairingDefaults`.
    var coupleID: String? { didSet { defaults.coupleID = coupleID } }
    var isCoupleOnServer: Bool { didSet { defaults.isCoupleOnServer = isCoupleOnServer } }
    /// Вошли по коду, ключ ещё не получили.
    var joiningCoupleID: String? { didSet { defaults.joiningCoupleID = joiningCoupleID } }
    var partnerJoined: Bool { didSet { defaults.partnerJoined = partnerJoined } }
    /// Партнёр был в паре и вышел (узнали в `refreshPartnerJoined`).
    var partnerLeft = false
    /// Пара на сервере есть, а ключа на этом телефоне нет (переустановка, новый телефон): просим ключ у партнёра.
    /// После перезапуска находится заново: `coupleID` есть, ключа нет.
    var restoringCoupleID: String?
    /// Чьи данные на телефоне и проверили ли пару на сервере (`PairingFlow+Account`).
    var accountState = AccountState.checking

    var invite: InviteCode?
    var errorMessage: String?
    var isWorking = false
    /// Передача ключа на этот телефон (вошли по коду).
    var joinStep: HandoffStep?
    /// Передача ключа с этого телефона партнёру.
    var incomingStep: HandoffStep?
    /// Показать приглашение сразу после знакомства.
    var presentsInvite = false
    /// Открыт экран приглашения: сверка идёт на нём, а не в отдельном окне поверх.
    var isInviteScreenVisible = false

    @ObservationIgnored let model: AppModel
    @ObservationIgnored let service: any PairingService
    @ObservationIgnored let keys: any CoupleKeyStoring
    @ObservationIgnored let defaults: PairingDefaults
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored private let makeTransport: @Sendable () -> any SyncTransport

    // Передача ключа идёт, пока открыт экран; после перезапуска начинается заново новым запросом.
    @ObservationIgnored var requester: KeyHandoffRequester?
    @ObservationIgnored var joinRequestID: String?
    @ObservationIgnored var responder: KeyHandoffResponder?
    @ObservationIgnored var incomingRequestID: String?
    /// Запросы, на которые ответил другой телефон с ключом: на них больше не отвечаем.
    @ObservationIgnored var answeredElsewhere: Set<String> = []
    /// Опрос сервера из таймера и с экрана может прийти одновременно: шаг передачи ключа идёт один.
    @ObservationIgnored var isPolling = false
    /// Идущая попытка создать пару на сервере: её ждут все, кто зовёт `registerCouple`.
    @ObservationIgnored var registration: Task<PairingError?, Never>?

    init(model: AppModel, service: any PairingService, keys: any CoupleKeyStoring = KeychainKeyStore(),
         defaults: PairingDefaults = PairingDefaults(), now: @escaping () -> Date = Date.init,
         makeTransport: @escaping @Sendable () -> any SyncTransport = { AppwriteTransport() }) {
        self.model = model
        self.service = service
        self.keys = keys
        self.defaults = defaults
        self.now = now
        self.makeTransport = makeTransport
        coupleID = defaults.coupleID
        isCoupleOnServer = defaults.isCoupleOnServer
        joiningCoupleID = defaults.joiningCoupleID
        partnerJoined = defaults.partnerJoined
    }

    /// Пара на сервере и ключ есть, а кто я в ней — нет: вошли по коду и ждём профиль пары или выбор себя.
    var awaitsProfile: Bool {
        isCoupleOnServer && coupleID != nil && joiningCoupleID == nil && restoringCoupleID == nil && !model.data.isPaired
    }

    /// Для какой пары этот телефон просит ключ: вошёл по коду или восстанавливает доступ.
    var keyRequestCoupleID: String? {
        joiningCoupleID ?? restoringCoupleID
    }

    /// Ключ пары этого телефона.
    var coupleKey: CoupleKey? {
        coupleID.flatMap { keys.load(coupleID: $0) }
    }

    // MARK: - Создание пары и запуск синхронизации

    /// Знакомство закончено: пара на сервере, синхронизация, приглашение партнёра.
    /// Ошибку здесь не показываем: экран приглашения сам попробует ещё раз и покажет, что не так.
    func coupleCreated() async {
        presentsInvite = true
        await registerCouple(quietly: true)
        await model.syncNow()
    }

    /// При запуске и раз в минуту, пока приложение открыто: дожать то, что не получилось без сети,
    /// и запустить синхронизацию. Для уже запущенной пары `startSync` ничего не делает.
    func prepareSync() async {
        await leaveOldCouples()
        if let coupleID, isCoupleOnServer, let key = keys.load(coupleID: coupleID) {
            model.startSync(coupleID: coupleID, key: key, transport: makeTransport())
        } else if model.data.isPaired, joiningCoupleID == nil {
            // В фоне: ошибку не показываем, экран может быть любым. Повторим через минуту.
            await registerCouple(quietly: true)
        }
    }

    /// Создаёт пару на сервере для пары из знакомства. Id и ключ появляются до вызова сервера и сохраняются:
    /// повтор после ошибки или потерянного ответа идёт с ними же, и вторая пара не появляется.
    /// Одновременные вызовы (знакомство, экран приглашения, таймер) ждут одну и ту же попытку.
    /// `quietly` — фоновая попытка: без текста ошибки на экране.
    func registerCouple(quietly: Bool = false) async {
        // Пара уже на сервере. Если ключа нет, новый не придумываем: у партнёра старый (восстановление — #86).
        guard !isCoupleOnServer else {
            startSyncIfReady()
            return
        }
        let attempt = registration ?? Task { await self.createCoupleOnServer() }
        registration = attempt
        let error = await attempt.value
        if registration == attempt { registration = nil }
        if !quietly { errorMessage = error?.message }
    }

    /// Одна попытка создать пару на сервере. Возвращает ошибку или `nil`, если получилось.
    private func createCoupleOnServer() async -> PairingError? {
        let id = coupleID ?? Self.newCoupleID()
        if keys.load(coupleID: id) == nil {
            do {
                try keys.save(CoupleKey(), coupleID: id)
            } catch {
                Self.log.error("Ключ пары не сохранился в Keychain: \(error)")
                return .server
            }
        }
        coupleID = id
        do {
            _ = try await service.createCouple(coupleID: id)
        } catch {
            Self.log.error("Пара на сервере не создалась: \(error)")
            return Self.pairingError(error)
        }
        // Пока ждали сервер, телефон мог войти в пару партнёра: эту, свою, тогда покидаем.
        guard coupleID == id else {
            defaults.couplesToLeave.append(id)
            return nil
        }
        isCoupleOnServer = true
        startSyncIfReady()
        return nil
    }

    func startSyncIfReady() {
        guard let coupleID, isCoupleOnServer, let key = keys.load(coupleID: coupleID) else { return }
        model.startSync(coupleID: coupleID, key: key, transport: makeTransport())
    }

    /// Свои пары без партнёра после входа в пару партнёра: выйти на сервере и забыть их ключи.
    /// Без сети не выйдет — повторим при следующем `prepareSync`.
    func leaveOldCouples() async {
        for old in defaults.couplesToLeave {
            do {
                try await service.leaveCouple(coupleID: old)
            } catch PairingError.notMember {
                // Уже вышли.
            } catch {
                Self.log.error("Не удалось выйти из старой пары, повторим позже: \(error)")
                continue
            }
            keys.delete(coupleID: old)
            defaults.couplesToLeave.removeAll { $0 == old }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    /// Запрос к серверу с крутилкой: ошибку превращаем в текст для экрана.
    func perform(_ action: () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        do {
            try await action()
        } catch {
            errorMessage = Self.pairingError(error).message
        }
        isWorking = false
    }

    static func pairingError(_ error: Error) -> PairingError {
        switch error {
        case let error as PairingError: error
        case let error as KeyHandoffError: PairingError(error)
        default: .network
        }
    }

    /// Id пары для Appwrite: 32 hex-цифры (до 36 символов, без спецсимволов в начале).
    static func newCoupleID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    static let log = Logger(subsystem: "com.docomoz.onetoone", category: "Pairing")
}
