# Server

Всё, что относится к нашему серверу Appwrite. Как он устроен, как его поднять заново, обновить и как выложить схему и функции: [docs/server.md](../docs/server.md).

- `appwrite.config.json` — база `main` с таблицами `records`, `keyRequests`, `invites` и функции. Выкладывается командой `appwrite push all` из этой папки.
- `functions/<имя>/` — функции на Node.js 22: `create-couple`, `create-invite`, `accept-invite`, `leave-couple`, `delete-account`, `cleanup-expired`. Код в `src/`, тесты в `test/` (`npm ci && npm test`).
- `functions/shared/` — общий код функций. После правки выполнить `functions/sync-shared.sh`: он копирует его в `src/shared/` каждой функции.
- `functions/test-support/` — фейковый Appwrite для тестов, на сервер не выкладывается.
