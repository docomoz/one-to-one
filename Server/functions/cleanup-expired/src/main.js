// Точка входа функции Appwrite `cleanup-expired`. Её вызывает расписание (cron в appwrite.config.json),
// пользователя у вызова нет. Из приложения её вызвать нельзя: в `execute` никого.
import { cleanupExpired } from './cleanup-expired.js';
import { appwriteServices, serverError } from './shared/http.js';

export async function handle(context, makeServices = appwriteServices) {
    try {
        const { status, body } = await cleanupExpired(makeServices(context.req));
        context.log(`Удалено просроченных: приглашений ${body.invites}, запросов ключа ${body.keyRequests}`);
        return context.res.json(body, status);
    } catch (thrown) {
        return serverError(context, thrown);
    }
}

export default (context) => handle(context);
