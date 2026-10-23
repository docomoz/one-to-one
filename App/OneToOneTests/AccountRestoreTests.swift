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
    // Аня удалила и поставила приложение заново: настройки и записи пропали, Keychain остался.
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    let reinstalled = Phone(user: "anya", pairing: couple.pairing, sync: couple.sync, keys: couple.anya.keys)

    await reinstalled.flow.prepareAccount(userID: "anya")
    await reinstalled.flow.prepareSync()
    await reinstalled.model.syncNow()

    #expect(reinstalled.flow.isAccountReady(for: "anya"))
    #expect(reinstalled.flow.restoringCoupleID == nil)
    #expect(reinstalled.defaults.coupleID == coupleID)
    #expect(reinstalled.defaults.partnerJoined)
    #expect(reinstalled.model.data.sexEntries.count == 1)
    #expect(reinstalled.model.data.couple == couple.anya.model.data.couple)
    #expect(reinstalled.flow.awaitsProfile, "кто я в паре, выбирает заново")
}

@MainActor
@Test func newPhoneWithoutKeyRestoresViaPartner() async throws {
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    let newPhone = Phone(user: "borya", pairing: couple.pairing, sync: couple.sync)

    await newPhone.flow.prepareAccount(userID: "borya")
    #expect(newPhone.flow.restoringCoupleID == coupleID)
    #expect(newPhone.flow.isAccountReady(for: "borya"))

    await newPhone.flow.startKeyRequest()
    await couple.anya.flow.checkIncoming()
    await newPhone.flow.pollJoin()
    await couple.anya.flow.pollIncoming()
    guard case .verify(let anyaCode) = couple.anya.flow.incomingStep,
          case .verify(let newCode) = newPhone.flow.joinStep
    else {
        Issue.record("Нет кода: \(String(describing: couple.anya.flow.incomingStep)) / \(String(describing: newPhone.flow.joinStep))")
        return
    }
    #expect(anyaCode == newCode)
    await newPhone.flow.confirmJoin()
    await couple.anya.flow.confirmIncoming()
    await newPhone.flow.pollJoin()

    #expect(newPhone.keys.load(coupleID: coupleID) == couple.anya.keys.load(coupleID: coupleID))
    #expect(newPhone.flow.restoringCoupleID == nil)
    #expect(newPhone.defaults.coupleID == coupleID)
    #expect(newPhone.model.data.sexEntries.count == 1)
    #expect(newPhone.flow.awaitsProfile)
    #expect(couple.pairing.members(coupleID).sorted() == ["anya", "borya"], "из пары никто не вышел")
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
    await couple.anya.flow.coupleCreated()
    await couple.anya.flow.prepareAccount(userID: "anya")
    couple.anya.service.failure.withLock { $0 = .network }

    await couple.anya.flow.prepareAccount(userID: "anya")

    #expect(couple.anya.flow.isAccountReady(for: "anya"))
    #expect(couple.anya.model.data.isPaired)
}

// MARK: - Другой аккаунт на том же телефоне

@MainActor
@Test func differentAccountWipesStaleData() async throws {
    // Аня вышла не через «Выйти» (например, приложение упало), на телефоне вошла Вера.
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    await couple.anya.flow.coupleCreated()
    await couple.anya.flow.prepareAccount(userID: "anya")
    let coupleID = try couple.coupleID
    couple.anya.service.signIn(as: "vera")

    await couple.anya.flow.prepareAccount(userID: "vera")

    #expect(!couple.anya.model.hasSyncedRecords)
    #expect(!couple.anya.model.data.isPaired)
    #expect(!couple.anya.model.isSyncStarted)
    #expect(couple.anya.defaults.coupleID == nil)
    #expect(couple.anya.defaults.ownerUserID == "vera")
    #expect(couple.anya.model.syncStateStore.load(coupleID: coupleID) == SyncState())
    #expect(couple.anya.flow.isAccountReady(for: "vera"))
}

@MainActor
@Test func firstAccountAdoptsExistingData() async throws {
    // Записи появились до аккаунтов: первый вошедший — их хозяин.
    let couple = try Couple2(anyaEntries: [sexEntry(3)])

    await couple.anya.flow.prepareAccount(userID: "anya")

    #expect(couple.anya.model.data.sexEntries.count == 1)
    #expect(couple.anya.defaults.ownerUserID == "anya")
}

// MARK: - Выход из аккаунта

@MainActor
@Test func signOutWipesLocalDataButKeepsKeyForReturn() async throws {
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    await couple.borya.flow.prepareAccount(userID: "borya")
    let fake = FakeAuthService(signedInUserID: "borya", consent: 1)
    let auth = AuthFlow(auth: fake, consent: fake)
    await auth.start()
    #expect(await !couple.borya.flow.hasUnsentChanges())

    await couple.borya.flow.signOut(auth: auth)

    #expect(auth.userID == nil)
    #expect(!couple.borya.model.hasSyncedRecords)
    #expect(couple.borya.defaults.coupleID == nil)
    #expect(!couple.borya.model.isSyncStarted)
    #expect(couple.borya.model.syncStateStore.load(coupleID: coupleID) == SyncState())
    #expect(couple.pairing.members(coupleID).sorted() == ["anya", "borya"], "из пары не вышел")

    // Вернулся с той же почтой: ключ в Keychain, записи снова с сервера.
    await couple.borya.flow.prepareAccount(userID: "borya")
    await couple.borya.flow.prepareSync()
    await couple.borya.model.syncNow()
    #expect(couple.borya.model.data.sexEntries.count == 1)
}

@MainActor
@Test func unsentChangesAreReportedBeforeSignOut() async throws {
    let couple = try Couple2()
    try await couple.paired()
    couple.borya.transport.isOffline = true
    couple.borya.model.update { $0.sexEntries.append(sexEntry(9)) }

    #expect(await couple.borya.flow.hasUnsentChanges())
}

@MainActor
@Test func signOutFailureKeepsData() async throws {
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let fake = FakeAuthService(signedInUserID: "borya", consent: 1)
    fake.signOutError = .network
    let auth = AuthFlow(auth: fake, consent: fake)
    await auth.start()

    await couple.borya.flow.signOut(auth: auth)

    #expect(auth.userID == "borya")
    #expect(couple.borya.model.data.sexEntries.count == 1)
    #expect(couple.borya.defaults.coupleID != nil)
}

// MARK: - Два телефона с ключом

@MainActor
@Test func onlyOnePhoneAnswersWhenBothCheckAtOnce() async throws {
    // У Бори новый телефон, а старый ещё жив: на запрос могут ответить и Аня, и старый телефон Бори.
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let newPhone = Phone(user: "borya", pairing: couple.pairing, sync: couple.sync)
    await newPhone.flow.prepareAccount(userID: "borya")
    await newPhone.flow.startKeyRequest()
    couple.anya.service.latency.withLock { $0 = .milliseconds(30) }
    couple.borya.service.latency.withLock { $0 = .milliseconds(30) }

    async let anya: Void = couple.anya.flow.checkIncoming()
    async let oldBorya: Void = couple.borya.flow.checkIncoming()
    _ = await (anya, oldBorya)

    let answering = [couple.anya.flow, couple.borya.flow].filter { $0.incomingStep != nil }
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
    // Ответ Ани перезаписал другой телефон уже после её проверки: она не отказывает запросу и не показывает код.
    let couple = try Couple2()
    try await couple.paired()
    let newPhone = Phone(user: "borya", pairing: couple.pairing, sync: couple.sync)
    await newPhone.flow.prepareAccount(userID: "borya")
    await newPhone.flow.startKeyRequest()
    await couple.anya.flow.checkIncoming()
    #expect(couple.anya.flow.incomingStep == .waiting)
    couple.pairing.state.withLock { state in
        for id in state.requests.keys { state.requests[id]?.responderPublicKey = KeyExchangePair().publicKey }
    }

    await couple.anya.flow.pollIncoming()
    await couple.anya.flow.checkIncoming()

    #expect(couple.anya.flow.incomingStep == nil)
    #expect(couple.pairing.requests.allSatisfy { $0.status != .rejected })
}

@MainActor
@Test func requesterNeverAnswersItsOwnRequest() async throws {
    // Телефон с ключом сам просит ключ (например, ключ не открылся) — на свой же запрос он не отвечает.
    let couple = try Couple2()
    await couple.anya.flow.coupleCreated()
    let coupleID = try couple.coupleID
    couple.anya.flow.restoringCoupleID = coupleID
    await couple.anya.flow.startKeyRequest()

    await couple.anya.flow.checkIncoming()

    #expect(couple.anya.flow.incomingStep == nil)
    #expect(couple.pairing.requests.allSatisfy { $0.status == .waiting && $0.responderPublicKey == nil })
}

// MARK: - QR вживую

@MainActor
@Test func scannedQRWithSameCodeDeliversKey() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()
    let payload = try #require(couple.borya.flow.verifyQRPayload)

    await couple.anya.flow.confirmIncoming(scanned: payload)
    await couple.borya.flow.confirmJoin()

    #expect(couple.anya.flow.incomingStep == .done)
    #expect(couple.borya.flow.joinStep == .done)
}

@MainActor
@Test func scannedQRWithOtherCodeRejects() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()
    let requestID = try #require(couple.pairing.requests.first?.id)

    await couple.anya.flow.confirmIncoming(scanned: VerifyQR.payload(requestID: requestID, code: "000000"))

    #expect(couple.anya.flow.incomingStep == .failed(.rejected))
    #expect(couple.pairing.requests.allSatisfy { $0.wrappedKey == nil })
}

@MainActor
@Test func scannedQRFromOtherRequestIsIgnored() async throws {
    let couple = try Couple2()
    _ = try await couple.untilCodes()
    let before = couple.anya.flow.incomingStep

    await couple.anya.flow.confirmIncoming(scanned: VerifyQR.payload(requestID: "other", code: "123456"))
    await couple.anya.flow.confirmIncoming(scanned: "https://example.com")

    #expect(couple.anya.flow.incomingStep == before)
    #expect(couple.anya.flow.errorMessage == VerifyQR.wrongQRMessage)
}

@Test func qrPayloadRoundTrips() {
    let payload = VerifyQR.payload(requestID: "req1", code: "042917")
    #expect(VerifyQR.parse(payload) == VerifyQR.Scanned(requestID: "req1", code: "042917"))
    #expect(VerifyQR.parse("one-to-one:verify:req1") == nil)
    #expect(VerifyQR.parse("hello") == nil)
}

// MARK: - Найдено на ревью

@MainActor
@Test func backupWithoutKeyAsksPartnerAndKeepsData() async throws {
    // Новый iPhone из резервной копии: записи и настройки пары вернулись, ключ (только этого устройства) — нет.
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    let restored = Phone(user: "borya", pairing: couple.pairing, sync: couple.sync, data: couple.borya.model.data)
    restored.defaults.coupleID = coupleID
    restored.defaults.isCoupleOnServer = true
    restored.defaults.ownerUserID = "borya"
    let flow = PairingFlow(model: restored.model, service: restored.service, keys: restored.keys,
                           defaults: restored.defaults, makeTransport: { restored.transport })

    await flow.prepareAccount(userID: "borya")
    #expect(flow.restoringCoupleID == coupleID)
    #expect(restored.model.data.isPaired)

    await flow.startKeyRequest()
    await couple.anya.flow.checkIncoming()
    await flow.pollJoin()
    await couple.anya.flow.pollIncoming()
    await flow.confirmJoin()
    await couple.anya.flow.confirmIncoming()
    await flow.pollJoin()

    #expect(flow.restoringCoupleID == nil)
    #expect(restored.model.isSyncStarted)
    #expect(restored.model.data.isPaired, "кто я — из копии, выбирать заново не нужно")
    #expect(restored.model.data.sexEntries.count == 1)
}

@MainActor
@Test func soloOwnSecondPhoneIsNotAPartner() async throws {
    // Одиночка передал ключ своему новому телефону: партнёр от этого не появился и «не вышел».
    let pairing = FakePairingServer()
    let sync = FakeSyncServer()
    let old = Phone(user: "vera", pairing: pairing, sync: sync)
    try old.model.createCouple(me: PersonDraft(sex: .female, name: "Вера", birthDate: pairingAdult),
                               partner: PersonDraft(sex: .male, name: "Пётр", birthDate: pairingAdult),
                               today: pairingToday)
    await old.flow.coupleCreated()
    let newPhone = Phone(user: "vera", pairing: pairing, sync: sync)
    await newPhone.flow.prepareAccount(userID: "vera")
    await newPhone.flow.startKeyRequest()
    await old.flow.checkIncoming()
    await newPhone.flow.pollJoin()
    await old.flow.pollIncoming()
    await newPhone.flow.confirmJoin()
    await old.flow.confirmIncoming()
    await newPhone.flow.pollJoin()

    #expect(newPhone.flow.restoringCoupleID == nil)
    #expect(newPhone.keys.load(coupleID: try #require(old.defaults.coupleID)) != nil)
    await old.flow.refreshPartnerJoined()
    #expect(!old.flow.partnerJoined)
    #expect(!old.flow.partnerLeft)
    #expect(!newPhone.flow.partnerJoined)
}

@MainActor
@Test func signOutClosesOpenKeyRequest() async throws {
    let couple = try Couple2()
    try await couple.paired()
    let newPhone = Phone(user: "borya", pairing: couple.pairing, sync: couple.sync)
    await newPhone.flow.prepareAccount(userID: "borya")
    await newPhone.flow.startKeyRequest()
    let fake = FakeAuthService(signedInUserID: "borya", consent: 1)
    let auth = AuthFlow(auth: fake, consent: fake)
    await auth.start()

    await newPhone.flow.signOut(auth: auth)

    // Запрос из приглашения отдал ключ раньше; новый, с этого телефона, закрыт.
    let open = couple.pairing.requests.filter { $0.status != .delivered }
    #expect(open.count == 1)
    #expect(open.allSatisfy { $0.status == .rejected })
}

@MainActor
@Test func staleLookupDoesNotTouchNextAccount() async throws {
    // Поиск пары для Ани ещё шёл, когда она вышла и на телефоне вошла Вера.
    let couple = try Couple2()
    await couple.anya.flow.coupleCreated()
    let reinstalled = Phone(user: "anya", pairing: couple.pairing, sync: couple.sync, keys: couple.anya.keys)
    reinstalled.service.latency.withLock { $0 = .milliseconds(50) }

    async let first: Void = reinstalled.flow.prepareAccount(userID: "anya")
    try await Task.sleep(for: .milliseconds(10))
    reinstalled.flow.forgetLocalData()
    reinstalled.defaults.ownerUserID = "vera"
    await first

    #expect(reinstalled.defaults.coupleID == nil)
    #expect(!reinstalled.flow.isAccountReady(for: "anya"))
}
