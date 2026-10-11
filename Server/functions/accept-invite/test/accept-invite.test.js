import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { FakeAppwrite, fakeContext } from '../../test-support/fake-appwrite.js';
import { assertSharedCopiesMatch } from '../../test-support/shared-copies.js';
import { acceptInvite } from '../src/accept-invite.js';
import { handle } from '../src/main.js';

const CODE = 'ABCD2345';
const sha256 = (text) => createHash('sha256').update(text).digest('hex');

// Анна создала пару и приглашение, Борис пока ни в какой паре.
function invitedCouple({ expiresAt = '2026-10-18T12:00:00.000Z' } = {}) {
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', ['anna']);
    fake.addUser('boris');
    fake.addRow('invites', { $id: 'invite1', codeHash: sha256(CODE), coupleId: 'couple1', expiresAt });
    return fake;
}

const accept = (fake, callerId, code = CODE) => acceptInvite({ callerId, body: { code } }, fake.services());

test('acceptInviteJoinsTeamAndDeletesInvite', async () => {
    const fake = invitedCouple();

    const result = await accept(fake, 'boris');

    assert.deepEqual(result, { status: 200, body: { coupleId: 'couple1' } });
    assert.deepEqual(fake.memberIds('couple1'), ['anna', 'boris']);
    assert.equal(fake.teamsById.get('couple1')[1].confirm, true);
    // Не владелец: владелец команды мог бы сам добавить третьего мимо приглашения.
    assert.deepEqual(fake.teamsById.get('couple1')[1].roles, ['partner']);
    assert.equal(fake.rows('invites').length, 0);
});

test('acceptInviteRejectsExpired', async () => {
    const fake = invitedCouple({ expiresAt: '2026-10-11T11:59:59.000Z' });

    const result = await accept(fake, 'boris');

    assert.deepEqual(result, { status: 410, body: { error: 'invite_expired' } });
    assert.deepEqual(fake.memberIds('couple1'), ['anna']);
    assert.equal(fake.rows('invites').length, 0, 'просроченное приглашение удаляется');
});

test('acceptInviteRejectsSecondPartner', async () => {
    const fake = invitedCouple();
    fake.join('couple1', 'boris');
    fake.addUser('victor');

    const result = await accept(fake, 'victor');

    assert.deepEqual(result, { status: 409, body: { error: 'couple_full' } });
    assert.deepEqual(fake.memberIds('couple1'), ['anna', 'boris']);
});

test('acceptInviteRejectsUserAlreadyPaired', async () => {
    const fake = invitedCouple();
    fake.addTeam('couple2', ['boris', 'vera']);

    const result = await accept(fake, 'boris');

    assert.deepEqual(result, { status: 409, body: { error: 'already_paired' } });
    assert.deepEqual(fake.memberIds('couple1'), ['anna']);
    assert.equal(fake.rows('invites').length, 1, 'приглашение остаётся для настоящего партнёра');
});

test('acceptInviteAllowsUserAloneInOwnCouple', async () => {
    // Кто пользовался приложением один, сидит в своей «паре» без партнёра. Её он покидает сам после входа.
    const fake = invitedCouple();
    fake.addTeam('solo', ['boris']);

    const result = await accept(fake, 'boris');

    assert.deepEqual(result, { status: 200, body: { coupleId: 'couple1' } });
    assert.deepEqual(fake.memberIds('solo'), ['boris'], 'свою пару функция не трогает');
});

test('acceptInviteRejectsOwnInvite', async () => {
    const fake = invitedCouple();

    const result = await accept(fake, 'anna');

    assert.deepEqual(result, { status: 409, body: { error: 'already_paired' } });
    assert.deepEqual(fake.memberIds('couple1'), ['anna']);
});

test('acceptInviteRejectsUnknownCode', async () => {
    const fake = invitedCouple();

    for (const code of ['ZZZZ2345', 'ABCD234', 'ABCD23451', 'ABCD234I', null, 42]) {
        const result = await accept(fake, 'boris', code);
        assert.deepEqual(result, { status: 404, body: { error: 'invite_not_found' } }, String(code));
    }
    assert.deepEqual(fake.memberIds('couple1'), ['anna']);
});

test('acceptInviteRejectsUsedCode', async () => {
    const fake = invitedCouple();
    fake.addUser('victor');
    await accept(fake, 'boris');

    const result = await accept(fake, 'victor');

    assert.deepEqual(result, { status: 404, body: { error: 'invite_not_found' } });
});

test('acceptInviteForgivesCaseSpacesAndDashes', async () => {
    const fake = invitedCouple();

    const result = await accept(fake, 'boris', ' abcd-2345 ');

    assert.deepEqual(result, { status: 200, body: { coupleId: 'couple1' } });
});

test('acceptInviteForgetsInviteOfDeletedCouple', async () => {
    const fake = invitedCouple();
    fake.teamsById.delete('couple1');

    const result = await accept(fake, 'boris');

    assert.deepEqual(result, { status: 404, body: { error: 'invite_not_found' } });
    assert.equal(fake.rows('invites').length, 0);
});

test('acceptInviteUndoesJoinWhenSomeoneElseJoinedFirst', async () => {
    // Двое ввели код одновременно: если после входа в команде больше двух, вошедший последним выходит.
    const fake = invitedCouple();
    const createMembership = fake.teams.createMembership;
    fake.teams.createMembership = async (params) => {
        fake.join('couple1', 'victor');
        return createMembership(params);
    };

    const result = await accept(fake, 'boris');

    assert.deepEqual(result, { status: 409, body: { error: 'couple_full' } });
    assert.deepEqual(fake.memberIds('couple1'), ['anna', 'victor']);
});

test('acceptInviteKeepsEarlierJoinerWhenSomeoneJoinsLater', async () => {
    // Обратная гонка: Борис вошёл, а следом вошёл Виктор. Борис раньше, поэтому остаётся он.
    const fake = invitedCouple();
    const createMembership = fake.teams.createMembership;
    fake.teams.createMembership = async (params) => {
        const joined = await createMembership(params);
        fake.join('couple1', 'victor');
        return joined;
    };

    const result = await accept(fake, 'boris');

    assert.deepEqual(result, { status: 200, body: { coupleId: 'couple1' } });
    assert.ok(fake.memberIds('couple1').includes('boris'));
});

test('acceptInviteRestoresInviteWhenJoinFails', async () => {
    const fake = invitedCouple();
    fake.teams.createMembership = async () => {
        throw new Error('сеть упала');
    };

    await assert.rejects(accept(fake, 'boris'), /сеть упала/);

    assert.deepEqual(
        fake.rows('invites').map((row) => row.$id),
        ['invite1'],
        'код должен остаться рабочим для повторной попытки',
    );
});

test('acceptInviteIgnoresPendingInvitation', async () => {
    // Неподтверждённое приглашение по почте — не партнёр: место в паре свободно.
    const fake = invitedCouple();
    fake.join('couple1', 'eve', { confirm: false });

    const result = await accept(fake, 'boris');

    assert.deepEqual(result, { status: 200, body: { coupleId: 'couple1' } });
});

test('mainTakesCallerFromHeaderNotFromBody', async () => {
    const fake = invitedCouple();
    const context = fakeContext({ userId: 'boris', body: JSON.stringify({ code: CODE, userId: 'mallory' }) });

    const response = await handle(context, () => fake.services());

    assert.deepEqual(response, { data: { coupleId: 'couple1' }, statusCode: 200 });
    assert.deepEqual(fake.memberIds('couple1'), ['anna', 'boris']);
});

test('mainRejectsAnonymousCall', async () => {
    const fake = invitedCouple();

    const response = await handle(fakeContext({ body: JSON.stringify({ code: CODE }) }), () => fake.services());

    assert.deepEqual(response, { data: { error: 'unauthorized' }, statusCode: 401 });
    assert.equal(fake.rows('invites').length, 1);
});

test('sharedCodeIsUpToDate', () => {
    assertSharedCopiesMatch(fileURLToPath(new URL('..', import.meta.url)));
});
