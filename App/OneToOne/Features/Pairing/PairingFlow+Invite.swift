import Foundation
import Sync

/// Приглашение и передача ключа с этого телефона партнёру (этот телефон отвечает на запрос ключа).
extension PairingFlow {
    /// Код приглашения для партнёра. Пары на сервере ещё нет (не было сети) — сначала создаёт её.
    func createInvite() async {
        if !isCoupleOnServer { await registerCouple() }
        guard let coupleID, isCoupleOnServer else { return }
        await perform {
            do {
                invite = try await service.createInvite(coupleID: coupleID)
            } catch PairingError.coupleFull {
                partnerJoined = true
                throw PairingError.coupleFull
            }
        }
    }

    /// Узнать у сервера, вошёл ли партнёр. Без сети оставляем, что знали.
    func refreshPartnerJoined() async {
        guard let coupleID, isCoupleOnServer, !partnerJoined else { return }
        if let count = try? await service.memberCount(coupleID: coupleID), count > 1 {
            partnerJoined = true
        }
    }

    /// Есть ли новый запрос ключа от телефона партнёра. Если есть — отвечаем своим открытым ключом
    /// и ждём, пока тот раскроет свой (`pollIncoming`).
    func checkIncoming() async {
        guard incomingStep == nil, !isPolling, let coupleID, isCoupleOnServer,
              let key = keys.load(coupleID: coupleID)
        else { return }
        isPolling = true
        defer { isPolling = false }
        do {
            let requests = try await service.keyRequests(coupleID: coupleID)
            guard let request = KeyHandoff.pendingRequest(in: requests, now: now()) else { return }
            var responder = KeyHandoffResponder(key: key)
            let update = try responder.answer(request, now: now())
            try await service.update(request, with: update)
            self.responder = responder
            incomingRequestID = request.id
            incomingStep = .waiting
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
            do {
                let code = try responder.verify(request, now: now())
                self.responder = responder
                if let code { incomingStep = .verify(code: code) }
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

    /// Закрыли окно сверки: следующий запрос ключа можно будет показать заново.
    func dismissIncoming() {
        incomingStep = nil
        responder = nil
        incomingRequestID = nil
    }
}
