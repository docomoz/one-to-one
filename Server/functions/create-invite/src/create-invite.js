// Член пары без партнёра получает код приглашения. Вход: `{coupleId}`, ответ: `{code, expiresAt}`.
import { ID, Query } from 'node-appwrite';

import { confirmedOnly, coupleMemberships, DATABASE_ID, isAppwriteId, isPairedElsewhere } from './shared/couple.js';
import { deleteExpired } from './shared/expired.js';
import { fail, ok } from './shared/http.js';
import { generateInviteCode, hashInviteCode, INVITE_LIFETIME_MS } from './shared/invite-code.js';

const ATTEMPTS = 3;

export async function createInvite({ callerId, body }, services) {
    const { coupleId } = body;
    if (!isAppwriteId(coupleId)) return fail(400, 'bad_request');

    const memberships = await coupleMemberships(services.teams, coupleId);
    const members = confirmedOnly(memberships ?? []);
    if (!members.some((membership) => membership.userId === callerId)) return fail(403, 'not_member');
    if (members.length > 1) return fail(409, 'couple_full');
    // Кто уже в паре с кем-то, не приглашает в свою старую пару без партнёра: двух пар у человека не бывает.
    if (await isPairedElsewhere(services, callerId, coupleId)) return fail(409, 'already_paired');

    // У пары действует только последнее приглашение. Заодно убираем просроченные приглашения всех пар.
    await services.tablesDB.deleteRows({
        databaseId: DATABASE_ID,
        tableId: 'invites',
        queries: [Query.equal('coupleId', coupleId)],
    });
    const now = services.now();
    await deleteExpired(services.tablesDB, 'invites', now);

    const expiresAt = new Date(now.getTime() + INVITE_LIFETIME_MS).toISOString();
    for (let attempt = 1; ; attempt++) {
        const code = generateInviteCode(services.randomInt);
        try {
            await services.tablesDB.createRow({
                databaseId: DATABASE_ID,
                tableId: 'invites',
                rowId: ID.unique(),
                data: { codeHash: hashInviteCode(code), coupleId, expiresAt },
                permissions: [],
            });
            return ok({ code, expiresAt });
        } catch (thrown) {
            // 409: такой хэш уже есть (уникальный индекс). Шанс ничтожный, но тогда берём другой код.
            if (thrown?.code !== 409 || attempt === ATTEMPTS) throw thrown;
        }
    }
}
