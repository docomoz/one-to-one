import Core
import Foundation
import Sync
import Testing
@testable import OneToOne

private func sexEntry(_ day: Int) -> SexEntry {
    SexEntry(day: DayKey(year: 2026, month: 10, day: day), types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1,
             createdBy: UUID())
}

// MARK: - Вход после переустановки или на новом телефоне

@MainActor
@Test func newAccountWithoutCoupleGoesToOnboarding() async throws {
    let phone = Phone(user: "vera", pairing: FakePairingServer(), sync: FakeSyncServer())

    await phone.flow.prepareAccount(userID: "vera")

    #expect(phone.flow.isAccountReady(for: "vera"))
    #expect(phone.flow.restoringCoupleID == nil)
    #expect(phone.defaults.coupleID == nil)
    #expect(phone.defaults.ownerUserID == "vera")
}

@MainActor
@Test func reinstallWithKeyInKeychainReusesIt() async throws {
    // Даша удалила и поставила приложение заново: настройки и записи пропали, Keychain остался.
    let couple = try Couple2(dashaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    let reinstalled = Phone(user: "dasha", pairing: couple.pairing, sync: couple.sync, keys: couple.dasha.keys)

    await reinstalled.flow.prepareAccount(userID: "dasha")
    await reinstalled.flow.prepareSync()
    await reinstalled.model.syncNow()

    #expect(reinstalled.flow.isAccountReady(for: "dasha"))
    #expect(reinstalled.flow.restoringCoupleID == nil)
    #expect(reinstalled.defaults.coupleID == coupleID)
    #expect(reinstalled.defaults.partnerJoined)
    #expect(reinstalled.model.data.sexEntries.count == 1)
    #expect(reinstalled.model.data.couple == couple.dasha.model.data.couple)
    #expect(reinstalled.flow.awaitsProfile, "кто я в паре, выбирает заново")
}

@MainActor
@Test func newPhoneWithoutKeyRestoresViaPartner() async throws {
    let couple = try Couple2(dashaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    let newPhone = Phone(user: "maxim", pairing: couple.pairing, sync: couple.sync)

    await newPhone.flow.prepareAccount(userID: "maxim")
    #expect(newPhone.flow.restoringCoupleID == coupleID)
    #expect(newPhone.flow.isAccountReady(for: "maxim"))

    await newPhone.flow.startKeyRequest()
    await couple.dasha.flow.checkIncoming()
    await newPhone.flow.pollJoin()
    await couple.dasha.flow.pollIncoming()
    guard case .verify(let dashaCode) = couple.dasha.flow.incomingStep,
          case .verify(let newCode) = newPhone.flow.joinStep
    else {
        Issue.record("Нет кода: \(String(describing: couple.dasha.flow.incomingStep)) / \(String(describing: newPhone.flow.joinStep))")
        return
    }
    #expect(dashaCode == newCode)
    await newPhone.flow.confirmJoin()
    await couple.dasha.flow.confirmIncoming()
    await newPhone.flow.pollJoin()

    #expect(newPhone.keys.load(coupleID: coupleID) == couple.dasha.keys.load(coupleID: coupleID))
    #expect(newPhone.flow.restoringCoupleID == nil)
    #expect(newPhone.defaults.coupleID == coupleID)
    #expect(newPhone.model.data.sexEntries.count == 1)
    #expect(newPhone.flow.awaitsProfile)
    #expect(couple.pairing.members(coupleID).sorted() == ["dasha", "maxim"], "из пары никто не вышел")
}

@MainActor
@Test func startOverFromRestoreLeavesCouple() async throws {
    // Один пользовался приложением и потерял телефон: ключа ни у кого нет, начинает заново.
    let pairing = FakePairingServer()
    let sync = FakeSyncServer()
    let old = Phone(user: "vera", pairing: pairing, sync: sync)
    try old.model.createCouple(me: PersonDraft(sex: .female, name: "Вера", birthDate: pairingAdult),
                               partner: PersonDraft(sex: .male, name: "Пётр", birthDate: pairingAdult),
                               today: pairingToday)
    await old.flow.coupleCreated()
    let coupleID = try #require(old.defaults.coupleID)
    let newPhone = Phone(user: "vera", pairing: pairing, sync: sync)
    await newPhone.flow.prepareAccount(userID: "vera")
    #expect(newPhone.flow.restoringCoupleID == coupleID)

    await newPhone.flow.abandonRestore()

    #expect(newPhone.flow.restoringCoupleID == nil)
    #expect(pairing.members(coupleID).isEmpty)
    #expect(newPhone.defaults.coupleID == nil)
    #expect(newPhone.flow.isAccountReady(for: "vera"))
}

@MainActor
@Test func lookupWithoutNetworkCanBeRetried() async throws {
    let phone = Phone(user: "vera", pairing: FakePairingServer(), sync: FakeSyncServer())
    phone.service.failure.withLock { $0 = .network }

    await phone.flow.prepareAccount(userID: "vera")

    #expect(!phone.flow.isAccountReady(for: "vera"))
    #expect(phone.flow.accountState == .failed(.network))

    await phone.flow.prepareAccount(userID: "vera")

    #expect(phone.flow.isAccountReady(for: "vera"))
}

@MainActor
@Test func sameAccountOfflineStartsWithoutServer() async throws {
    // Обычный запуск без сети: пара уже известна, сервер не спрашиваем.
    let couple = try Couple2()
    await couple.dasha.flow.coupleCreated()
    await couple.dasha.flow.prepareAccount(userID: "dasha")
    couple.dasha.service.failure.withLock { $0 = .network }

    await couple.dasha.flow.prepareAccount(userID: "dasha")

    #expect(couple.dasha.flow.isAccountReady(for: "dasha"))
    #expect(couple.dasha.model.data.isPaired)
}

// MARK: - Другой аккаунт на том же телефоне

@MainActor
@Test func differentAccountWipesStaleData() async throws {
    // Даша вышла не через «Выйти» (например, приложение упало), на телефоне вошла Вера.
    let couple = try Couple2(dashaEntries: [sexEntry(3)])
    await couple.dasha.flow.coupleCreated()
    await couple.dasha.flow.prepareAccount(userID: "dasha")
    let coupleID = try couple.coupleID
    couple.dasha.service.signIn(as: "vera")

    await couple.dasha.flow.prepareAccount(userID: "vera")

    #expect(!couple.dasha.model.hasSyncedRecords)
    #expect(!couple.dasha.model.data.isPaired)
    #expect(!couple.dasha.model.isSyncStarted)
    #expect(couple.dasha.defaults.coupleID == nil)
    #expect(couple.dasha.defaults.ownerUserID == "vera")
    #expect(couple.dasha.model.syncStateStore.load(coupleID: coupleID) == SyncState())
    #expect(couple.dasha.flow.isAccountReady(for: "vera"))
}

@MainActor
@Test func firstAccountAdoptsExistingData() async throws {
    // Записи появились до аккаунтов: первый вошедший — их хозяин.
    let couple = try Couple2(dashaEntries: [sexEntry(3)])

    await couple.dasha.flow.prepareAccount(userID: "dasha")

    #expect(couple.dasha.model.data.sexEntries.count == 1)
    #expect(couple.dasha.defaults.ownerUserID == "dasha")
}

// MARK: - Выход из аккаунта

@MainActor
@Test func signOutWipesLocalDataButKeepsKeyForReturn() async throws {
    let couple = try Couple2(dashaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    await couple.maxim.flow.prepareAccount(userID: "maxim")
    let fake = FakeAuthService(signedInUserID: "maxim", consent: 1)
    let auth = AuthFlow(auth: fake, consent: fake)
    await auth.start()
    #expect(await !couple.maxim.flow.hasUnsentChanges())

    await couple.maxim.flow.signOut(auth: auth)

    #expect(auth.userID == nil)
    #expect(!couple.maxim.model.hasSyncedRecords)
    #expect(couple.maxim.defaults.coupleID == nil)
    #expect(!couple.maxim.model.isSyncStarted)
    #expect(couple.maxim.model.syncStateStore.load(coupleID: coupleID) == SyncState())
    #expect(couple.pairing.members(coupleID).sorted() == ["dasha", "maxim"], "из пары не вышел")

    // Вернулся с той же почтой: ключ в Keychain, записи снова с сервера.
    await couple.maxim.flow.prepareAccount(userID: "maxim")
    await couple.maxim.flow.prepareSync()
    await couple.maxim.model.syncNow()
    #expect(couple.maxim.model.data.sexEntries.count == 1)
}

@MainActor
@Test func unsentChangesAreReportedBeforeSignOut() async throws {
    let couple = try Couple2()
    try await couple.paired()
    couple.maxim.transport.isOffline = true
    couple.maxim.model.update { $0.sexEntries.append(sexEntry(9)) }

    #expect(await couple.maxim.flow.hasUnsentChanges())
}

@MainActor
@Test func signOutFailureKeepsData() async throws {
    let couple = try Couple2(dashaEntries: [sexEntry(3)])
    try await couple.paired()
    let fake = FakeAuthService(signedInUserID: "maxim", consent: 1)
    fake.signOutError = .network
    let auth = AuthFlow(auth: fake, consent: fake)
    await auth.start()

    await couple.maxim.flow.signOut(auth: auth)

    #expect(auth.userID == "maxim")
    #expect(couple.maxim.model.data.sexEntries.count == 1)
    #expect(couple.maxim.defaults.coupleID != nil)
}

// MARK: - Два телефона с ключом

@MainActor
@Test func onlyOnePhoneAnswersWhenBothCheckAtOnce() async throws {
    // У Максима новый телефон, а старый ещё жив: на запрос могут ответить и Даша, и старый телефон Максима.
    let couple = try Couple2(dashaEntries: [sexEntry(3)])
    try await couple.paired()
    let newPhone = Phone(user: "maxim", pairing: couple.pairing, sync: couple.sync)
    await newPhone.flow.prepareAccount(userID: "maxim")
    await newPhone.flow.startKeyRequest()
    couple.dasha.service.latency.withLock { $0 = .milliseconds(30) }
    couple.maxim.service.latency.withLock { $0 = .milliseconds(30) }

    async let dasha: Void = couple.dasha.flow.checkIncoming()
    async let oldMaxim: Void = couple.maxim.flow.checkIncoming()
    _ = await (dasha, oldMaxim)

    let answering = [couple.dasha.flow, couple.maxim.flow].filter { $0.incomingStep != nil }
    #expect(answering.count == 1)
    #expect(couple.pairing.requests.allSatisfy { $0.status != .rejected })

    // Дальше передача идёт с тем, кто остался.
    let responder = try #require(answering.first)
    await newPhone.flow.pollJoin()
    await responder.pollIncoming()
    guard case .verify(let code) = responder.incomingStep, case .verify(let newCode) = newPhone.flow.joinStep else {
        Issue.record("Нет кода: \(String(describing: responder.incomingStep)) / \(String(describing: newPhone.flow.joinStep))")
        return
    }
    #expect(code == newCode)
}

@MainActor
@Test func overwrittenAnswerWithdrawsQuietly() async throws {
    // Ответ Даши перезаписал другой телефон уже после её проверки: она не отказывает запросу и не показывает код.
    let couple = try Couple2()
    try await couple.paired()
    let newPhone = Phone(user: "maxim", pairing: couple.pairing, sync: couple.sync)
    await newPhone.flow.prepareAccount(userID: "maxim")
    await newPhone.flow.startKeyRequest()
    await couple.dasha.flow.checkIncoming()
    #expect(couple.dasha.flow.incomingStep == .waiting)
    couple.pairing.state.withLock { state in
        for id in state.requests.keys { state.requests[id]?.responderPublicKey = KeyExchangePair().publicKey }
    }

    await couple.dasha.flow.pollIncoming()
    await couple.dasha.flow.checkIncoming()

    #expect(couple.dasha.flow.incomingStep == nil)
    #expect(couple.pairing.requests.allSatisfy { $0.status != .rejected })
}

@MainActor
@Test func requesterNeverAnswersItsOwnRequest() async throws {
    // Телефон с ключом сам просит ключ (например, ключ не открылся) — на свой же запрос он не отвечает.
    let couple = try Couple2()
    await couple.dasha.flow.coupleCreated()
    let coupleID = try couple.coupleID
    couple.dasha.flow.restoringCoupleID = coupleID
    await couple.dasha.flow.startKeyRequest()

    await couple.dasha.flow.checkIncoming()

    #expect(couple.dasha.flow.incomingStep == nil)
    #expect(couple.pairing.requests.allSatisfy { $0.status == .waiting && $0.responderPublicKey == nil })
}

// MARK: - QR вживую

@MainActor
@Test func scannedQRWithSameCodeDeliversKey() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()
    let payload = try #require(couple.maxim.flow.verifyQRPayload)

    await couple.dasha.flow.confirmIncoming(scanned: payload)
    await couple.maxim.flow.confirmJoin()

    #expect(couple.dasha.flow.incomingStep == .done)
    #expect(couple.maxim.flow.joinStep == .done)
}

@MainActor
@Test func scannedQRWithOtherCodeRejects() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()
    let requestID = try #require(couple.pairing.requests.first?.id)

    await couple.dasha.flow.confirmIncoming(scanned: VerifyQR.payload(requestID: requestID, code: "000000"))

    #expect(couple.dasha.flow.incomingStep == .failed(.rejected))
    #expect(couple.pairing.requests.allSatisfy { $0.wrappedKey == nil })
}

@MainActor
@Test func scannedQRFromOtherRequestIsIgnored() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()
    let before = couple.dasha.flow.incomingStep

    await couple.dasha.flow.confirmIncoming(scanned: VerifyQR.payload(requestID: "other", code: "123456"))
    await couple.dasha.flow.confirmIncoming(scanned: "https://example.com")

    #expect(couple.dasha.flow.incomingStep == before)
    #expect(couple.dasha.flow.errorMessage == VerifyQR.wrongQRMessage)
}

@Test func qrPayloadRoundTrips() {
    let payload = VerifyQR.payload(requestID: "req1", code: "042917")
    #expect(VerifyQR.parse(payload) == VerifyQR.Scanned(requestID: "req1", code: "042917"))
    #expect(VerifyQR.parse("one-to-one:verify:req1") == nil)
    #expect(VerifyQR.parse("hello") == nil)
}
