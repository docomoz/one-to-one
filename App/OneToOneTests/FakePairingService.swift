import Foundation
import Synchronization
import Sync
@testable import OneToOne

/// Сервер пар в памяти: команды, приглашения и `keyRequests`. Общий для двух «телефонов» в тесте.
/// Правила как у функций в Server/functions: в паре не больше двух, код одноразовый.
final class FakePairingServer: Sendable {
    struct State {
        var teams: [String: [String]] = [:]
        var invites: [String: String] = [:]
        var requests: [String: KeyRequest] = [:]
        var left: [(coupleID: String, userID: String)] = []
        var nextID = 1
    }

    let state = Mutex(State())
    /// Сервер-злоумышленник: меняет строку запроса перед тем, как отдать её телефону `reader`.
    let tamper = Mutex<(@Sendable (_ request: KeyRequest, _ reader: String) -> KeyRequest)?>(nil)

    func members(_ coupleID: String) -> [String] {
        state.withLock { $0.teams[coupleID] ?? [] }
    }

    var requests: [KeyRequest] {
        state.withLock { Array($0.requests.values) }
    }

    var left: [(coupleID: String, userID: String)] {
        state.withLock { $0.left }
    }
}

/// Сеть одного телефона до `FakePairingServer`, от имени `userID`. `failure` — следующий вызов упадёт с ней.
final class FakePairingService: PairingService {
    let server: FakePairingServer
    let userID: String
    let failure = Mutex<PairingError?>(nil)
    /// Задержка каждого ответа: чтобы вызовы с экрана и из таймера шли одновременно, как в жизни.
    let latency = Mutex<Duration?>(nil)
    /// Следующая запись в строку запроса дойдёт до сервера, а ответ потеряется (ошибка сети).
    let loseNextUpdateResponse = Mutex(false)

    init(server: FakePairingServer = FakePairingServer(), userID: String) {
        self.server = server
        self.userID = userID
    }

    private func checkFailure() async throws {
        if let latency = latency.withLock({ $0 }) { try? await Task.sleep(for: latency) }
        if let error = failure.withLock({ error in defer { error = nil }; return error }) { throw error }
    }

    func createCouple(coupleID: String) async throws -> String {
        try await checkFailure()
        return try server.state.withLock { state in
            if let members = state.teams[coupleID] {
                guard members.contains(userID) else { throw PairingError.notMember }
                return coupleID
            }
            let pairedElsewhere = state.teams.values.contains { $0.contains(userID) && $0.count > 1 }
            if pairedElsewhere { throw PairingError.alreadyPaired }
            state.teams[coupleID] = [userID]
            return coupleID
        }
    }

    func createInvite(coupleID: String) async throws -> InviteCode {
        try await checkFailure()
        return try server.state.withLock { state in
            guard let members = state.teams[coupleID], members.contains(userID) else { throw PairingError.notMember }
            guard members.count == 1 else { throw PairingError.coupleFull }
            let code = "CODE\(state.nextID)AB"
            state.nextID += 1
            state.invites = state.invites.filter { $0.value != coupleID }
            state.invites[code] = coupleID
            return InviteCode(code: code, expiresAt: Date().addingTimeInterval(7 * 24 * 3600))
        }
    }

    func acceptInvite(code: String) async throws -> String {
        try await checkFailure()
        return try server.state.withLock { state in
            guard let coupleID = state.invites[code], let members = state.teams[coupleID] else {
                throw PairingError.inviteNotFound
            }
            if members.contains(userID) { throw PairingError.alreadyPaired }
            guard members.count == 1 else { throw PairingError.coupleFull }
            state.invites[code] = nil
            state.teams[coupleID] = members + [userID]
            return coupleID
        }
    }

    func leaveCouple(coupleID: String) async throws {
        try await checkFailure()
        server.state.withLock { state in
            state.left.append((coupleID, userID))
            state.teams[coupleID]?.removeAll { $0 == userID }
            if state.teams[coupleID]?.isEmpty == true { state.teams[coupleID] = nil }
        }
    }

    func memberCount(coupleID: String) async throws -> Int {
        try await checkFailure()
        return server.members(coupleID).count
    }

    func createKeyRequest(coupleID: String, commitment: Data, expiresAt: Date) async throws -> KeyRequest {
        try await checkFailure()
        return try server.state.withLock { state in
            guard state.teams[coupleID]?.contains(userID) == true else { throw PairingError.notMember }
            let request = KeyRequest(id: "req\(state.nextID)", coupleID: coupleID, requesterUserID: userID,
                                     requesterKeyCommitment: commitment, status: .waiting, expiresAt: expiresAt)
            state.nextID += 1
            state.requests[request.id] = request
            return request
        }
    }

    func keyRequest(id: String) async throws -> KeyRequest? {
        try await checkFailure()
        guard let request = server.state.withLock({ $0.requests[id] }) else { return nil }
        return server.tamper.withLock { $0 }.map { $0(request, userID) } ?? request
    }

    func keyRequests(coupleID: String) async throws -> [KeyRequest] {
        try await checkFailure()
        let tamper = server.tamper.withLock { $0 }
        let requests: [KeyRequest] = server.state.withLock { state in
            guard state.teams[coupleID]?.contains(userID) == true else { return [] }
            return state.requests.values.filter { $0.coupleID == coupleID }
        }
        return requests.map { tamper?($0, userID) ?? $0 }
    }

    func update(_ request: KeyRequest, with update: KeyRequestUpdate) async throws {
        try await checkFailure()
        server.state.withLock { state in
            guard let stored = state.requests[request.id] else { return }
            state.requests[request.id] = stored.applying(update)
        }
        if loseNextUpdateResponse.withLock({ lose in defer { lose = false }; return lose }) {
            throw PairingError.network
        }
    }
}
