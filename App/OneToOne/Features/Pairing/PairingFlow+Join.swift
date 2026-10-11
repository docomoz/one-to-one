import Foundation
import Sync

/// Вход в пару партнёра по коду и получение ключа пары на этот телефон.
extension PairingFlow {
    /// Вводит код приглашения и просит у телефона партнёра ключ пары.
    func join(code: String) async {
        let code = Self.normalizedCode(code)
        await perform {
            joiningCoupleID = try await service.acceptInvite(code: code)
        }
        if joiningCoupleID != nil { await startKeyRequest() }
    }

    /// Новый запрос ключа: на сервер уходит только обязательство, сам ключ — после ответа партнёра.
    /// Так же начинаем заново после отказа, истёкшего срока или перезапуска приложения.
    func startKeyRequest() async {
        guard let coupleID = joiningCoupleID else { return }
        let requester = KeyHandoffRequester()
        joinStep = .waiting
        do {
            let request = try await service.createKeyRequest(
                coupleID: coupleID, commitment: requester.commitment,
                expiresAt: now().addingTimeInterval(KeyHandoff.lifetime))
            self.requester = requester
            joinRequestID = request.id
        } catch {
            joinStep = .failed(Self.pairingError(error))
        }
    }

    /// Шаг опроса: партнёр ответил — раскрываем ключ и показываем код; оба подтвердили — забираем ключ пары.
    func pollJoin() async {
        guard !isPolling, let id = joinRequestID, var requester else { return }
        guard joinStep == .waiting || joinStep == .waitingForPartner else { return }
        isPolling = true
        defer { isPolling = false }
        do {
            guard let request = try await service.keyRequest(id: id) else {
                joinStep = .failed(.expired)
                return
            }
            if joinStep == .waiting {
                if let update = try requester.reveal(after: request, now: now()) {
                    try await service.update(request, with: update)
                    self.requester = requester
                    if let code = requester.verificationCode { joinStep = .verify(code: code) }
                }
            } else if let key = try requester.receive(request, now: now()) {
                await finishJoin(key: key)
            }
        } catch let error as KeyHandoffError {
            joinStep = .failed(PairingError(error))
        } catch {
            Self.log.error("Не удалось проверить запрос ключа, повторим: \(error)")
        }
    }

    /// Человек подтвердил, что коды совпали. Ключ возьмём, когда его отдаст телефон партнёра.
    func confirmJoin() async {
        guard case .verify = joinStep, var requester else { return }
        requester.confirm()
        self.requester = requester
        joinStep = .waitingForPartner
        await pollJoin()
    }

    /// «Не совпадает»: говорим телефону партнёра, что ключ не нужен.
    func rejectJoin() async {
        if let id = joinRequestID, let request = try? await service.keyRequest(id: id) {
            try? await service.update(request, with: .reject)
        }
        requester = nil
        joinStep = .failed(.rejected)
    }

    /// Передумали входить: выходим из пары партнёра, свои записи остаются как были.
    func cancelJoin() async {
        guard let coupleID = joiningCoupleID else { return }
        await perform {
            try await service.leaveCouple(coupleID: coupleID)
            joiningCoupleID = nil
            joinStep = nil
            requester = nil
            joinRequestID = nil
        }
    }

    /// Ключ получен. Записи этого телефона заменяются записями пары (человек видел предупреждение до ввода кода),
    /// своя пара без партнёра покидается, синхронизация переключается на пару партнёра.
    func finishJoin(key: CoupleKey) async {
        guard let newCoupleID = joiningCoupleID else { return }
        do {
            try keys.save(key, coupleID: newCoupleID)
        } catch {
            Self.log.error("Ключ пары не сохранился в Keychain: \(error)")
            joinStep = .failed(.server)
            return
        }
        if let old = coupleID, old != newCoupleID { defaults.coupleToLeave = old }
        // Сначала остановить старую синхронизацию: иначе стирание записей ушло бы в старую пару.
        model.stopSync()
        model.replaceWithJoinedCouple()
        coupleID = newCoupleID
        isCoupleOnServer = true
        partnerJoined = true
        joiningCoupleID = nil
        joinRequestID = nil
        self.requester = nil
        invite = nil
        joinStep = .done
        startSyncIfReady()
        await leaveOldCouple()
        await model.syncNow()
    }

    // MARK: - Ввод кода

    /// Как человек ввёл код («abcd-2345 ») → как его ждёт сервер: заглавные, без пробелов и дефисов.
    nonisolated static func normalizedCode(_ text: String) -> String {
        text.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    }

    /// «ABCD2345» → «ABCD-2345»: так легче продиктовать.
    nonisolated static func formattedCode(_ code: String) -> String {
        guard code.count == 8 else { return code }
        return "\(code.prefix(4))-\(code.suffix(4))"
    }
}
