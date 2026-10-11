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
        guard let coupleID = keyRequestCoupleID else { return }
        // Старый запрос закрываем: телефон партнёра не должен ждать раскрытия, которого не будет.
        await abandonKeyRequest()
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
                // Запоминаем до записи: если ответ сервера потеряется, следующий опрос отправит раскрытие ещё раз
                // или увидит, что оно уже на сервере.
                let update = try requester.reveal(after: request, now: now())
                self.requester = requester
                if let update { try await service.update(request, with: update) }
                if let code = requester.verificationCode, update != nil || request.status == .revealed {
                    joinStep = .verify(code: code)
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
        await abandonKeyRequest()
        joinStep = .failed(.rejected)
    }

    /// Закрыть свой запрос ключа на сервере (если ещё не закрыт) и забыть его.
    func abandonKeyRequest() async {
        let id = joinRequestID
        requester = nil
        joinRequestID = nil
        guard let id, let request = try? await service.keyRequest(id: id),
              request.status != .delivered, request.status != .rejected
        else { return }
        try? await service.update(request, with: .reject)
    }

    /// Передумали входить: выходим из пары партнёра, свои записи остаются как были.
    func cancelJoin() async {
        guard let coupleID = joiningCoupleID else { return }
        await perform {
            await abandonKeyRequest()
            try await service.leaveCouple(coupleID: coupleID)
            joiningCoupleID = nil
            joinStep = nil
        }
    }

    /// Ключ получен. Записи этого телефона заменяются записями пары (человек видел предупреждение до ввода кода),
    /// своя пара без партнёра покидается, синхронизация переключается на пару партнёра.
    /// При восстановлении доступа записи не стираются: это записи той же пары (после переустановки их нет,
    /// после восстановления из резервной копии они есть, и неотправленное из копии уйдёт партнёру).
    func finishJoin(key: CoupleKey) async {
        guard let newCoupleID = keyRequestCoupleID else { return }
        let isRestore = joiningCoupleID == nil
        do {
            try keys.save(key, coupleID: newCoupleID)
        } catch {
            Self.log.error("Ключ пары не сохранился в Keychain: \(error)")
            joinStep = .failed(.server)
            return
        }
        if let old = coupleID, old != newCoupleID, !defaults.couplesToLeave.contains(old) {
            defaults.couplesToLeave.append(old)
        }
        // Сначала остановить старую синхронизацию: иначе стирание записей ушло бы в старую пару.
        model.stopSync()
        if !isRestore { model.replaceWithJoinedCouple() }
        coupleID = newCoupleID
        isCoupleOnServer = true
        // Восстанавливать мог и свой второй телефон, без партнёра: сколько в паре, спросим у сервера.
        if !isRestore { partnerJoined = true }
        joiningCoupleID = nil
        restoringCoupleID = nil
        joinRequestID = nil
        self.requester = nil
        invite = nil
        joinStep = .done
        startSyncIfReady()
        await leaveOldCouples()
        await model.syncNow()
        if isRestore { await refreshPartnerJoined() }
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
