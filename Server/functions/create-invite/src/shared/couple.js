// Пара = команда Appwrite. Общие действия с парой для всех функций.
// Источник правды — Server/functions/shared/, в функциях лежат копии (Server/functions/sync-shared.sh).
import { Query } from 'node-appwrite';

import { fail, ok } from './http.js';

export const DATABASE_ID = 'main';
export const COUPLE_TABLES = ['records', 'keyRequests', 'invites'];
const PAGE_SIZE = 100;

// Id в Appwrite: до 36 символов, буквы, цифры, точка, дефис, подчёркивание, не со спецсимвола.
export const isAppwriteId = (value) => typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9._-]{0,35}$/.test(value);

export const isNotFound = (thrown) => thrown?.code === 404;

async function listAllMemberships(fetchPage) {
    const all = [];
    for (;;) {
        const queries = [Query.limit(PAGE_SIZE)];
        if (all.length > 0) queries.push(Query.cursorAfter(all.at(-1).$id));
        const { memberships } = await fetchPage(queries);
        all.push(...memberships);
        if (memberships.length < PAGE_SIZE) return all;
    }
}

// Все членства команды, включая неподтверждённые. `null`, если команды нет.
export async function coupleMemberships(teams, coupleId) {
    try {
        return await listAllMemberships((queries) => teams.listMemberships({ teamId: coupleId, queries }));
    } catch (thrown) {
        if (isNotFound(thrown)) return null;
        throw thrown;
    }
}

export function userMemberships(users, userId) {
    return listAllMemberships((queries) => users.listMemberships({ userId, queries }));
}

// Члены пары — только подтверждённые членства. Неподтверждённое приглашение по почте доступа к данным не даёт
// и не мешает ни приглашать, ни удалять пустую пару.
export const confirmedOnly = (memberships) => memberships.filter((membership) => membership.confirm);

// «В другой паре» — в команде, где кроме него есть ещё кто-то подтверждённый. Своя пара без партнёра не в счёт:
// так пользуются приложением в одиночку, и из неё приложение выходит само после входа в новую.
export async function isPairedElsewhere({ teams, users }, callerId, coupleId) {
    for (const membership of await userMemberships(users, callerId)) {
        if (membership.teamId === coupleId || !membership.confirm) continue;
        const members = await coupleMemberships(teams, membership.teamId);
        if (members !== null && confirmedOnly(members).some((other) => other.userId !== callerId)) return true;
    }
    return false;
}

// Удаляет записи, запросы ключа и приглашения пары. Команду удаляет последней:
// если что-то упадёт посередине, повторный вызов доудалит остальное.
async function deleteCouple({ tablesDB, teams }, coupleId) {
    for (const tableId of COUPLE_TABLES) {
        await tablesDB.deleteRows({ databaseId: DATABASE_ID, tableId, queries: [Query.equal('coupleId', coupleId)] });
    }
    try {
        await teams.delete({ teamId: coupleId });
    } catch (thrown) {
        if (!isNotFound(thrown)) throw thrown;
    }
}

const hasOthers = (memberships, callerId) =>
    confirmedOnly(memberships).some((membership) => membership.userId !== callerId);

// Выход из пары. Если подтверждённых членов не осталось, удаляются команда (вместе с неподтверждёнными
// приглашениями) и все данные пары. Пустую команду (прошлый выход упал посередине) дочищает любой вызов:
// её данные уже никому не видны.
export async function leaveCouple(services, coupleId, callerId) {
    const memberships = await coupleMemberships(services.teams, coupleId);
    if (memberships === null) return fail(403, 'not_member');

    const mine = memberships.filter((membership) => membership.userId === callerId);
    if (mine.length === 0 && hasOthers(memberships, callerId)) return fail(403, 'not_member');

    for (const membership of mine) {
        await services.teams.deleteMembership({ teamId: coupleId, membershipId: membership.$id });
    }

    // Смотрим заново, а не по старому списку: если оба вышли одновременно, каждый видел бы второго,
    // и пустая пара с данными осталась бы навсегда. Удалить пару дважды не страшно.
    const remaining = await coupleMemberships(services.teams, coupleId);
    if (remaining !== null && hasOthers(remaining, callerId)) return ok({ left: true, coupleDeleted: false });

    await deleteCouple(services, coupleId);
    return ok({ left: true, coupleDeleted: true });
}
