// Вход в пару по коду приглашения. Вход: `{code}`, ответ: `{coupleId}`.
// Ошибки: invite_not_found, invite_expired, couple_full, already_paired.
import { Query } from 'node-appwrite';

import { confirmedOnly, coupleMemberships, DATABASE_ID, isNotFound, isPairedElsewhere } from './shared/couple.js';
import { fail, ok } from './shared/http.js';
import { hashInviteCode, normalizeInviteCode } from './shared/invite-code.js';

const notFound = () => fail(404, 'invite_not_found');

async function findInvite(tablesDB, code) {
    const { rows } = await tablesDB.listRows({
        databaseId: DATABASE_ID,
        tableId: 'invites',
        queries: [Query.equal('codeHash', hashInviteCode(code)), Query.limit(1)],
    });
    return rows[0] ?? null;
}

// Удаляет приглашение. `false`, если его уже удалил кто-то другой (код только что использован).
async function deleteInvite(tablesDB, invite) {
    try {
        await tablesDB.deleteRow({ databaseId: DATABASE_ID, tableId: 'invites', rowId: invite.$id });
        return true;
    } catch (thrown) {
        if (isNotFound(thrown)) return false;
        throw thrown;
    }
}

// Возвращает приглашение, если войти не получилось из-за сбоя: код должен остаться рабочим.
async function restoreInvite(tablesDB, invite) {
    const { codeHash, coupleId, expiresAt } = invite;
    try {
        await tablesDB.createRow({
            databaseId: DATABASE_ID,
            tableId: 'invites',
            rowId: invite.$id,
            data: { codeHash, coupleId, expiresAt },
            permissions: [],
        });
    } catch {
        // Не вышло — партнёр сделает новое приглашение. Главное — не скрыть исходную ошибку.
    }
}

// Кто вошёл раньше: по времени членства, при равенстве — по id. Одинаково для всех вызовов.
const joinedEarlier = (a, b) => (a.$createdAt ?? '').localeCompare(b.$createdAt ?? '') || a.$id.localeCompare(b.$id);

export async function acceptInvite({ callerId, body }, services) {
    const { tablesDB, teams } = services;
    const code = normalizeInviteCode(body.code);
    if (code === null) return notFound();

    const invite = await findInvite(tablesDB, code);
    if (invite === null) return notFound();

    if (Date.parse(invite.expiresAt) <= services.now().getTime()) {
        await deleteInvite(tablesDB, invite);
        return fail(410, 'invite_expired');
    }

    const memberships = await coupleMemberships(teams, invite.coupleId);
    const members = memberships === null ? [] : confirmedOnly(memberships);
    if (members.length === 0) {
        await deleteInvite(tablesDB, invite);
        return notFound();
    }
    if (members.some((membership) => membership.userId === callerId)) return fail(409, 'already_paired');
    if (members.length > 1) return fail(409, 'couple_full');
    if (await isPairedElsewhere(services, callerId, invite.coupleId)) return fail(409, 'already_paired');

    // Сначала забираем приглашение: из двух одновременных вызовов с одним кодом удалить его сможет только один.
    if (!(await deleteInvite(tablesDB, invite))) return notFound();

    let joined;
    try {
        // С ключом сервера членство создаётся сразу подтверждённым, без письма.
        joined = await teams.createMembership({ teamId: invite.coupleId, roles: ['partner'], userId: callerId });
    } catch (thrown) {
        if (isNotFound(thrown)) return notFound(); // пару только что удалили
        await restoreInvite(tablesDB, invite);
        throw thrown;
    }

    // Страховка от гонки двух разных приглашений одной пары: остаются двое, вошедшие раньше,
    // остальные выходят. Порядок одинаков для всех, поэтому хотя бы один партнёр всегда остаётся.
    const after = await coupleMemberships(teams, invite.coupleId);
    if (after === null) return notFound();
    const keep = confirmedOnly(after).sort(joinedEarlier).slice(0, 2);
    if (!keep.some((membership) => membership.$id === joined.$id)) {
        await teams.deleteMembership({ teamId: invite.coupleId, membershipId: joined.$id });
        return fail(409, 'couple_full');
    }

    return ok({ coupleId: invite.coupleId });
}
