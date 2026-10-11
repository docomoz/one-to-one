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
    let couple = try Couple2(dashaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    #expect(couple.maxim.model.data.sexEntries.count == 1)

    let left = await couple.maxim.flow.leaveCouple()

    #expect(left)
    #expect(couple.pairing.members(coupleID) == ["dasha"])
    #expect(couple.maxim.keys.load(coupleID: coupleID) == nil)
    #expect(couple.maxim.defaults.coupleID == nil)
    #expect(!couple.maxim.defaults.isCoupleOnServer)
    #expect(!couple.maxim.defaults.partnerJoined)
    #expect(!couple.maxim.model.isSyncStarted)
    #expect(!couple.maxim.model.hasSyncedRecords)
    #expect(couple.maxim.model.data.meID == nil)
    #expect(!couple.maxim.model.data.isPaired, "назад в знакомство")
    #expect(couple.maxim.model.syncStateStore.load(coupleID: coupleID) == SyncState())
    // У Даши всё осталось.
    #expect(couple.dasha.model.data.sexEntries.count == 1)
    #expect(couple.dasha.keys.load(coupleID: coupleID) != nil)
}

@MainActor
@Test func newCoupleAfterLeaveHasNewKeyAndNoOldRecords() async throws {
    let couple = try Couple2(dashaEntries: [sexEntry(3)])
    try await couple.paired()
    let oldID = try couple.coupleID
    let oldKey = try #require(couple.maxim.keys.load(coupleID: oldID))
    await couple.maxim.flow.leaveCouple()

    // Максим начинает новую пару с Верой.
    try couple.maxim.model.createCouple(me: PersonDraft(sex: .male, name: "Максим", birthDate: pairingAdult),
                                        partner: PersonDraft(sex: .female, name: "Вера", birthDate: pairingAdult),
                                        today: pairingToday)
    couple.maxim.model.update { $0.sexEntries.append(sexEntry(20)) }
    await couple.maxim.flow.coupleCreated()
    // Даша пишет в старую пару уже после выхода Максима.
    couple.dasha.model.update { $0.sexEntries.append(sexEntry(25)) }
    await couple.dasha.model.syncNow()
    await couple.maxim.model.syncNow()

    let newID = try #require(couple.maxim.defaults.coupleID)
    #expect(newID != oldID)
    let newKey = try #require(couple.maxim.keys.load(coupleID: newID))
    #expect(newKey != oldKey)
    #expect(couple.maxim.model.data.sexEntries.map(\.day) == [DayKey(year: 2026, month: 10, day: 20)],
            "ни старых записей, ни новых записей бывшей пары")
    // В новую пару ушли только записи новой: профиль пары и одна запись.
    #expect(couple.sync.documentCount(coupleID: newID) == 2)
    #expect(couple.dasha.model.data.sexEntries.count == 2)
}

@MainActor
@Test func leaveWithoutNetworkKeepsEverything() async throws {
    let couple = try Couple2(dashaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    couple.maxim.service.failure.withLock { $0 = .network }

    let left = await couple.maxim.flow.leaveCouple()

    #expect(!left)
    #expect(couple.maxim.flow.errorMessage == PairingError.network.message)
    #expect(couple.maxim.keys.load(coupleID: coupleID) != nil)
    #expect(couple.maxim.defaults.coupleID == coupleID)
    #expect(couple.maxim.model.data.isPaired)
    #expect(couple.maxim.model.isSyncStarted)
}

// MARK: - Удаление аккаунта

@MainActor
@Test func deleteAccountWipesEverythingAndSignsOut() async throws {
    let couple = try Couple2(dashaEntries: [sexEntry(3)])
    try await couple.paired()
    let coupleID = try couple.coupleID
    let auth = AuthFlow(auth: FakeAuthService(signedInUserID: "maxim", consent: 1),
                        consent: FakeAuthService(signedInUserID: "maxim", consent: 1))
    await auth.start()

    await couple.maxim.flow.deleteAccount(auth: auth)

    #expect(couple.pairing.deletedUsers == ["maxim"])
    #expect(couple.pairing.members(coupleID) == ["dasha"])
    #expect(couple.maxim.keys.load(coupleID: coupleID) == nil)
    #expect(couple.maxim.defaults.coupleID == nil)
    #expect(couple.maxim.defaults.ownerUserID == nil)
    #expect(!couple.maxim.model.hasSyncedRecords)
    #expect(!couple.maxim.model.isSyncStarted)
    #expect(auth.screen(isPaired: false) == .signIn)
    #expect(auth.userID == nil)
}

@MainActor
@Test func deleteAccountFailureKeepsAccountAndData() async throws {
    let couple = try Couple2(dashaEntries: [sexEntry(3)])
    try await couple.paired()
    let auth = AuthFlow(auth: FakeAuthService(signedInUserID: "maxim", consent: 1),
                        consent: FakeAuthService(signedInUserID: "maxim", consent: 1))
    await auth.start()
    couple.maxim.service.failure.withLock { $0 = .network }

    await couple.maxim.flow.deleteAccount(auth: auth)

    #expect(couple.pairing.deletedUsers.isEmpty)
    #expect(couple.maxim.flow.errorMessage == PairingError.network.message)
    #expect(couple.maxim.model.data.isPaired)
    #expect(auth.userID == "maxim")
}
