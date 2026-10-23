import Core
import Foundation
import Sync
import Testing
@testable import OneToOne

// Общее для тестов пары: телефоны и серверы в памяти.

let pairingToday = DayKey(year: 2026, month: 10, day: 11)
let pairingAdult = DayKey(year: 1996, month: 5, day: 12)

/// Один телефон: данные, ключи, настройки пары и сеть до общих фейковых серверов.
@MainActor
struct Phone {
    let model: AppModel
    let flow: PairingFlow
    let keys: InMemoryKeyStore
    let defaults: PairingDefaults
    let service: FakePairingService
    /// Сеть до сервера записей: `transport.isOffline = true` выключает её.
    let transport: FakeSyncTransport

    /// `keys` — Keychain: переживает удаление приложения, поэтому новый «телефон» после переустановки берёт старый.
    init(user: String, pairing: FakePairingServer, sync: FakeSyncServer, data: AppData = AppData(),
         keys: InMemoryKeyStore = InMemoryKeyStore()) {
        model = AppModel(store: InMemoryStore(data))
        model.autoSyncDelay = nil
        self.keys = keys
        defaults = PairingDefaults(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        service = FakePairingService(server: pairing, userID: user)
        let transport = FakeSyncTransport(server: sync)
        self.transport = transport
        flow = PairingFlow(model: model, service: service, keys: keys, defaults: defaults,
                           makeTransport: { transport })
    }
}

/// Двое и общие серверы. Аня создаёт пару в знакомстве, Боря войдёт по коду.
@MainActor
struct Couple2 {
    let pairing = FakePairingServer()
    let sync = FakeSyncServer()
    let anya: Phone
    let borya: Phone

    init(boryaData: AppData = AppData(), anyaEntries: [SexEntry] = []) throws {
        anya = Phone(user: "anya", pairing: pairing, sync: sync)
        borya = Phone(user: "borya", pairing: pairing, sync: sync, data: boryaData)
        try anya.model.createCouple(me: PersonDraft(sex: .female, name: "Аня", birthDate: pairingAdult),
                                     partner: PersonDraft(sex: .male, name: "Боря", birthDate: pairingAdult), today: pairingToday)
        for entry in anyaEntries { anya.model.update { $0.sexEntries.append(entry) } }
    }

    /// Аня зарегистрировала пару и пригласила, Боря ввёл код, телефоны дошли до показа кода.
    func untilCodes() async throws -> (anyaCode: String, boryaCode: String) {
        // Как в знакомстве: пара на сервере и первая синхронизация, записи Ани уходят в пару.
        await anya.flow.coupleCreated()
        await anya.flow.createInvite()
        let code = try #require(anya.flow.invite?.code)
        await borya.flow.join(code: code)
        await anya.flow.checkIncoming()
        await borya.flow.pollJoin()
        await anya.flow.pollIncoming()
        guard case .verify(let anyaCode) = anya.flow.incomingStep,
              case .verify(let boryaCode) = borya.flow.joinStep
        else {
            Issue.record("Нет кода: \(String(describing: anya.flow.incomingStep)) / \(String(describing: borya.flow.joinStep))")
            throw CancellationError()
        }
        return (anyaCode, boryaCode)
    }

    /// Оба подтвердили код: ключ переходит к Боре.
    func confirmBoth() async {
        await borya.flow.confirmJoin()
        await anya.flow.confirmIncoming()
        await borya.flow.pollJoin()
    }

    /// Пара готова: ключ у обоих, Боря выбрал себя, записи на обоих телефонах.
    func paired() async throws {
        _ = try await untilCodes()
        await anya.model.syncNow()
        await confirmBoth()
        anya.flow.dismissIncoming()
        let placeholder = try #require(borya.model.data.couple?.man)
        try borya.model.claimPerson(PersonDraft(id: placeholder.id, sex: .male, name: placeholder.name,
                                                birthDate: placeholder.birthDate), today: pairingToday)
        await borya.model.syncNow()
        await anya.model.syncNow()
    }

    var coupleID: String {
        get throws { try #require(anya.defaults.coupleID) }
    }
}

