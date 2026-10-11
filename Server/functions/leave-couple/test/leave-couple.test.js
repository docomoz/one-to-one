import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { FakeAppwrite, fakeContext } from '../../test-support/fake-appwrite.js';
import { assertSharedCopiesMatch } from '../../test-support/shared-copies.js';
import { leaveCouple } from '../src/leave-couple.js';
import { handle } from '../src/main.js';

// По записи каждого вида у пары couple1 и у чужой пары couple2.
function withCoupleData(fake) {
    for (const coupleId of ['couple1', 'couple2']) {
        fake.addRow('records', { coupleId, envelope: 'AQ==', deleted: false });
        fake.addRow('keyRequests', { coupleId, requesterUserId: 'x', status: 'waiting' });
        fake.addRow('invites', { coupleId, codeHash: `hash-${coupleId}` });
    }
    return fake;
}

const coupleIds = (fake, tableId) => fake.rows(tableId).map((row) => row.coupleId);
const leave = (fake, callerId, coupleId = 'couple1') =>
    leaveCouple({ callerId, body: { coupleId } }, fake.services());

test('leaveCoupleDeletesEmptyCoupleData', async () => {
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', ['anna']);
    fake.addTeam('couple2', ['vera']);
    withCoupleData(fake);

    const result = await leave(fake, 'anna');

    assert.deepEqual(result, { status: 200, body: { left: true, coupleDeleted: true } });
    assert.equal(fake.teamsById.has('couple1'), false);
    assert.deepEqual(coupleIds(fake, 'records'), ['couple2']);
    assert.deepEqual(coupleIds(fake, 'keyRequests'), ['couple2']);
    assert.deepEqual(coupleIds(fake, 'invites'), ['couple2']);
    assert.deepEqual(fake.memberIds('couple2'), ['vera']);
    // Команда удаляется последней: если удаление записей упадёт, повторный вызов их доудалит.
    assert.deepEqual(fake.calls.at(-1), ['teams.delete', 'couple1']);
});

test('leaveCoupleKeepsDataWhenPartnerStays', async () => {
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', ['anna', 'boris']);
    fake.addTeam('couple2', ['vera']);
    withCoupleData(fake);

    const result = await leave(fake, 'boris');

    assert.deepEqual(result, { status: 200, body: { left: true, coupleDeleted: false } });
    assert.deepEqual(fake.memberIds('couple1'), ['anna']);
    assert.deepEqual(coupleIds(fake, 'records'), ['couple1', 'couple2']);
    assert.deepEqual(coupleIds(fake, 'keyRequests'), ['couple1', 'couple2']);
});

test('leaveCoupleRejectsStranger', async () => {
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', ['anna']);
    withCoupleData(fake);

    const result = await leave(fake, 'mallory');

    assert.deepEqual(result, { status: 403, body: { error: 'not_member' } });
    assert.deepEqual(fake.memberIds('couple1'), ['anna']);
    assert.equal(fake.rows('records').length, 2);
});

test('leaveCoupleRejectsUnknownCouple', async () => {
    const fake = new FakeAppwrite();

    const result = await leave(fake, 'anna', 'nope');

    assert.deepEqual(result, { status: 403, body: { error: 'not_member' } });
});

test('leaveCoupleFinishesCleanupOfEmptyCouple', async () => {
    // Прошлый вызов успел удалить членство, но не данные: команда пустая, её данные никому не видны.
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', []);
    withCoupleData(fake);

    const result = await leave(fake, 'anna');

    assert.deepEqual(result, { status: 200, body: { left: true, coupleDeleted: true } });
    assert.deepEqual(coupleIds(fake, 'records'), ['couple2']);
    assert.equal(fake.teamsById.has('couple1'), false);
});

test('leaveCoupleDeletesDataWhenBothLeaveAtOnce', async () => {
    // Борис выходит в тот же момент: Анна прочитала список с ним, а после её выхода его уже нет.
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', ['anna', 'boris']);
    withCoupleData(fake);
    const deleteMembership = fake.teams.deleteMembership;
    fake.teams.deleteMembership = async (params) => {
        const boris = fake.teamsById.get('couple1').find((m) => m.userId === 'boris');
        if (boris) await deleteMembership({ teamId: 'couple1', membershipId: boris.$id });
        return deleteMembership(params);
    };

    const result = await leave(fake, 'anna');

    assert.deepEqual(result, { status: 200, body: { left: true, coupleDeleted: true } });
    assert.equal(fake.teamsById.has('couple1'), false);
    assert.deepEqual(coupleIds(fake, 'records'), ['couple2']);
});

test('leaveCoupleIgnoresPendingInvitation', async () => {
    // Неподтверждённое приглашение по почте не держит пару: иначе приглашённый потом получил бы чужие записи.
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', ['anna']);
    fake.join('couple1', 'eve', { confirm: false });
    withCoupleData(fake);

    const result = await leave(fake, 'anna');

    assert.deepEqual(result, { status: 200, body: { left: true, coupleDeleted: true } });
    assert.equal(fake.teamsById.has('couple1'), false);
});

test('leaveCoupleRejectsBadCoupleId', async () => {
    const fake = new FakeAppwrite();

    const result = await leave(fake, 'anna', { $ne: '' });

    assert.deepEqual(result, { status: 400, body: { error: 'bad_request' } });
});

test('mainTakesCallerFromHeaderNotFromBody', async () => {
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', ['anna', 'boris']);
    const context = fakeContext({ userId: 'mallory', body: JSON.stringify({ coupleId: 'couple1', userId: 'anna' }) });

    const response = await handle(context, () => fake.services());

    assert.deepEqual(response, { data: { error: 'not_member' }, statusCode: 403 });
    assert.deepEqual(fake.memberIds('couple1'), ['anna', 'boris']);
});

test('mainRejectsAnonymousCall', async () => {
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', []);

    const response = await handle(fakeContext({ body: JSON.stringify({ coupleId: 'couple1' }) }), () => fake.services());

    assert.deepEqual(response, { data: { error: 'unauthorized' }, statusCode: 401 });
    assert.equal(fake.teamsById.has('couple1'), true);
});

test('sharedCodeIsUpToDate', () => {
    assertSharedCopiesMatch(fileURLToPath(new URL('..', import.meta.url)));
});
