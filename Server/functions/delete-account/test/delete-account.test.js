import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { FakeAppwrite, fakeContext } from '../../test-support/fake-appwrite.js';
import { assertSharedCopiesMatch } from '../../test-support/shared-copies.js';
import { deleteAccount } from '../src/delete-account.js';
import { handle } from '../src/main.js';

test('deleteAccountLeavesCouplesThenDeletesUser', async () => {
    const fake = new FakeAppwrite();
    fake.addTeam('pair', ['anna', 'boris']);
    fake.addTeam('solo', ['anna']);
    fake.addRow('records', { coupleId: 'pair', envelope: 'AQ==' });
    fake.addRow('records', { coupleId: 'solo', envelope: 'AQ==' });

    const result = await deleteAccount({ callerId: 'anna', body: {} }, fake.services());

    assert.deepEqual(result, { status: 200, body: { deleted: true } });
    assert.equal(fake.userIds.has('anna'), false);
    // В паре остался Борис: пара и её записи остаются у него.
    assert.deepEqual(fake.memberIds('pair'), ['boris']);
    assert.deepEqual(fake.rows('records').map((row) => row.coupleId), ['pair']);
    // Своя пара без партнёра удалена целиком.
    assert.equal(fake.teamsById.has('solo'), false);
    // Пользователь удаляется последним, после выхода из всех пар.
    const names = fake.calls.map(([name]) => name);
    assert.equal(names.at(-1), 'users.delete');
    assert.equal(names.filter((name) => name === 'teams.deleteMembership').length, 2);
});

test('deleteAccountWithoutCouplesDeletesUser', async () => {
    const fake = new FakeAppwrite();
    fake.addUser('anna');

    const result = await deleteAccount({ callerId: 'anna', body: {} }, fake.services());

    assert.deepEqual(result, { status: 200, body: { deleted: true } });
    assert.equal(fake.userIds.has('anna'), false);
});

test('deleteAccountLeavesManyCouples', async () => {
    // Больше одной страницы членств (по 100): ни одна пара не должна остаться.
    const fake = new FakeAppwrite();
    for (let index = 0; index < 120; index++) fake.addTeam(`solo${index}`, ['anna']);

    const result = await deleteAccount({ callerId: 'anna', body: {} }, fake.services());

    assert.equal(result.status, 200);
    assert.equal(fake.teamsById.size, 0);
});

test('mainDeletesCallerNotUserFromBody', async () => {
    const fake = new FakeAppwrite();
    fake.addUser('anna');
    fake.addUser('mallory');

    const response = await handle(
        fakeContext({ userId: 'mallory', body: JSON.stringify({ userId: 'anna' }) }),
        () => fake.services(),
    );

    assert.deepEqual(response, { data: { deleted: true }, statusCode: 200 });
    assert.equal(fake.userIds.has('anna'), true);
    assert.equal(fake.userIds.has('mallory'), false);
});

test('mainRejectsAnonymousCall', async () => {
    const fake = new FakeAppwrite();
    fake.addUser('anna');

    const response = await handle(fakeContext({ body: '' }), () => fake.services());

    assert.deepEqual(response, { data: { error: 'unauthorized' }, statusCode: 401 });
    assert.equal(fake.calls.length, 0);
});

test('mainAcceptsEmptyBody', async () => {
    const fake = new FakeAppwrite();
    fake.addUser('anna');

    const response = await handle(fakeContext({ userId: 'anna', body: '' }), () => fake.services());

    assert.deepEqual(response, { data: { deleted: true }, statusCode: 200 });
});

test('sharedCodeIsUpToDate', () => {
    assertSharedCopiesMatch(fileURLToPath(new URL('..', import.meta.url)));
});
