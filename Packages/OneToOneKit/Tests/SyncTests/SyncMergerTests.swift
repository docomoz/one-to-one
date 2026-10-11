import Foundation
import Testing
@testable import Sync

private func record(_ seconds: Double, _ payload: String?) -> SyncRecord {
    SyncRecord(id: "herMood:2026-10-11", updatedAt: Date(timeIntervalSinceReferenceDate: seconds),
               payload: payload.map { Data($0.utf8) })
}

@Test func laterEditWins() {
    let older = record(100, #""wants""#)
    let newer = record(200, #""leaveMeAlone""#)

    #expect(SyncMerger.winner(older, newer) == newer)
    #expect(SyncMerger.winner(newer, older) == newer)
}

@Test func laterDeletionWinsAndLaterEditBeatsDeletion() {
    let edit = record(100, #""wants""#)
    let deletion = record(200, nil)
    let revived = record(300, #""neutral""#)

    #expect(SyncMerger.winner(edit, deletion) == deletion)
    #expect(SyncMerger.winner(deletion, revived) == revived)
}

@Test func tombstoneWinsTie() {
    let edit = record(100, #""wants""#)
    let deletion = record(100, nil)

    #expect(SyncMerger.winner(edit, deletion) == deletion)
    #expect(SyncMerger.winner(deletion, edit) == deletion)
}

@Test func biggerPayloadWinsTie() {
    let small = record(100, #""leaveMeAlone""#)
    let big = record(100, #""wants""#)

    #expect(SyncMerger.winner(small, big) == big)
    #expect(SyncMerger.winner(big, small) == big)
}

/// Оба телефона сливают одни и те же записи в разном порядке и должны прийти к одному результату.
@Test func winnerIsSymmetric() {
    let records = [
        record(100, #""wants""#), record(100, #""neutral""#), record(100, nil),
        record(200, #""wants""#), record(200, nil), record(50, #""leaveMeAlone""#),
    ]
    for a in records {
        for b in records {
            #expect(SyncMerger.winner(a, b) == SyncMerger.winner(b, a))
        }
    }
}
