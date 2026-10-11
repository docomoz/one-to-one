import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { FakeAppwrite, fakeContext } from '../../test-support/fake-appwrite.js';
import { assertSharedCopiesMatch } from '../../test-support/shared-copies.js';
import { cleanupExpired } from '../src/cleanup-expired.js';
import { handle } from '../src/main.js';

// Сейчас 2026-10-11 12:00 (FakeAppwrite.now): по одной просроченной и одной живой строке в каждой таблице.
function withRows() {
    const fake = new FakeAppwrite();
    fake.addRow('invites', { $id: 'oldInvite', coupleId: 'c1', codeHash: 'a', expiresAt: '2026-10-11T11:59:59.000Z' });
    fake.addRow('invites', { $id: 'newInvite', coupleId: 'c2', codeHash: 'b', expiresAt: '2026-10-18T12:00:00.000Z' });
    fake.addRow('keyRequests', { $id: 'oldRequest', coupleId: 'c1', status: 'delivered', expiresAt: '2026-10-10T00:00:00.000Z' });
    fake.addRow('keyRequests', { $id: 'newRequest', coupleId: 'c1', status: 'waiting', expiresAt: '2026-10-11T12:10:00.000Z' });
    fake.addRow('records', { $id: 'record', coupleId: 'c1', envelope: 'AQ==' });
    return fake;
}

const ids = (fake, tableId) => fake.rows(tableId).map((row) => row.$id);

test('cleanupDeletesOnlyExpired', async () => {
    const fake = withRows();

    const result = await cleanupExpired(fake.services());

    assert.deepEqual(result, { status: 200, body: { invites: 1, keyRequests: 1 } });
    assert.deepEqual(ids(fake, 'invites'), ['newInvite']);
    assert.deepEqual(ids(fake, 'keyRequests'), ['newRequest']);
    assert.deepEqual(ids(fake, 'records'), ['record'], 'записи пары уборка не трогает');
});

test('mainRunsWithoutCaller', async () => {
    // Расписание вызывает функцию без пользователя: `x-appwrite-user-id` пустой.
    const fake = withRows();
    const context = fakeContext({ body: '' });

    const response = await handle(context, () => fake.services());

    assert.deepEqual(response, { data: { invites: 1, keyRequests: 1 }, statusCode: 200 });
    assert.deepEqual(context.logs, [['log', 'Удалено просроченных: приглашений 1, запросов ключа 1']]);
});

test('mainHidesServerErrors', async () => {
    const fake = withRows();
    fake.tablesDB.deleteRows = async () => {
        throw new Error('база недоступна');
    };
    const context = fakeContext({ body: '' });

    const response = await handle(context, () => fake.services());

    assert.deepEqual(response, { data: { error: 'server_error' }, statusCode: 500 });
    assert.equal(context.logs[0][0], 'error');
});

test('sharedCodeIsUpToDate', () => {
    assertSharedCopiesMatch(fileURLToPath(new URL('..', import.meta.url)));
});
