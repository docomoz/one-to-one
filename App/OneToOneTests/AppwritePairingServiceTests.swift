import Foundation
import Sync
import Testing
@testable import OneToOne

private let commitment = Data(repeating: 7, count: 32)
private let key = Data(repeating: 9, count: 32)

private func row(_ extra: [String: Any] = [:]) -> [String: Any] {
    [
        "coupleId": "couple1",
        "requesterUserId": "boris",
        "requesterKeyCommitment": commitment.base64EncodedString(),
        "requesterPublicKey": NSNull(),
        "responderPublicKey": "",
        "wrappedKey": NSNull(),
        "status": "waiting",
        "expiresAt": "2026-10-11T12:15:00.000+00:00",
    ].merging(extra) { $1 }
}

@Test func keyRequestRowParses() throws {
    let request = try #require(AppwritePairingService.keyRequest(
        id: "req1", data: row(["responderPublicKey": key.base64EncodedString(), "status": "answered"])))

    #expect(request.id == "req1")
    #expect(request.coupleID == "couple1")
    #expect(request.requesterKeyCommitment == commitment)
    #expect(request.requesterPublicKey == nil)
    #expect(request.responderPublicKey == key)
    #expect(request.status == .answered)
    #expect(request.expiresAt == RecordsPuller.date("2026-10-11T12:15:00.000+00:00"))
}

@Test func brokenKeyRequestRowSkipped() {
    #expect(AppwritePairingService.keyRequest(id: "r", data: row(["status": "lost"])) == nil)
    #expect(AppwritePairingService.keyRequest(id: "r", data: row(["requesterKeyCommitment": ""])) == nil)
    #expect(AppwritePairingService.keyRequest(id: "r", data: row(["responderPublicKey": "не base64"])) == nil)
}

@Test func keyRequestUpdateFields() {
    #expect(AppwritePairingService.fields(for: .answer(responderPublicKey: key))
        == ["status": "answered", "responderPublicKey": key.base64EncodedString()])
    #expect(AppwritePairingService.fields(for: .reveal(requesterPublicKey: key))
        == ["status": "revealed", "requesterPublicKey": key.base64EncodedString()])
    #expect(AppwritePairingService.fields(for: .deliver(wrappedKey: key))
        == ["status": "delivered", "wrappedKey": key.base64EncodedString()])
    #expect(AppwritePairingService.fields(for: .reject) == ["status": "rejected"])
}
