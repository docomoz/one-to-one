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

/// Двое и общие серверы. Даша создаёт пару в знакомстве, Максим войдёт по коду.
@MainActor
struct Couple2 {
    let pairing = FakePairingServer()
    let sync = FakeSyncServer()
    let dasha: Phone
    let maxim: Phone

    init(maximData: AppData = AppData(), dashaEntries: [SexEntry] = []) throws {
        dasha = Phone(user: "dasha", pairing: pairing, sync: sync)
        maxim = Phone(user: "maxim", pairing: pairing, sync: sync, data: maximData)
        try dasha.model.createCouple(me: PersonDraft(sex: .female, name: "Даша", birthDate: pairingAdult),
                                     partner: PersonDraft(sex: .male, name: "Максим", birthDate: pairingAdult), today: pairingToday)
        for entry in dashaEntries { dasha.model.update { $0.sexEntries.append(entry) } }
    }

    /// Даша зарегистрировала пару и пригласила, Максим ввёл код, телефоны дошли до показа кода.
    func untilCodes() async throws -> (dashaCode: String, maximCode: String) {
        // Как в знакомстве: пара на сервере и первая синхронизация, записи Даши уходят в пару.
        await dasha.flow.coupleCreated()
        await dasha.flow.createInvite()
        let code = try #require(dasha.flow.invite?.code)
        await maxim.flow.join(code: code)
        await dasha.flow.checkIncoming()
        await maxim.flow.pollJoin()
        await dasha.flow.pollIncoming()
        guard case .verify(let dashaCode) = dasha.flow.incomingStep,
              case .verify(let maximCode) = maxim.flow.joinStep
        else {
            Issue.record("Нет кода: \(String(describing: dasha.flow.incomingStep)) / \(String(describing: maxim.flow.joinStep))")
            throw CancellationError()
        }
        return (dashaCode, maximCode)
    }

    /// Оба подтвердили код: ключ переходит к Максиму.
    func confirmBoth() async {
        await maxim.flow.confirmJoin()
        await dasha.flow.confirmIncoming()
        await maxim.flow.pollJoin()
    }

    /// Пара готова: ключ у обоих, Максим выбрал себя, записи на обоих телефонах.
    func paired() async throws {
        _ = try await untilCodes()
        await dasha.model.syncNow()
        await confirmBoth()
        dasha.flow.dismissIncoming()
        let placeholder = try #require(maxim.model.data.couple?.man)
        try maxim.model.claimPerson(PersonDraft(id: placeholder.id, sex: .male, name: placeholder.name,
                                                birthDate: placeholder.birthDate), today: pairingToday)
        await maxim.model.syncNow()
        await dasha.model.syncNow()
    }

    var coupleID: String {
        get throws { try #require(dasha.defaults.coupleID) }
    }
}

