import Core
import Foundation
import Sync
import Testing
@testable import OneToOne

private let today = DayKey(year: 2026, month: 10, day: 11)
private let adult = DayKey(year: 1996, month: 5, day: 12)

private func sexEntry(_ day: Int) -> SexEntry {
    SexEntry(day: DayKey(year: 2026, month: 10, day: day), types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, createdBy: UUID())
}

// MARK: - Создание пары

@MainActor
@Test func createdCoupleRegistersOnServerAndStartsSync() async throws {
    let couple = try Couple2()

    await couple.anya.flow.registerCouple()

    let coupleID = try #require(couple.anya.defaults.coupleID)
    #expect(couple.anya.defaults.isCoupleOnServer)
    #expect(couple.pairing.members(coupleID) == ["anya"])
    #expect(couple.anya.keys.load(coupleID: coupleID) != nil)
    #expect(couple.anya.model.isSyncStarted)
}

@MainActor
@Test func registerRetryKeepsCoupleIDAndKey() async throws {
    let couple = try Couple2()
    couple.anya.service.failure.withLock { $0 = .network }

    await couple.anya.flow.registerCouple()

    #expect(couple.anya.flow.errorMessage == PairingError.network.message)
    #expect(!couple.anya.defaults.isCoupleOnServer)
    #expect(!couple.anya.model.isSyncStarted)
    let coupleID = try #require(couple.anya.defaults.coupleID)
    let key = try #require(couple.anya.keys.load(coupleID: coupleID))

    await couple.anya.flow.registerCouple()

    #expect(couple.anya.defaults.coupleID == coupleID)
    #expect(couple.anya.keys.load(coupleID: coupleID) == key)
    #expect(couple.anya.defaults.isCoupleOnServer)
    #expect(couple.anya.flow.errorMessage == nil)
}

@MainActor
@Test func backgroundRegistrationRetriesSilently() async throws {
    // Пару создали без сети: раз в минуту пробуем снова, ошибку на экран не выводим.
    let couple = try Couple2()
    couple.anya.service.failure.withLock { $0 = .network }

    await couple.anya.flow.prepareSync()

    #expect(couple.anya.flow.errorMessage == nil)
    #expect(!couple.anya.flow.isWorking)
    #expect(!couple.anya.defaults.isCoupleOnServer)

    await couple.anya.flow.prepareSync()

    #expect(couple.anya.defaults.isCoupleOnServer)
    #expect(couple.anya.model.isSyncStarted)
}

@MainActor
@Test func inviteRightAfterOnboardingWaitsForRegistration() async throws {
    // Знакомство создаёт пару на сервере, а экран приглашения в это же время просит код.
    let couple = try Couple2()
    couple.anya.service.latency.withLock { $0 = .milliseconds(50) }

    async let created: Void = couple.anya.flow.coupleCreated()
    async let invited: Void = couple.anya.flow.createInvite()
    _ = await (created, invited)

    #expect(couple.anya.flow.invite != nil)
    #expect(couple.anya.flow.errorMessage == nil)
    #expect(couple.pairing.state.withLock { $0.teams.count } == 1)
}

@MainActor
@Test func launchStartsSyncWithStoredKey() async throws {
    let couple = try Couple2()
    await couple.anya.flow.registerCouple()
    let coupleID = try #require(couple.anya.defaults.coupleID)
    // Перезапуск: новый AppModel и PairingFlow на тех же Keychain и настройках.
    let model = AppModel(store: InMemoryStore(couple.anya.model.data))
    let flow = PairingFlow(model: model, service: couple.anya.service, keys: couple.anya.keys,
                           defaults: couple.anya.defaults, makeTransport: { FakeSyncTransport(server: couple.sync) })

    await flow.prepareSync()

    #expect(model.isSyncStarted)
    #expect(model.syncCoupleID == coupleID)
}

// MARK: - Передача ключа

@MainActor
@Test func inviteDeliversKeyAfterBothConfirm() async throws {
    let couple = try Couple2()
    let (anyaCode, boryaCode) = try await couple.untilCodes()
    #expect(anyaCode == boryaCode)

    // Аня подтвердила, Боря ещё нет: ключ он не берёт.
    await couple.anya.flow.confirmIncoming()
    await couple.borya.flow.pollJoin()
    #expect(couple.borya.defaults.isCoupleOnServer == false)

    await couple.borya.flow.confirmJoin()

    let coupleID = try #require(couple.anya.defaults.coupleID)
    #expect(couple.borya.defaults.coupleID == coupleID)
    #expect(couple.borya.keys.load(coupleID: coupleID) == couple.anya.keys.load(coupleID: coupleID))
    #expect(couple.borya.flow.joinStep == .done)
    #expect(couple.anya.flow.incomingStep == .done)
    #expect(couple.borya.model.syncCoupleID == coupleID)
}

@MainActor
@Test func rejectedCodeNeverDeliversKey() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()

    await couple.anya.flow.rejectIncoming()
    await couple.borya.flow.confirmJoin()

    #expect(couple.pairing.requests.allSatisfy { $0.wrappedKey == nil && $0.status == .rejected })
    #expect(couple.borya.flow.joinStep == .failed(.rejected))
    #expect(couple.borya.defaults.coupleID == nil)
}

@MainActor
@Test func joinerRejectingStopsResponder() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()

    await couple.borya.flow.rejectJoin()
    await couple.anya.flow.confirmIncoming()

    #expect(couple.pairing.requests.allSatisfy { $0.wrappedKey == nil })
    #expect(couple.anya.flow.incomingStep == .failed(.rejected))
}

@MainActor
@Test func tamperedRevealIsRejectedByResponder() async throws {
    // Сервер подменяет раскрытый ключ Бори, когда строку читает Аня: код ей не показывается.
    let couple = try Couple2()
    let fake = KeyExchangePair().publicKey
    couple.pairing.tamper.withLock {
        $0 = { request, reader in
            var request = request
            if reader == "anya", request.requesterPublicKey != nil { request.requesterPublicKey = fake }
            return request
        }
    }
    await couple.anya.flow.registerCouple()
    await couple.anya.flow.createInvite()
    await couple.borya.flow.join(code: try #require(couple.anya.flow.invite?.code))
    await couple.anya.flow.checkIncoming()
    await couple.borya.flow.pollJoin()

    await couple.anya.flow.pollIncoming()

    #expect(couple.anya.flow.incomingStep == .failed(.keyMismatch))
    #expect(couple.pairing.requests.allSatisfy { $0.status == .rejected && $0.wrappedKey == nil })
}

@MainActor
@Test func expiredRequestIsNotAnswered() async throws {
    let couple = try Couple2()
    await couple.anya.flow.registerCouple()
    await couple.anya.flow.createInvite()
    await couple.borya.flow.join(code: try #require(couple.anya.flow.invite?.code))
    couple.pairing.state.withLock { state in
        for id in state.requests.keys { state.requests[id]?.expiresAt = .distantPast }
    }

    await couple.anya.flow.checkIncoming()

    #expect(couple.anya.flow.incomingStep == nil)
    #expect(couple.pairing.requests.allSatisfy { $0.status == .waiting })
}

@MainActor
@Test func responderSwitchesToJoinersNewRequest() async throws {
    // Боря перезапустил приложение, пока Аня ждала раскрытия: её телефон переходит на новый запрос.
    let couple = try Couple2()
    await couple.anya.flow.coupleCreated()
    await couple.anya.flow.createInvite()
    await couple.borya.flow.join(code: try #require(couple.anya.flow.invite?.code))
    await couple.anya.flow.checkIncoming()
    let restarted = Phone(user: "borya", pairing: couple.pairing, sync: couple.sync)
    restarted.defaults.joiningCoupleID = couple.borya.defaults.joiningCoupleID
    let flow = PairingFlow(model: restarted.model, service: couple.borya.service, keys: restarted.keys,
                           defaults: restarted.defaults, makeTransport: { FakeSyncTransport(server: couple.sync) })
    await flow.startKeyRequest()

    await couple.anya.flow.pollIncoming()
    await flow.pollJoin()
    await couple.anya.flow.pollIncoming()

    guard case .verify(let anyaCode) = couple.anya.flow.incomingStep, case .verify(let boryaCode) = flow.joinStep else {
        Issue.record("Нет кода: \(String(describing: couple.anya.flow.incomingStep)) / \(String(describing: flow.joinStep))")
        return
    }
    #expect(anyaCode == boryaCode)
}

@MainActor
@Test func lostResponsesDoNotStallHandoff() async throws {
    // Ответ Ани и раскрытие Бори записались на сервер, но ответы сервера потерялись.
    let couple = try Couple2()
    await couple.anya.flow.coupleCreated()
    await couple.anya.flow.createInvite()
    await couple.borya.flow.join(code: try #require(couple.anya.flow.invite?.code))
    couple.anya.service.loseNextUpdateResponse.withLock { $0 = true }
    await couple.anya.flow.checkIncoming()
    couple.borya.service.loseNextUpdateResponse.withLock { $0 = true }
    await couple.borya.flow.pollJoin()
    #expect(couple.borya.flow.joinStep == .waiting)

    await couple.borya.flow.pollJoin()
    await couple.anya.flow.pollIncoming()

    guard case .verify(let anyaCode) = couple.anya.flow.incomingStep,
          case .verify(let boryaCode) = couple.borya.flow.joinStep
    else {
        Issue.record("Нет кода: \(String(describing: couple.anya.flow.incomingStep)) / \(String(describing: couple.borya.flow.joinStep))")
        return
    }
    #expect(anyaCode == boryaCode)
}

// MARK: - Записи

@MainActor
@Test func creatorRecordsReachJoinerAndJoinerOwnRecordsStayOff() async throws {
    // У Бори на телефоне были свои записи. После входа в пару у него записи Ани, его — нигде.
    var boryaData = AppData()
    boryaData.sexEntries = [sexEntry(1)]
    let anyaEntry = sexEntry(5)
    let couple = try Couple2(boryaData: boryaData, anyaEntries: [anyaEntry])
    _ = try await couple.untilCodes()
    await couple.anya.model.syncNow()

    await couple.confirmBoth()

    #expect(couple.borya.model.data.sexEntries == [anyaEntry])
    #expect(couple.borya.model.data.couple == couple.anya.model.data.couple)
    #expect(couple.borya.model.data.meID == nil, "кто он в паре, Боря выберет сам")
    await couple.anya.model.syncNow()
    #expect(couple.anya.model.data.sexEntries == [anyaEntry])
}

@MainActor
@Test func soloJoinerLeavesOldCoupleAndForgetsItsKey() async throws {
    // Боря пользовался приложением один: у него своя пара на сервере.
    let couple = try Couple2()
    try couple.borya.model.createCouple(me: PersonDraft(sex: .male, name: "Боря", birthDate: adult),
                                        partner: PersonDraft(sex: .female, name: "Д.", birthDate: adult), today: today)
    await couple.borya.flow.registerCouple()
    let oldID = try #require(couple.borya.defaults.coupleID)
    _ = try await couple.untilCodes()

    await couple.confirmBoth()

    #expect(couple.pairing.left.contains { $0 == (oldID, "borya") })
    #expect(couple.borya.keys.load(coupleID: oldID) == nil)
    #expect(couple.borya.defaults.coupleID == couple.anya.defaults.coupleID)
    #expect(couple.borya.defaults.couplesToLeave.isEmpty)
    #expect(couple.borya.model.data.couple == couple.anya.model.data.couple)
}

@MainActor
@Test func joinerClaimsPartnerPlaceholderKeepingSex() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()
    await couple.anya.model.syncNow()
    await couple.confirmBoth()
    let placeholder = try #require(couple.borya.model.data.couple?.man)
    #expect(couple.borya.flow.awaitsProfile)

    try couple.borya.model.claimPerson(
        PersonDraft(id: placeholder.id, sex: .male, name: "Боря Б.", birthDate: placeholder.birthDate), today: today)

    #expect(couple.borya.model.data.meID == placeholder.id)
    #expect(couple.borya.model.data.couple?.man.name == "Боря Б.")
    #expect(couple.borya.model.data.couple?.man.sex == .male)
    #expect(couple.borya.model.data.isPaired)
    #expect(!couple.borya.flow.awaitsProfile)
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
