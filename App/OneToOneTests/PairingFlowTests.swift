import Core
import Foundation
import Sync
import Testing
@testable import OneToOne

private let today = DayKey(year: 2026, month: 10, day: 11)
private let adult = DayKey(year: 1996, month: 5, day: 12)

/// Один телефон: данные, ключи, настройки пары и сеть до общих фейковых серверов.
@MainActor
private struct Phone {
    let model: AppModel
    let flow: PairingFlow
    let keys: InMemoryKeyStore
    let defaults: PairingDefaults
    let service: FakePairingService

    init(user: String, pairing: FakePairingServer, sync: FakeSyncServer, data: AppData = AppData()) {
        model = AppModel(store: InMemoryStore(data))
        model.autoSyncDelay = nil
        keys = InMemoryKeyStore()
        defaults = PairingDefaults(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        service = FakePairingService(server: pairing, userID: user)
        flow = PairingFlow(model: model, service: service, keys: keys, defaults: defaults,
                           makeTransport: { FakeSyncTransport(server: sync) })
    }
}

/// Двое и общие серверы. Даша создаёт пару в знакомстве, Максим войдёт по коду.
@MainActor
private struct Couple2 {
    let pairing = FakePairingServer()
    let sync = FakeSyncServer()
    let dasha: Phone
    let maxim: Phone

    init(maximData: AppData = AppData(), dashaEntries: [SexEntry] = []) throws {
        dasha = Phone(user: "dasha", pairing: pairing, sync: sync)
        maxim = Phone(user: "maxim", pairing: pairing, sync: sync, data: maximData)
        try dasha.model.createCouple(me: PersonDraft(sex: .female, name: "Даша", birthDate: adult),
                                     partner: PersonDraft(sex: .male, name: "Максим", birthDate: adult), today: today)
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
}

private func sexEntry(_ day: Int) -> SexEntry {
    SexEntry(day: DayKey(year: 2026, month: 10, day: day), types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, createdBy: UUID())
}

// MARK: - Создание пары

@MainActor
@Test func createdCoupleRegistersOnServerAndStartsSync() async throws {
    let couple = try Couple2()

    await couple.dasha.flow.registerCouple()

    let coupleID = try #require(couple.dasha.defaults.coupleID)
    #expect(couple.dasha.defaults.isCoupleOnServer)
    #expect(couple.pairing.members(coupleID) == ["dasha"])
    #expect(couple.dasha.keys.load(coupleID: coupleID) != nil)
    #expect(couple.dasha.model.isSyncStarted)
}

@MainActor
@Test func registerRetryKeepsCoupleIDAndKey() async throws {
    let couple = try Couple2()
    couple.dasha.service.failure.withLock { $0 = .network }

    await couple.dasha.flow.registerCouple()

    #expect(couple.dasha.flow.errorMessage == PairingError.network.message)
    #expect(!couple.dasha.defaults.isCoupleOnServer)
    #expect(!couple.dasha.model.isSyncStarted)
    let coupleID = try #require(couple.dasha.defaults.coupleID)
    let key = try #require(couple.dasha.keys.load(coupleID: coupleID))

    await couple.dasha.flow.registerCouple()

    #expect(couple.dasha.defaults.coupleID == coupleID)
    #expect(couple.dasha.keys.load(coupleID: coupleID) == key)
    #expect(couple.dasha.defaults.isCoupleOnServer)
    #expect(couple.dasha.flow.errorMessage == nil)
}

@MainActor
@Test func backgroundRegistrationRetriesSilently() async throws {
    // Пару создали без сети: раз в минуту пробуем снова, ошибку на экран не выводим.
    let couple = try Couple2()
    couple.dasha.service.failure.withLock { $0 = .network }

    await couple.dasha.flow.prepareSync()

    #expect(couple.dasha.flow.errorMessage == nil)
    #expect(!couple.dasha.flow.isWorking)
    #expect(!couple.dasha.defaults.isCoupleOnServer)

    await couple.dasha.flow.prepareSync()

    #expect(couple.dasha.defaults.isCoupleOnServer)
    #expect(couple.dasha.model.isSyncStarted)
}

@MainActor
@Test func launchStartsSyncWithStoredKey() async throws {
    let couple = try Couple2()
    await couple.dasha.flow.registerCouple()
    let coupleID = try #require(couple.dasha.defaults.coupleID)
    // Перезапуск: новый AppModel и PairingFlow на тех же Keychain и настройках.
    let model = AppModel(store: InMemoryStore(couple.dasha.model.data))
    let flow = PairingFlow(model: model, service: couple.dasha.service, keys: couple.dasha.keys,
                           defaults: couple.dasha.defaults, makeTransport: { FakeSyncTransport(server: couple.sync) })

    await flow.prepareSync()

    #expect(model.isSyncStarted)
    #expect(model.syncCoupleID == coupleID)
}

// MARK: - Передача ключа

@MainActor
@Test func inviteDeliversKeyAfterBothConfirm() async throws {
    let couple = try Couple2()
    let (dashaCode, maximCode) = try await couple.untilCodes()
    #expect(dashaCode == maximCode)

    // Даша подтвердила, Максим ещё нет: ключ он не берёт.
    await couple.dasha.flow.confirmIncoming()
    await couple.maxim.flow.pollJoin()
    #expect(couple.maxim.defaults.isCoupleOnServer == false)

    await couple.maxim.flow.confirmJoin()

    let coupleID = try #require(couple.dasha.defaults.coupleID)
    #expect(couple.maxim.defaults.coupleID == coupleID)
    #expect(couple.maxim.keys.load(coupleID: coupleID) == couple.dasha.keys.load(coupleID: coupleID))
    #expect(couple.maxim.flow.joinStep == .done)
    #expect(couple.dasha.flow.incomingStep == .done)
    #expect(couple.maxim.model.syncCoupleID == coupleID)
}

@MainActor
@Test func rejectedCodeNeverDeliversKey() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()

    await couple.dasha.flow.rejectIncoming()
    await couple.maxim.flow.confirmJoin()

    #expect(couple.pairing.requests.allSatisfy { $0.wrappedKey == nil && $0.status == .rejected })
    #expect(couple.maxim.flow.joinStep == .failed(.rejected))
    #expect(couple.maxim.defaults.coupleID == nil)
}

@MainActor
@Test func joinerRejectingStopsResponder() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()

    await couple.maxim.flow.rejectJoin()
    await couple.dasha.flow.confirmIncoming()

    #expect(couple.pairing.requests.allSatisfy { $0.wrappedKey == nil })
    #expect(couple.dasha.flow.incomingStep == .failed(.rejected))
}

@MainActor
@Test func tamperedRevealIsRejectedByResponder() async throws {
    // Сервер подменяет раскрытый ключ Максима, когда строку читает Даша: код ей не показывается.
    let couple = try Couple2()
    let fake = KeyExchangePair().publicKey
    couple.pairing.tamper.withLock {
        $0 = { request, reader in
            var request = request
            if reader == "dasha", request.requesterPublicKey != nil { request.requesterPublicKey = fake }
            return request
        }
    }
    await couple.dasha.flow.registerCouple()
    await couple.dasha.flow.createInvite()
    await couple.maxim.flow.join(code: try #require(couple.dasha.flow.invite?.code))
    await couple.dasha.flow.checkIncoming()
    await couple.maxim.flow.pollJoin()

    await couple.dasha.flow.pollIncoming()

    #expect(couple.dasha.flow.incomingStep == .failed(.keyMismatch))
    #expect(couple.pairing.requests.allSatisfy { $0.status == .rejected && $0.wrappedKey == nil })
}

@MainActor
@Test func expiredRequestIsNotAnswered() async throws {
    let couple = try Couple2()
    await couple.dasha.flow.registerCouple()
    await couple.dasha.flow.createInvite()
    await couple.maxim.flow.join(code: try #require(couple.dasha.flow.invite?.code))
    couple.pairing.state.withLock { state in
        for id in state.requests.keys { state.requests[id]?.expiresAt = .distantPast }
    }

    await couple.dasha.flow.checkIncoming()

    #expect(couple.dasha.flow.incomingStep == nil)
    #expect(couple.pairing.requests.allSatisfy { $0.status == .waiting })
}

// MARK: - Записи

@MainActor
@Test func creatorRecordsReachJoinerAndJoinerOwnRecordsStayOff() async throws {
    // У Максима на телефоне были свои записи. После входа в пару у него записи Даши, его — нигде.
    var maximData = AppData()
    maximData.sexEntries = [sexEntry(1)]
    let dashaEntry = sexEntry(5)
    let couple = try Couple2(maximData: maximData, dashaEntries: [dashaEntry])
    _ = try await couple.untilCodes()
    await couple.dasha.model.syncNow()

    await couple.confirmBoth()

    #expect(couple.maxim.model.data.sexEntries == [dashaEntry])
    #expect(couple.maxim.model.data.couple == couple.dasha.model.data.couple)
    #expect(couple.maxim.model.data.meID == nil, "кто он в паре, Максим выберет сам")
    await couple.dasha.model.syncNow()
    #expect(couple.dasha.model.data.sexEntries == [dashaEntry])
}

@MainActor
@Test func soloJoinerLeavesOldCoupleAndForgetsItsKey() async throws {
    // Максим пользовался приложением один: у него своя пара на сервере.
    let couple = try Couple2()
    try couple.maxim.model.createCouple(me: PersonDraft(sex: .male, name: "Макс", birthDate: adult),
                                        partner: PersonDraft(sex: .female, name: "Д.", birthDate: adult), today: today)
    await couple.maxim.flow.registerCouple()
    let oldID = try #require(couple.maxim.defaults.coupleID)
    _ = try await couple.untilCodes()

    await couple.confirmBoth()

    #expect(couple.pairing.left.contains { $0 == (oldID, "maxim") })
    #expect(couple.maxim.keys.load(coupleID: oldID) == nil)
    #expect(couple.maxim.defaults.coupleID == couple.dasha.defaults.coupleID)
    #expect(couple.maxim.defaults.coupleToLeave == nil)
    #expect(couple.maxim.model.data.couple == couple.dasha.model.data.couple)
}

@MainActor
@Test func joinerClaimsPartnerPlaceholderKeepingSex() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()
    await couple.dasha.model.syncNow()
    await couple.confirmBoth()
    let placeholder = try #require(couple.maxim.model.data.couple?.man)
    #expect(couple.maxim.flow.awaitsProfile)

    try couple.maxim.model.claimPerson(
        PersonDraft(id: placeholder.id, sex: .male, name: "Максим Б.", birthDate: placeholder.birthDate), today: today)

    #expect(couple.maxim.model.data.meID == placeholder.id)
    #expect(couple.maxim.model.data.couple?.man.name == "Максим Б.")
    #expect(couple.maxim.model.data.couple?.man.sex == .male)
    #expect(couple.maxim.model.data.isPaired)
    #expect(!couple.maxim.flow.awaitsProfile)
}

// MARK: - Ошибки

@MainActor
@Test func usedCodeAndFullCoupleShowErrors() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()
    let used = "CODE1AB"
    let third = Phone(user: "vera", pairing: couple.pairing, sync: couple.sync)

    await third.flow.join(code: used)

    #expect(third.flow.errorMessage == PairingError.inviteNotFound.message)
    #expect(third.defaults.joiningCoupleID == nil)
}

@Test func functionErrorsMapToMessages() {
    #expect(PairingError(functionError: "invite_not_found", status: 404) == .inviteNotFound)
    #expect(PairingError(functionError: "couple_full", status: 409) == .coupleFull)
    #expect(PairingError(functionError: "already_paired", status: 409) == .alreadyPaired)
    #expect(PairingError(functionError: "invite_expired", status: 410) == .inviteExpired)
    #expect(PairingError(functionError: nil, status: 401) == .signedOut)
    #expect(PairingError(functionError: "server_error", status: 500) == .server)
    #expect(PairingError.coupleFull.message == "В паре уже двое.")
    #expect(PairingError.inviteNotFound.message.hasPrefix("Приглашение уже использовано"))
}

@Test func inviteCodeInputIsNormalized() {
    #expect(PairingFlow.normalizedCode(" abcd-2345 ") == "ABCD2345")
    #expect(PairingFlow.formattedCode("ABCD2345") == "ABCD-2345")
}
