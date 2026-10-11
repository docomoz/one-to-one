// Раз в сутки по расписанию: удаляет просроченные приглашения и запросы ключа, чтобы они не копились.
// Ответ: сколько строк удалено в каждой таблице.
import { deleteExpired, EXPIRING_TABLES } from './shared/expired.js';
import { ok } from './shared/http.js';

export async function cleanupExpired(services) {
    const now = services.now();
    const deleted = {};
    for (const tableId of EXPIRING_TABLES) {
        deleted[tableId] = await deleteExpired(services.tablesDB, tableId, now);
    }
    return ok(deleted);
}
