// Уборка просроченного: приглашения и запросы ключа после `expiresAt` больше не нужны.
// Источник правды — Server/functions/shared/, в функциях лежат копии (Server/functions/sync-shared.sh).
import { Query } from 'node-appwrite';

import { DATABASE_ID } from './couple.js';

export const EXPIRING_TABLES = ['invites', 'keyRequests'];

// Удаляет строки таблицы, у которых `expiresAt` не позже `now`. Возвращает, сколько удалено.
export async function deleteExpired(tablesDB, tableId, now) {
    const result = await tablesDB.deleteRows({
        databaseId: DATABASE_ID,
        tableId,
        queries: [Query.lessThanEqual('expiresAt', now.toISOString())],
    });
    return result?.total ?? result?.rows?.length ?? 0;
}
