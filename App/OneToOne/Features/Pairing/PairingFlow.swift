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
    /// Опрос сервера из таймера и с экрана может прийти одновременно: шаг передачи ключа идёт один.
    @ObservationIgnored var isPolling = false

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
        isCoupleOnServer && coupleID != nil && joiningCoupleID == nil && !model.data.isPaired
    }

    /// Ключ пары этого телефона.
    var coupleKey: CoupleKey? {
        coupleID.flatMap { keys.load(coupleID: $0) }
    }

    // MARK: - Создание пары и запуск синхронизации

    /// Знакомство закончено: пара на сервере, синхронизация, приглашение партнёра.
    func coupleCreated() async {
        presentsInvite = true
        await registerCouple()
        await model.syncNow()
    }

    /// При запуске и раз в минуту, пока приложение открыто: дожать то, что не получилось без сети,
    /// и запустить синхронизацию. Для уже запущенной пары `startSync` ничего не делает.
    func prepareSync() async {
        await leaveOldCouple()
        if let coupleID, isCoupleOnServer, let key = keys.load(coupleID: coupleID) {
            model.startSync(coupleID: coupleID, key: key, transport: makeTransport())
        } else if model.data.isPaired, joiningCoupleID == nil {
            // В фоне: ошибку не показываем, экран может быть любым. Повторим через минуту.
            await registerCouple(quietly: true)
        }
    }

    /// Создаёт пару на сервере для пары из знакомства. Id и ключ появляются до вызова сервера и сохраняются:
    /// повтор после ошибки или потерянного ответа идёт с ними же, и вторая пара не появляется.
    /// `quietly` — фоновая попытка: без крутилки и без текста ошибки на экране.
    func registerCouple(quietly: Bool = false) async {
        // Пара уже на сервере. Если ключа нет, новый не придумываем: у партнёра старый (восстановление — #86).
        guard !isCoupleOnServer else {
            startSyncIfReady()
            return
        }
        let id = coupleID ?? Self.newCoupleID()
        if keys.load(coupleID: id) == nil {
            do {
                try keys.save(CoupleKey(), coupleID: id)
            } catch {
                Self.log.error("Ключ пары не сохранился в Keychain: \(error)")
                if !quietly { errorMessage = PairingError.server.message }
                return
            }
        }
        coupleID = id
        let create = {
            _ = try await self.service.createCouple(coupleID: id)
            self.isCoupleOnServer = true
            self.startSyncIfReady()
        }
        if quietly {
            do { try await create() } catch { Self.log.error("Пара на сервере не создалась, повторим: \(error)") }
        } else {
            await perform(create)
        }
    }

    func startSyncIfReady() {
        guard let coupleID, isCoupleOnServer, let key = keys.load(coupleID: coupleID) else { return }
        model.startSync(coupleID: coupleID, key: key, transport: makeTransport())
    }

    /// Своя пара без партнёра после входа в пару партнёра: выйти на сервере и забыть её ключ.
    /// Без сети не выйдет — повторим при следующем `prepareSync`.
    func leaveOldCouple() async {
        guard let old = defaults.coupleToLeave else { return }
        do {
            try await service.leaveCouple(coupleID: old)
        } catch PairingError.notMember {
            // Уже вышли.
        } catch {
            Self.log.error("Не удалось выйти из старой пары, повторим позже: \(error)")
            return
        }
        keys.delete(coupleID: old)
        defaults.coupleToLeave = nil
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
