// Создание пары. Вход: `{coupleId?}` (id придумывает приложение, чтобы повтор после потерянного ответа
// не создал вторую пару), ответ: `{coupleId}`. Ошибки: already_paired, not_member, bad_request.
//
// Пару создаёт сервер, а не приложение: команда, созданная из приложения, сделала бы создателя её владельцем,
// а владелец может сам добавить в команду кого угодно мимо `accept-invite`. Здесь команда создаётся ключом сервера
// без владельца, а вызывающий входит в неё с ролью `partner`. Добавлять людей в пару может только сервер.
import { ID } from 'node-appwrite';

import { confirmedOnly, coupleMemberships, isAppwriteId, isPairedElsewhere } from './shared/couple.js';
import { fail, ok } from './shared/http.js';

const isConflict = (thrown) => thrown?.code === 409;

export async function createCouple({ callerId, body }, services) {
    const { teams } = services;
    if (body.coupleId !== undefined && !isAppwriteId(body.coupleId)) return fail(400, 'bad_request');
    const coupleId = body.coupleId ?? ID.unique();

    if (await isPairedElsewhere(services, callerId, coupleId)) return fail(409, 'already_paired');

    let created = true;
    try {
        await teams.create({ teamId: coupleId, name: 'couple' });
    } catch (thrown) {
        if (!isConflict(thrown)) throw thrown;
        created = false; // повтор: пара с этим id уже есть
    }

    const members = confirmedOnly((await coupleMemberships(teams, coupleId)) ?? []);
    if (members.some((membership) => membership.userId === callerId)) return ok({ coupleId });
    // Чужая пара: в неё входят только по приглашению.
    if (members.length > 0) return fail(403, 'not_member');

    try {
        // С ключом сервера членство создаётся сразу подтверждённым, без письма.
        await teams.createMembership({ teamId: coupleId, roles: ['partner'], userId: callerId });
    } catch (thrown) {
        // Два одновременных вызова с одним id: второй уже добавил вызывающего — пара есть, это успех.
        const after = confirmedOnly((await coupleMemberships(teams, coupleId).catch(() => null)) ?? []);
        if (after.some((membership) => membership.userId === callerId)) return ok({ coupleId });
        // Пустая команда никому не нужна; если удалить не вышло, её дочистит `leave-couple`.
        if (created && after.length === 0) await teams.delete({ teamId: coupleId }).catch(() => {});
        throw thrown;
    }
    return ok({ coupleId });
}
