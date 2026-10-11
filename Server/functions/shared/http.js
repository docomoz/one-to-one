// Общая обвязка функций: кто вызывает, разбор тела, ответ и подключение к Appwrite.
// Источник правды — Server/functions/shared/, в функциях лежат копии (Server/functions/sync-shared.sh).
import { Client, TablesDB, Teams, Users } from 'node-appwrite';

export const ok = (body) => ({ status: 200, body });
export const fail = (status, error) => ({ status, body: { error } });

// Настоящий SDK. Ключ на время вызова Appwrite кладёт в заголовок `x-appwrite-key`,
// его права — `scopes` функции из appwrite.config.json.
export function appwriteServices(req) {
    const client = new Client()
        .setEndpoint(process.env.APPWRITE_FUNCTION_API_ENDPOINT)
        .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
        .setKey(req.headers['x-appwrite-key'] ?? '');
    return {
        tablesDB: new TablesDB(client),
        teams: new Teams(client),
        users: new Users(client),
        now: () => new Date(),
    };
}

// Рантайм open-runtimes v5 отдаёт тело строкой в `bodyText`; `bodyRaw` и `body` — на случай старого рантайма.
function readJson(req) {
    const text = [req.bodyText, req.bodyRaw, req.body].find((value) => typeof value === 'string') ?? '';
    if (text.trim() === '') return {};
    const body = JSON.parse(text);
    if (body === null || typeof body !== 'object' || Array.isArray(body)) throw new Error('Тело не объект');
    return body;
}

// Запускает действие функции. Вызывающего берём только из `x-appwrite-user-id`: этот заголовок
// ставит сам Appwrite по сессии, подделать его из приложения нельзя. `userId` из тела не читаем никогда.
export async function run({ req, res, error }, action, makeServices = appwriteServices) {
    const callerId = req.headers['x-appwrite-user-id'];
    if (!callerId) return res.json({ error: 'unauthorized' }, 401);

    let body;
    try {
        body = readJson(req);
    } catch {
        return res.json({ error: 'bad_request' }, 400);
    }

    try {
        const result = await action({ callerId, body }, makeServices(req));
        return res.json(result.body, result.status);
    } catch (thrown) {
        return serverError({ res, error }, thrown);
    }
}

// Неожиданная ошибка: в лог только тип и текст ошибки Appwrite (ни тела запроса, ни кодов приглашений),
// в ответ — `server_error`.
export function serverError({ res, error }, thrown) {
    error(`${thrown?.name ?? 'Error'} ${thrown?.code ?? ''} ${thrown?.type ?? ''}: ${thrown?.message ?? thrown}`);
    return res.json({ error: 'server_error' }, 500);
}
