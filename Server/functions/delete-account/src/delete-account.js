// Удаление аккаунта вызывающего. Вход: ничего, ответ: `{deleted: true}`.
// Сначала выход из всех пар (пустые пары удаляются с данными, в остальных записи остаются партнёру),
// потом удаление пользователя.
import { leaveCouple, userMemberships } from './shared/couple.js';
import { ok } from './shared/http.js';

export async function deleteAccount({ callerId }, services) {
    const memberships = await userMemberships(services.users, callerId);
    for (const coupleId of new Set(memberships.map((membership) => membership.teamId))) {
        await leaveCouple(services, coupleId, callerId);
    }
    await services.users.delete({ userId: callerId });
    return ok({ deleted: true });
}
