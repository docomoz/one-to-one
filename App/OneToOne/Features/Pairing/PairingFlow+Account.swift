import Foundation
import Sync

/// Чьи данные на этом телефоне и можно ли их показывать.
enum AccountState: Equatable {
    /// Проверяем: чьи данные и есть ли у человека пара на сервере.
    case checking
    /// Не получилось узнать у сервера, есть ли пара. Экран предлагает повторить.
    case failed(PairingError)
    /// Данные телефона принадлежат `userID`, экраны можно показывать.
    case ready(userID: String)
}

/// Аккаунт и пара: вход на новом телефоне или после переустановки, другой человек на том же телефоне,
/// выход из пары, выход из аккаунта и удаление аккаунта.
///
/// Что стираем и что оставляем:
/// - выход из аккаунта: записи, `SyncState.json` и настройки пары; ключ в Keychain остаётся (без членства в паре
///   он бесполезен, а тот же человек после входа откроет им записи снова; иначе одиночка потерял бы их навсегда);
/// - выход из пары и удаление аккаунта: то же и ключ пары.
extension PairingFlow {
    func isAccountReady(for userID: String?) -> Bool {
        guard let userID else { return false }
        return accountState == .ready(userID: userID)
    }

    /// После входа и при каждом запуске, до показа экранов. Вошёл другой человек — данные прежнего стираются.
    /// После переустановки id пары на телефоне нет: спрашиваем сервер. Пара есть и ключ в Keychain — берём его,
    /// ключа нет — `restoringCoupleID`, ключ попросим у партнёра. Обычный запуск обходится без сети.
    func prepareAccount(userID: String) async {
        guard !isAccountReady(for: userID) else { return }
        accountState = .checking
        if let owner = defaults.ownerUserID, owner != userID {
            Self.log.info("На телефоне данные другого аккаунта, стираем")
            forgetLocalData()
        }
        // Хозяина не было (данные появились до аккаунтов или их нет вовсе): теперь хозяин тот, кто вошёл.
        defaults.ownerUserID = userID
        if let coupleID, isCoupleOnServer, joiningCoupleID == nil, keys.load(coupleID: coupleID) == nil {
            restoringCoupleID = coupleID
        }
        let needsLookup = coupleID == nil && joiningCoupleID == nil && !model.data.isPaired
            && !defaults.coupleLookupDone
        if needsLookup {
            do {
                try await lookUpCouple(userID: userID)
            } catch {
                Self.log.error("Не удалось узнать, есть ли пара: \(error)")
                if defaults.ownerUserID == userID { accountState = .failed(Self.pairingError(error)) }
                return
            }
        }
        // Пока ждали сервер, человек мог выйти, а на телефоне — войти другой: его состояние не трогаем.
        guard defaults.ownerUserID == userID else { return }
        accountState = .ready(userID: userID)
    }

    /// Пара этого человека на сервере. Если их несколько, берём пару с партнёром, а свои пустые покидаем,
    /// как после входа по коду (`leaveOldCouples`).
    private func lookUpCouple(userID: String) async throws {
        var found: [(id: String, members: Int, hasKey: Bool)] = []
        for id in try await service.couples() {
            found.append((id, try await service.memberCount(coupleID: id), keys.load(coupleID: id) != nil))
        }
        guard defaults.ownerUserID == userID else { return }
        defaults.coupleLookupDone = true
        guard let chosen = found.max(by: { ($0.members, $0.hasKey ? 1 : 0) < ($1.members, $1.hasKey ? 1 : 0) }) else {
            return
        }
        if chosen.members > 1 {
            for other in found where other.id != chosen.id && other.members == 1
                && !defaults.couplesToLeave.contains(other.id) {
                defaults.couplesToLeave.append(other.id)
            }
        }
        coupleID = chosen.id
        isCoupleOnServer = true
        partnerJoined = chosen.members > 1
        if !chosen.hasKey { restoringCoupleID = chosen.id }
    }

    // MARK: - Новый телефон

    /// Ключа нет ни у кого (одиночка потерял телефон) или не хочется ждать партнёра: выйти из старой пары
    /// и начать заново. Старые записи на этом телефоне так и не откроются; у партнёра они останутся.
    func abandonRestore() async {
        guard let coupleID = restoringCoupleID else { return }
        await leave(coupleID) { await abandonKeyRequest() }
    }

    // MARK: - Выход из пары

    /// «Выйти из пары»: функция `leave-couple`, затем с телефона стираются записи пары, `SyncState.json`, ключ
    /// и настройки пары, и человек возвращается в знакомство. Без сети ничего не меняется, ошибка на экране.
    /// Сервер больше не отдаёт ему документы пары; новая пара начнётся с нового ключа.
    @discardableResult
    func leaveCouple() async -> Bool {
        guard let coupleID else { return false }
        // Последние правки успеваем отдать партнёру. Не вышло — не страшно, выход их всё равно сотрёт.
        await model.syncNow()
        return await leave(coupleID) {}
    }

    private func leave(_ coupleID: String, before: () async -> Void) async -> Bool {
        var left = false
        await perform {
            await before()
            do {
                try await service.leaveCouple(coupleID: coupleID)
            } catch PairingError.notMember {
                // Уже не в паре: например, прошлый выход дошёл до сервера, а ответ потерялся.
            }
            left = true
        }
        guard left else { return false }
        // Стираем до того, как появится движок новой пары: иначе старые записи ушли бы в неё.
        model.wipeCoupleData()
        keys.delete(coupleID: coupleID)
        resetCoupleState()
        // Пары у человека больше нет, спрашивать сервер при следующем запуске незачем.
        defaults.coupleLookupDone = true
        return true
    }

    // MARK: - Выход из аккаунта и удаление

    /// Есть ли правки, которых нет на сервере: при выходе из аккаунта они пропадут. Сначала пробуем их отправить.
    func hasUnsentChanges() async -> Bool {
        await model.syncNow()
        await model.syncChangesRecorded()
        let state: SyncState
        if let current = await model.syncState {
            state = current
        } else if let coupleID {
            state = model.syncStateStore.load(coupleID: coupleID)
        } else {
            // Пары на сервере нет: всё на телефоне существует только здесь.
            state = SyncState()
        }
        return state.hasUnsentChanges(in: model.data)
    }

    /// Выход из аккаунта. Получилось — следующий, кто войдёт на этом телефоне, ничего прежнего не увидит.
    /// Ключ остаётся в Keychain: вернувшись с той же почтой, человек откроет записи без партнёра.
    func signOut(auth: AuthFlow) async {
        // Свой запрос ключа закрываем, пока есть вход: иначе телефон партнёра ждал бы раскрытия, которого не будет.
        await abandonKeyRequest()
        await auth.signOut()
        guard auth.userID == nil else { return }
        forgetLocalData()
    }

    /// «Удалить аккаунт»: функция `delete-account` (выход из всех пар и удаление пользователя), затем стираем
    /// с телефона всё, включая ключи, и выходим. Если в паре остался партнёр, записи остаются у него.
    func deleteAccount(auth: AuthFlow) async {
        var deleted = false
        await perform {
            do {
                try await service.deleteAccount()
            } catch PairingError.signedOut {
                // Сессии нет: прошлое удаление дошло до сервера, а ответ потерялся (или вход истёк).
                // Человек хотел удалить аккаунт — стираем телефон и выходим; войдёт снова, если аккаунт остался.
            }
            deleted = true
        }
        guard deleted else { return }
        let couples = [coupleID, joiningCoupleID, restoringCoupleID].compactMap { $0 } + defaults.couplesToLeave
        for id in Set(couples) { keys.delete(coupleID: id) }
        forgetLocalData()
        await auth.accountDeleted()
    }

    /// Стереть с телефона записи пары, состояние синхронизации и всё о паре и аккаунте. Ключи не трогает.
    func forgetLocalData() {
        model.wipeCoupleData()
        resetCoupleState()
        defaults.removeAll()
        accountState = .checking
    }

    /// Пары на этом телефоне больше нет: ни id, ни шагов передачи ключа.
    private func resetCoupleState() {
        registration?.cancel()
        registration = nil
        coupleID = nil
        isCoupleOnServer = false
        joiningCoupleID = nil
        partnerJoined = false
        partnerLeft = false
        restoringCoupleID = nil
        invite = nil
        joinStep = nil
        requester = nil
        joinRequestID = nil
        dismissIncoming()
        answeredElsewhere = []
    }
}
