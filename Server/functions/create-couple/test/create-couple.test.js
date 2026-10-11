import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { FakeAppwrite, fakeContext } from '../../test-support/fake-appwrite.js';
import { assertSharedCopiesMatch } from '../../test-support/shared-copies.js';
import { createCouple } from '../src/create-couple.js';
import { handle } from '../src/main.js';

const create = (fake, callerId, body = { coupleId: 'couple1' }) => createCouple({ callerId, body }, fake.services());

function withAnna() {
    const fake = new FakeAppwrite();
    fake.addUser('anna');
    return fake;
}

test('createCoupleAddsCallerAsConfirmedPartnerNotOwner', async () => {
    const fake = withAnna();

    const result = await create(fake, 'anna');

    assert.deepEqual(result, { status: 200, body: { coupleId: 'couple1' } });
    const [membership] = fake.teamsById.get('couple1');
    assert.equal(membership.userId, 'anna');
    assert.equal(membership.confirm, true);
    // Владелец команды мог бы сам добавить третьего мимо accept-invite. Владельцев в паре нет ни у кого.
    assert.deepEqual(membership.roles, ['partner']);
});

test('createCoupleGeneratesIdWhenNotGiven', async () => {
    const fake = withAnna();

    const result = await create(fake, 'anna', {});

    assert.equal(result.status, 200);
    assert.deepEqual(fake.memberIds(result.body.coupleId), ['anna']);
});

test('createCoupleRejectsUserAlreadyPaired', async () => {
    const fake = new FakeAppwrite();
    fake.addTeam('old', ['anna', 'boris']);

    const result = await create(fake, 'anna');

    assert.deepEqual(result, { status: 409, body: { error: 'already_paired' } });
    assert.equal(fake.teamsById.has('couple1'), false);
});

test('createCoupleAllowsUserAloneInOldCouple', async () => {
    // Своя пара без партнёра не в счёт: из неё приложение выходит само.
    const fake = new FakeAppwrite();
    fake.addTeam('solo', ['anna']);

    const result = await create(fake, 'anna');

    assert.deepEqual(result, { status: 200, body: { coupleId: 'couple1' } });
});

test('createCoupleRetryReturnsSameCouple', async () => {
    // Ответ на первый вызов потерялся, приложение повторяет с тем же id: вторая пара не появляется.
    const fake = withAnna();
    await create(fake, 'anna');

    const result = await create(fake, 'anna');

    assert.deepEqual(result, { status: 200, body: { coupleId: 'couple1' } });
    assert.deepEqual(fake.memberIds('couple1'), ['anna']);
    assert.equal(fake.teamsById.size, 1);
});

test('createCoupleRetryAfterPartnerJoinedStillAnswers', async () => {
    const fake = withAnna();
    await create(fake, 'anna');
    fake.join('couple1', 'boris');

    const result = await create(fake, 'anna');

    assert.deepEqual(result, { status: 200, body: { coupleId: 'couple1' } });
    assert.deepEqual(fake.memberIds('couple1'), ['anna', 'boris']);
});

test('createCoupleRefusesSomeoneElsesCouple', async () => {
    // Чужой id: войти в чужую пару так нельзя, только по приглашению.
    const fake = new FakeAppwrite();
    fake.addTeam('couple1', ['vera']);
    fake.addUser('anna');

    const result = await create(fake, 'anna');

    assert.deepEqual(result, { status: 403, body: { error: 'not_member' } });
    assert.deepEqual(fake.memberIds('couple1'), ['vera']);
});

test('createCoupleRejectsBadId', async () => {
    const fake = withAnna();

    for (const coupleId of ['', '-x', 'a'.repeat(37), 42, null]) {
        const result = await create(fake, 'anna', { coupleId });
        assert.deepEqual(result, { status: 400, body: { error: 'bad_request' } }, String(coupleId));
    }
    assert.equal(fake.teamsById.size, 0);
});

test('createCoupleDeletesTeamWhenJoinFails', async () => {
    const fake = withAnna();
    fake.teams.createMembership = async () => {
        throw new Error('сеть упала');
    };

    await assert.rejects(create(fake, 'anna'), /сеть упала/);

    assert.equal(fake.teamsById.has('couple1'), false, 'пустая команда не остаётся');
});

test('createCoupleConcurrentRetryKeepsTeam', async () => {
    // Два вызова с одним id одновременно: второй добавил Анну раньше первого. Первый не удаляет команду.
    const fake = withAnna();
    const createMembership = fake.teams.createMembership;
    fake.teams.createMembership = async (params) => {
        fake.teams.createMembership = createMembership;
        await createMembership(params); // «второй вызов» успел первым
        throw Object.assign(new Error('Membership already exists'), { code: 409 });
    };

    const result = await create(fake, 'anna');

    assert.deepEqual(result, { status: 200, body: { coupleId: 'couple1' } });
    assert.deepEqual(fake.memberIds('couple1'), ['anna']);
});

test('mainTakesCallerFromHeaderNotFromBody', async () => {
    const fake = withAnna();
    fake.addUser('mallory');
    const context = fakeContext({ userId: 'anna', body: JSON.stringify({ coupleId: 'couple1', userId: 'mallory' }) });

    const response = await handle(context, () => fake.services());

    assert.deepEqual(response, { data: { coupleId: 'couple1' }, statusCode: 200 });
    assert.deepEqual(fake.memberIds('couple1'), ['anna']);
});

test('mainRejectsAnonymousCall', async () => {
    const fake = withAnna();

    const response = await handle(fakeContext({ body: '{}' }), () => fake.services());

    assert.deepEqual(response, { data: { error: 'unauthorized' }, statusCode: 401 });
    assert.equal(fake.teamsById.size, 0);
});

test('sharedCodeIsUpToDate', () => {
    assertSharedCopiesMatch(fileURLToPath(new URL('..', import.meta.url)));
});
