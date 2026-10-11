import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { FakeAppwrite, fakeContext } from '../../test-support/fake-appwrite.js';
import { assertSharedCopiesMatch } from '../../test-support/shared-copies.js';
import { createInvite } from '../src/create-invite.js';
import { handle } from '../src/main.js';

const sha256 = (text) => createHash('sha256').update(text).digest('hex');

function soloCouple() {
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', ['anna']);
    return fake;
}

test('createInviteStoresOnlyHash', async () => {
    const fake = soloCouple();

    const result = await createInvite({ callerId: 'anna', body: { coupleId: 'couple1' } }, fake.services());

    assert.equal(result.status, 200);
    const [invite] = fake.rows('invites');
    assert.equal(invite.codeHash, sha256(result.body.code));
    assert.equal(invite.coupleId, 'couple1');
    assert.ok(!JSON.stringify(fake.rows('invites')).includes(result.body.code), 'кода в базе быть не должно');
    assert.deepEqual(invite.$permissions, [], 'приглашения видят только функции');
});

test('createInviteRejectsFullCouple', async () => {
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', ['anna', 'boris']);

    const result = await createInvite({ callerId: 'anna', body: { coupleId: 'couple1' } }, fake.services());

    assert.deepEqual(result, { status: 409, body: { error: 'couple_full' } });
    assert.equal(fake.rows('invites').length, 0);
});

test('createInviteRejectsUserPairedElsewhere', async () => {
    // Анна уже вошла в пару с Борисом, но из своей старой пары без партнёра выйти не успела.
    const fake = soloCouple();
    fake.addTeam('pair', ['boris']);
    fake.join('pair', 'anna');

    const result = await createInvite({ callerId: 'anna', body: { coupleId: 'couple1' } }, fake.services());

    assert.deepEqual(result, { status: 409, body: { error: 'already_paired' } });
    assert.equal(fake.rows('invites').length, 0);
});

test('createInviteIgnoresPendingInvitation', async () => {
    const fake = soloCouple();
    fake.join('couple1', 'eve', { confirm: false });

    const result = await createInvite({ callerId: 'anna', body: { coupleId: 'couple1' } }, fake.services());

    assert.equal(result.status, 200);
});

test('createInviteGivesCodeFromAlphabetValidForSevenDays', async () => {
    const fake = soloCouple();

    const result = await createInvite({ callerId: 'anna', body: { coupleId: 'couple1' } }, fake.services());

    assert.match(result.body.code, /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{8}$/);
    assert.equal(result.body.expiresAt, '2026-10-18T12:00:00.000Z');
    assert.equal(fake.rows('invites')[0].expiresAt, '2026-10-18T12:00:00.000Z');
});

test('createInviteMapsRandomIndexesToAlphabet', async () => {
    // Код собирается из случайных индексов алфавита: проверяем, что индекс превращается в букву без сдвига.
    const fake = soloCouple();
    let index = 0;
    const randomInt = (max) => {
        assert.equal(max, 31);
        return index++ % max;
    };

    const result = await createInvite(
        { callerId: 'anna', body: { coupleId: 'couple1' } },
        fake.services({ randomInt }),
    );

    assert.equal(result.body.code, '23456789');
});

test('createInviteDeletesPreviousInvitesOfCouple', async () => {
    const fake = soloCouple();
    fake.addRow('invites', { codeHash: 'old', coupleId: 'couple1', expiresAt: '2026-10-12T00:00:00.000Z' });
    fake.addRow('invites', { codeHash: 'other', coupleId: 'couple2', expiresAt: '2026-10-12T00:00:00.000Z' });

    const result = await createInvite({ callerId: 'anna', body: { coupleId: 'couple1' } }, fake.services());

    assert.deepEqual(
        fake.rows('invites').map((row) => row.codeHash).sort(),
        [sha256(result.body.code), 'other'].sort(),
    );
});

test('createInviteDeletesExpiredInvites', async () => {
    // Попутная уборка: просроченные приглашения других пар больше никому не нужны.
    const fake = soloCouple();
    fake.addRow('invites', { codeHash: 'expired', coupleId: 'couple2', expiresAt: '2026-10-11T11:00:00.000Z' });
    fake.addRow('invites', { codeHash: 'alive', coupleId: 'couple3', expiresAt: '2026-10-11T13:00:00.000Z' });

    const result = await createInvite({ callerId: 'anna', body: { coupleId: 'couple1' } }, fake.services());

    assert.deepEqual(
        fake.rows('invites').map((row) => row.codeHash).sort(),
        ['alive', sha256(result.body.code)].sort(),
    );
});

test('createInviteRetriesWhenCodeHashIsTaken', async () => {
    const fake = soloCouple();
    fake.addRow('invites', { codeHash: sha256('22222222'), coupleId: 'couple2', expiresAt: '2026-10-12T00:00:00.000Z' });
    let call = 0;
    // Первый код совпадает с чужим приглашением, второй — новый.
    const randomInt = () => (call++ < 8 ? 0 : 1);

    const result = await createInvite(
        { callerId: 'anna', body: { coupleId: 'couple1' } },
        fake.services({ randomInt }),
    );

    assert.equal(result.status, 200);
    assert.equal(result.body.code, '33333333');
});

test('createInviteRejectsStranger', async () => {
    const fake = soloCouple();
    fake.addUser('mallory');

    const result = await createInvite({ callerId: 'mallory', body: { coupleId: 'couple1' } }, fake.services());

    assert.deepEqual(result, { status: 403, body: { error: 'not_member' } });
    assert.equal(fake.rows('invites').length, 0);
});

test('createInviteRejectsUnknownCouple', async () => {
    const fake = soloCouple();

    const result = await createInvite({ callerId: 'anna', body: { coupleId: 'nope' } }, fake.services());

    assert.deepEqual(result, { status: 403, body: { error: 'not_member' } });
});

test('createInviteRejectsUnconfirmedMember', async () => {
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', ['anna'], { confirm: false });

    const result = await createInvite({ callerId: 'anna', body: { coupleId: 'couple1' } }, fake.services());

    assert.deepEqual(result, { status: 403, body: { error: 'not_member' } });
});

test('createInviteRejectsMissingCoupleId', async () => {
    const fake = soloCouple();

    for (const body of [{}, { coupleId: 42 }, { coupleId: '' }, { coupleId: '../x' }]) {
        const result = await createInvite({ callerId: 'anna', body }, fake.services());
        assert.deepEqual(result, { status: 400, body: { error: 'bad_request' } }, JSON.stringify(body));
    }
});

test('mainTakesCallerFromHeaderNotFromBody', async () => {
    const fake = soloCouple();
    fake.addUser('mallory');
    const context = fakeContext({ userId: 'mallory', body: JSON.stringify({ coupleId: 'couple1', userId: 'anna' }) });

    const response = await handle(context, () => fake.services());

    assert.deepEqual(response, { data: { error: 'not_member' }, statusCode: 403 });
});

test('mainRejectsAnonymousCall', async () => {
    const fake = soloCouple();
    const context = fakeContext({ body: JSON.stringify({ coupleId: 'couple1' }) });

    const response = await handle(context, () => fake.services());

    assert.deepEqual(response, { data: { error: 'unauthorized' }, statusCode: 401 });
    assert.equal(fake.calls.length, 0);
});

test('mainRejectsBrokenJson', async () => {
    const fake = soloCouple();

    const response = await handle(fakeContext({ userId: 'anna', body: '{' }), () => fake.services());

    assert.deepEqual(response, { data: { error: 'bad_request' }, statusCode: 400 });
});

test('mainReturnsInviteToMember', async () => {
    const fake = soloCouple();

    const response = await handle(
        fakeContext({ userId: 'anna', body: JSON.stringify({ coupleId: 'couple1' }) }),
        () => fake.services(),
    );

    assert.equal(response.statusCode, 200);
    assert.match(response.data.code, /^[23456789A-Z]{8}$/);
});

test('mainHidesServerErrors', async () => {
    const fake = soloCouple();
    fake.teams.listMemberships = async () => {
        throw new Error('сеть упала');
    };
    const context = fakeContext({ userId: 'anna', body: JSON.stringify({ coupleId: 'couple1' }) });

    const response = await handle(context, () => fake.services());

    assert.deepEqual(response, { data: { error: 'server_error' }, statusCode: 500 });
    assert.equal(context.logs[0][0], 'error');
});

test('sharedCodeIsUpToDate', () => {
    assertSharedCopiesMatch(fileURLToPath(new URL('..', import.meta.url)));
});
