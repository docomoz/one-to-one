// Выход из пары. Вход: `{coupleId}`, ответ: `{left, coupleDeleted}`.
// Если в паре никого не осталось, удаляются команда и все её записи, запросы ключа и приглашения.
import { isAppwriteId, leaveCouple as leave } from './shared/couple.js';
import { fail } from './shared/http.js';

export async function leaveCouple({ callerId, body }, services) {
    const { coupleId } = body;
    if (!isAppwriteId(coupleId)) return fail(400, 'bad_request');
    return leave(services, coupleId, callerId);
}
