import Core
import Foundation
import Sync
import Testing
@testable import OneToOne

private func sexEntry(_ day: Int) -> SexEntry {
    SexEntry(day: DayKey(year: 2026, month: 10, day: day), types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1,
             createdBy: UUID())
}

// MARK: - Выход из пары (Review Focus 5)

@MainActor
@Test func leaveWipesCoupleDataAndKey() async throws {
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    #expect(couple.borya.model.data.sexEntries.count == 1)

    let left = await couple.borya.flow.leaveCouple()

    #expect(left)
    #expect(couple.pairing.members(coupleID) == ["anya"])
    #expect(couple.borya.keys.load(coupleID: coupleID) == nil)
    #expect(couple.borya.defaults.coupleID == nil)
    #expect(!couple.borya.defaults.isCoupleOnServer)
    #expect(!couple.borya.defaults.partnerJoined)
    #expect(!couple.borya.model.isSyncStarted)
    #expect(!couple.borya.model.hasSyncedRecords)
    #expect(couple.borya.model.data.meID == nil)
    #expect(!couple.borya.model.data.isPaired, "назад в знакомство")
    #expect(couple.borya.model.syncStateStore.load(coupleID: coupleID) == SyncState())
    // У Ани всё осталось.
    #expect(couple.anya.model.data.sexEntries.count == 1)
    #expect(couple.anya.keys.load(coupleID: coupleID) != nil)
}

@MainActor
@Test func newCoupleAfterLeaveHasNewKeyAndNoOldRecords() async throws {
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let oldID = try couple.coupleID
    let oldKey = try #require(couple.borya.keys.load(coupleID: oldID))
    await couple.borya.flow.leaveCouple()

    // Боря начинает новую пару с Верой.
    try couple.borya.model.createCouple(me: PersonDraft(sex: .male, name: "Боря", birthDate: pairingAdult),
                                        partner: PersonDraft(sex: .female, name: "Вера", birthDate: pairingAdult),
                                        today: pairingToday)
    couple.borya.model.update { $0.sexEntries.append(sexEntry(20)) }
    await couple.borya.flow.coupleCreated()
    // Аня пишет в старую пару уже после выхода Бори.
    couple.anya.model.update { $0.sexEntries.append(sexEntry(25)) }
    await couple.anya.model.syncNow()
    await couple.borya.model.syncNow()

    let newID = try #require(couple.borya.defaults.coupleID)
    #expect(newID != oldID)
    let newKey = try #require(couple.borya.keys.load(coupleID: newID))
    #expect(newKey != oldKey)
    #expect(couple.borya.model.data.sexEntries.map(\.day) == [DayKey(year: 2026, month: 10, day: 20)],
            "ни старых записей, ни новых записей бывшей пары")
    // В новую пару ушли только записи новой: профиль пары и одна запись.
    #expect(couple.sync.documentCount(coupleID: newID) == 2)
    #expect(couple.anya.model.data.sexEntries.count == 2)
}

@MainActor
@Test func leaveWithoutNetworkKeepsEverything() async throws {
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    couple.borya.service.failure.withLock { $0 = .network }

    let left = await couple.borya.flow.leaveCouple()

    #expect(!left)
    #expect(couple.borya.flow.errorMessage == PairingError.network.message)
    #expect(couple.borya.keys.load(coupleID: coupleID) != nil)
    #expect(couple.borya.defaults.coupleID == coupleID)
    #expect(couple.borya.model.data.isPaired)
    #expect(couple.borya.model.isSyncStarted)
}

// MARK: - Удаление аккаунта

@MainActor
@Test func deleteAccountWipesEverythingAndSignsOut() async throws {
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    let auth = AuthFlow(auth: FakeAuthService(signedInUserID: "borya", consent: 1),
                        consent: FakeAuthService(signedInUserID: "borya", consent: 1))
    await auth.start()

    await couple.borya.flow.deleteAccount(auth: auth)

    #expect(couple.pairing.deletedUsers == ["borya"])
    #expect(couple.pairing.members(coupleID) == ["anya"])
    #expect(couple.borya.keys.load(coupleID: coupleID) == nil)
    #expect(couple.borya.defaults.coupleID == nil)
    #expect(couple.borya.defaults.ownerUserID == nil)
    #expect(!couple.borya.model.hasSyncedRecords)
    #expect(!couple.borya.model.isSyncStarted)
    #expect(auth.screen(isPaired: false) == .signIn)
    #expect(auth.userID == nil)
}

@MainActor
@Test func deleteAccountFailureKeepsAccountAndData() async throws {
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let auth = AuthFlow(auth: FakeAuthService(signedInUserID: "borya", consent: 1),
                        consent: FakeAuthService(signedInUserID: "borya", consent: 1))
    await auth.start()
    couple.borya.service.failure.withLock { $0 = .network }

    await couple.borya.flow.deleteAccount(auth: auth)

    #expect(couple.pairing.deletedUsers.isEmpty)
    #expect(couple.borya.flow.errorMessage == PairingError.network.message)
    #expect(couple.borya.model.data.isPaired)
    #expect(auth.userID == "borya")
}

@MainActor
@Test func deleteAccountAfterLostResponseStillWipes() async throws {
    // Аккаунт удалился, ответ потерялся; повтор упирается в отсутствие сессии.
    let couple = try Couple2(anyaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    let fake = FakeAuthService(signedInUserID: "borya", consent: 1)
    let auth = AuthFlow(auth: fake, consent: fake)
    await auth.start()
    couple.borya.service.failure.withLock { $0 = .signedOut }

    await couple.borya.flow.deleteAccount(auth: auth)

    #expect(couple.borya.keys.load(coupleID: coupleID) == nil)
    #expect(!couple.borya.model.hasSyncedRecords)
    #expect(auth.userID == nil)
}
