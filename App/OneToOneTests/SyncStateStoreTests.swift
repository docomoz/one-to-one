import Foundation
import Sync
import Testing
@testable import OneToOne

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "SyncStateStoreTests-\(UUID().uuidString)")
}

private let state = SyncState(
    known: ["period:2026-10-11": SyncRecord(id: "period:2026-10-11", updatedAt: Date(timeIntervalSince1970: 5),
                                            payload: Data("{}".utf8))],
    cursor: "2026-10-11T10:00:00.123+00:00"
)

@Test func syncStateSurvivesRestart() throws {
    let directory = temporaryDirectory()
    try SyncStateStore(directory: directory).save(state, coupleID: "c1")

    #expect(SyncStateStore(directory: directory).load(coupleID: "c1") == state)
    #expect(FileManager.default.fileExists(atPath: directory.appending(path: "SyncState.json").path()))
}

/// Состояние другой пары (курсор, известные записи) к новой паре не подходит.
@Test func syncStateOfOtherCoupleIgnored() throws {
    let directory = temporaryDirectory()
    try SyncStateStore(directory: directory).save(state, coupleID: "c1")

    #expect(SyncStateStore(directory: directory).load(coupleID: "c2") == SyncState())
}

@Test func missingOrBrokenSyncStateStartsFresh() throws {
    let directory = temporaryDirectory()
    #expect(SyncStateStore(directory: directory).load(coupleID: "c1") == SyncState())

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("мусор".utf8).write(to: directory.appending(path: "SyncState.json"))
    #expect(SyncStateStore(directory: directory).load(coupleID: "c1") == SyncState())
}

@Test func debugKeyHexRoundTrip() throws {
    let key = CoupleKey()
    let hex = DebugSyncSettings.hex(key)

    #expect(hex.count == 64)
    #expect(DebugSyncSettings.key(fromHex: hex.uppercased()) == key)
    #expect(DebugSyncSettings.key(fromHex: " \(hex.prefix(32))\n\(hex.dropFirst(32)) ") == key)
    #expect(DebugSyncSettings.key(fromHex: String(hex.dropLast())) == nil)
    #expect(DebugSyncSettings.key(fromHex: String(repeating: "zz", count: 32)) == nil)
    #expect(DebugSyncSettings.key(fromHex: String(repeating: "+f", count: 32)) == nil)
}
