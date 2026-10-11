import Foundation
import Sync

/// Приглашение и передача ключа с этого телефона партнёру (этот телефон отвечает на запрос ключа).
extension PairingFlow {
    /// Код приглашения для партнёра. Пары на сервере ещё нет (не было сети) — сначала создаёт её.
    func createInvite() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        if !isCoupleOnServer { await registerCouple() }
        guard let coupleID, isCoupleOnServer else { return }
        do {
            invite = try await service.createInvite(coupleID: coupleID)
        } catch {
            let error = Self.pairingError(error)
            if error == .coupleFull { partnerJoined = true }
            errorMessage = error.message
        }
    }

    /// Узнать у сервера, вошёл ли партнёр или вышел ли он. Без сети оставляем, что знали.
    func refreshPartnerJoined() async {
        guard let coupleID, isCoupleOnServer, let count = try? await service.memberCount(coupleID: coupleID) else { return }
        if count > 1 {
            partnerJoined = true
            partnerLeft = false
        } else if partnerJoined {
            partnerLeft = true
        }
    }

    /// Есть ли новый запрос ключа от телефона партнёра. Если есть — отвечаем своим открытым ключом
    /// и ждём, пока тот раскроет свой (`pollIncoming`).
    func checkIncoming() async {
        guard incomingStep == nil, !isPolling else { return }
        isPolling = true
        defer { isPolling = false }
        await answerNewestRequest()
    }

    /// Ответить на самый новый ждущий запрос. Шаг ставим до записи на сервер: если ответ потеряется,
    /// `pollIncoming` отправит его ещё раз.
    private func answerNewestRequest(replacing current: KeyRequest? = nil) async {
        guard let coupleID, isCoupleOnServer, let key = keys.load(coupleID: coupleID) else { return }
        do {
            let requests = try await service.keyRequests(coupleID: coupleID)
            // Свой запрос (этот телефон сам просит ключ) и запросы, на которые ответил другой телефон, пропускаем.
            let skipped = answeredElsewhere.union([joinRequestID].compactMap { $0 })
            guard let request = KeyHandoff.pendingRequest(in: requests, now: now(), excluding: skipped),
                  request.id != incomingRequestID
            else { return }
            // Телефон партнёра начал заново (перезапуск, «Начать заново»): старый запрос закрываем.
            if let current { try? await service.update(current, with: .reject) }
            var responder = KeyHandoffResponder(key: key)
            let update = try responder.answer(request, now: now())
            self.responder = responder
            incomingRequestID = request.id
            incomingStep = .waiting
            try await service.update(request, with: update)
            // Второй телефон с ключом (свой второй или партнёра) мог ответить одновременно и перезаписать наш ответ.
            // Сравнивать и писать одним запросом Appwrite не умеет, поэтому перечитываем: запрос достаётся тому,
            // чей ответ остался в строке. Если перезапишут позже, это поймает `pollIncoming`.
            if let stored = try await service.keyRequest(id: request.id), stored.responderPublicKey != nil,
               !responder.owns(stored) {
                withdrawIncoming()
            }
        } catch {
            // Не ответили — попробуем при следующей проверке.
            Self.log.error("Не удалось ответить на запрос ключа: \(error)")
        }
    }

    /// Второй телефон раскрыл ключ? Проверяем его по обязательству и показываем код.
    func pollIncoming() async {
        guard incomingStep == .waiting, !isPolling, let id = incomingRequestID, var responder else { return }
        isPolling = true
        defer { isPolling = false }
        do {
            guard let request = try await service.keyRequest(id: id) else {
                incomingStep = .failed(.expired)
                return
            }
            // Наш ответ не дошёл до сервера: отправляем ещё раз.
            if request.status == .waiting, request.responderPublicKey == nil, !request.isExpired(at: now()) {
                try await service.update(request, with: .answer(responderPublicKey: responder.publicKey))
                return
            }
            do {
                let code = try responder.verify(request, now: now())
                self.responder = responder
                if let code {
                    incomingStep = .verify(code: code)
                } else {
                    // Пока ждём раскрытия, телефон партнёра мог начать заново новым запросом.
                    await answerNewestRequest(replacing: request)
                }
            } catch .answeredElsewhere {
                withdrawIncoming()
            } catch {
                self.responder = responder
                // Подмену видим только мы: говорим второму телефону, что ключа не будет.
                if error != .rejected { try? await service.update(request, with: .reject) }
                incomingStep = .failed(PairingError(error))
            }
        } catch {
            Self.log.error("Не удалось проверить запрос ключа, повторим: \(error)")
        }
    }

    /// Человек подтвердил, что коды совпали: отдаём завёрнутый ключ.
    func confirmIncoming() async {
        guard case .verify = incomingStep, !isWorking, let id = incomingRequestID, let responder else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            guard let request = try await service.keyRequest(id: id) else { throw PairingError.expired }
            // Второй телефон мог отказаться, пока человек смотрел на код.
            if request.status == .rejected { throw PairingError.rejected }
            try await service.update(request, with: try responder.deliver())
            incomingStep = .done
            partnerJoined = true
            invite = nil
        } catch {
            let error = Self.pairingError(error)
            // Без сети код остаётся на экране: можно нажать ещё раз.
            if error == .network { errorMessage = error.message } else { incomingStep = .failed(error) }
        }
    }

    /// «Не совпадает»: ключ не отдаём.
    func rejectIncoming() async {
        guard let id = incomingRequestID, var responder else { return }
        let update = responder.reject()
        self.responder = responder
        if let request = try? await service.keyRequest(id: id) {
            try? await service.update(request, with: update)
        }
        incomingStep = .failed(.rejected)
    }

    /// На запрос ответил другой телефон с ключом: тихо отходим. Запросу не отказываем (передача идёт с тем телефоном),
    /// ключ не отдаём и на этот запрос больше не отвечаем.
    func withdrawIncoming() {
        if let incomingRequestID { answeredElsewhere.insert(incomingRequestID) }
        dismissIncoming()
    }

    /// Закрыли окно сверки: следующий запрос ключа можно будет показать заново.
    func dismissIncoming() {
        incomingStep = nil
        responder = nil
        incomingRequestID = nil
        errorMessage = nil
    }
}
