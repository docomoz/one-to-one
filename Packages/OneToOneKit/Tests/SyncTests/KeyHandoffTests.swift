import Foundation
import Testing
@testable import Sync

private let now = Date(timeIntervalSince1970: 1_800_000_000)

/// Строка `keyRequests`, которую создал телефон без ключа: только обязательство.
private func newRequest(_ requester: KeyHandoffRequester, expiresAt: Date = now.addingTimeInterval(600)) -> KeyRequest {
    KeyRequest(id: "req1", coupleID: "couple1", requesterUserID: "boris",
               requesterKeyCommitment: requester.commitment, status: .waiting, expiresAt: expiresAt)
}

/// Оба телефона дошли до показа кода: ответ, раскрытие, проверка обязательства.
private func exchangeUntilCodes(requester: inout KeyHandoffRequester, responder: inout KeyHandoffResponder)
    throws -> (row: KeyRequest, requesterCode: String, responderCode: String?) {
    var row = newRequest(requester)
    row = row.applying(try responder.answer(row, now: now))
    row = row.applying(try #require(try requester.reveal(after: row, now: now)))
    let responderCode = try responder.verify(row, now: now)
    return (row, try #require(requester.verificationCode), responderCode)
}

@Test func handoffDeliversKeyAfterBothConfirm() throws {
    let key = CoupleKey()
    var requester = KeyHandoffRequester()
    var responder = KeyHandoffResponder(key: key)

    var (row, requesterCode, responderCode) = try exchangeUntilCodes(requester: &requester, responder: &responder)
    #expect(row.status == .revealed)
    #expect(responderCode == requesterCode)
    #expect(requesterCode.count == 6)

    row = row.applying(try responder.deliver())
    #expect(row.status == .delivered)
    // Пока сам не подтвердил код, ключ не берёт, даже если он уже лежит в строке.
    #expect(try requester.receive(row, now: now) == nil)

    requester.confirm()
    #expect(try requester.receive(row, now: now) == key)
}

@Test func rejectedHandoffNeverSendsKey() throws {
    var requester = KeyHandoffRequester()
    var responder = KeyHandoffResponder(key: CoupleKey())
    var (row, _, _) = try exchangeUntilCodes(requester: &requester, responder: &responder)

    row = row.applying(responder.reject())

    #expect(row.status == .rejected)
    #expect(row.wrappedKey == nil)
    #expect(throws: KeyHandoffError.rejected) { try responder.deliver() }
    requester.confirm()
    #expect(throws: KeyHandoffError.rejected) { try requester.receive(row, now: now) }
}

@Test func responderCannotDeliverBeforeVerifying() throws {
    var responder = KeyHandoffResponder(key: CoupleKey())
    let row = newRequest(KeyHandoffRequester())
    _ = try responder.answer(row, now: now)

    #expect(throws: KeyHandoffError.unexpectedStatus) { try responder.deliver() }
}

@Test func expiredRequestIgnored() throws {
    let requester = KeyHandoffRequester()
    var responder = KeyHandoffResponder(key: CoupleKey())
    let expired = newRequest(requester, expiresAt: now)
    let alive = KeyRequest(id: "req2", coupleID: "couple1", requesterUserID: "boris",
                           requesterKeyCommitment: requester.commitment, status: .waiting,
                           expiresAt: now.addingTimeInterval(1))

    #expect(KeyHandoff.pendingRequest(in: [expired], now: now) == nil)
    #expect(KeyHandoff.pendingRequest(in: [expired, alive], now: now) == alive)
    #expect(throws: KeyHandoffError.expired) { try responder.answer(expired, now: now) }
}

@Test func pendingRequestSkipsAnsweredAndFinished() {
    let requester = KeyHandoffRequester()
    let rows = [KeyRequestStatus.answered, .revealed, .delivered, .rejected].map { status in
        KeyRequest(id: status.rawValue, coupleID: "couple1", requesterUserID: "boris",
                   requesterKeyCommitment: requester.commitment, status: status, expiresAt: now.addingTimeInterval(600))
    }

    #expect(KeyHandoff.pendingRequest(in: rows, now: now) == nil)
}

@Test func revealNotMatchingCommitmentRejected() throws {
    // Сервер подменил раскрытый ключ своим: он не совпадает с обещанным, кода не будет.
    var requester = KeyHandoffRequester()
    var responder = KeyHandoffResponder(key: CoupleKey())
    var row = newRequest(requester)
    row = row.applying(try responder.answer(row, now: now))
    row = row.applying(try #require(try requester.reveal(after: row, now: now)))
    row.requesterPublicKey = KeyExchangePair().publicKey

    #expect(throws: KeyHandoffError.commitmentMismatch) { try responder.verify(row, now: now) }
    #expect(throws: KeyHandoffError.rejected) { try responder.deliver() }
}

@Test func responderKeyRequiredBeforeReveal() throws {
    // Пока второй телефон не ответил своим ключом, свой не раскрываем: иначе сервер подберёт ключ под код.
    var requester = KeyHandoffRequester()
    var row = newRequest(requester)

    #expect(try requester.reveal(after: row, now: now) == nil)
    #expect(requester.verificationCode == nil)

    // Статус «ответил», а ключа нет — тоже ждём.
    row.status = .answered
    #expect(try requester.reveal(after: row, now: now) == nil)
}

@Test func responderWaitsUntilRequesterReveals() throws {
    let requester = KeyHandoffRequester()
    var responder = KeyHandoffResponder(key: CoupleKey())
    var row = newRequest(requester)
    row = row.applying(try responder.answer(row, now: now))

    #expect(try responder.verify(row, now: now) == nil)
}

@Test func requesterRejectsSwappedResponderKeyAfterCode() throws {
    // После показа кода сервер подменил ключ отвечающего: завёрнутый ключ не принимаем.
    var requester = KeyHandoffRequester()
    var responder = KeyHandoffResponder(key: CoupleKey())
    var (row, _, _) = try exchangeUntilCodes(requester: &requester, responder: &responder)
    row = row.applying(try responder.deliver())
    row.responderPublicKey = KeyExchangePair().publicKey
    requester.confirm()

    #expect(throws: KeyHandoffError.keyChanged) { try requester.receive(row, now: now) }
}

@Test func commitmentIsSHA256OfPublicKey() {
    let pair = KeyExchangePair()
    let requester = KeyHandoffRequester(pair: pair)

    #expect(requester.commitment == KeyHandoff.commitment(for: pair.publicKey))
    #expect(requester.commitment.count == 32)
    #expect(requester.commitment != pair.publicKey)
}

@Test func unansweredRequestExpiresForRequester() throws {
    // Партнёр так и не открыл приложение: телефон без ключа перестаёт ждать.
    var requester = KeyHandoffRequester()
    let row = newRequest(requester)

    #expect(throws: KeyHandoffError.expired) { try requester.reveal(after: row, now: row.expiresAt) }
}

@Test func expiredRequestNotRevealed() throws {
    var requester = KeyHandoffRequester()
    var responder = KeyHandoffResponder(key: CoupleKey())
    var row = newRequest(requester)
    row = row.applying(try responder.answer(row, now: now))

    #expect(throws: KeyHandoffError.expired) {
        try requester.reveal(after: row, now: row.expiresAt)
    }
}

@Test func revealRepeatsUntilServerHasIt() throws {
    // Раскрытие записалось, а ответ сервера потерялся — или не записалось вовсе. Оба случая не должны застрять.
    var requester = KeyHandoffRequester()
    var responder = KeyHandoffResponder(key: CoupleKey())
    var row = newRequest(requester)
    row = row.applying(try responder.answer(row, now: now))
    let first = try #require(try requester.reveal(after: row, now: now))

    #expect(try requester.reveal(after: row, now: now) == first, "не записалось: отправить ещё раз")
    #expect(try requester.reveal(after: row.applying(first), now: now) == nil, "записалось: больше не нужно")
}

@Test func responderWaitsWhileItsAnswerIsNotOnServer() throws {
    let requester = KeyHandoffRequester()
    var responder = KeyHandoffResponder(key: CoupleKey())
    let row = newRequest(requester)
    let answer = try responder.answer(row, now: now)

    #expect(try responder.verify(row, now: now) == nil)
    #expect(answer == .answer(responderPublicKey: responder.publicKey))
}
