// Фейковый Appwrite для тестов функций: команды, пользователи и таблицы в памяти.
// Повторяет только то, чем пользуются функции, и записывает каждый вызов в `calls`,
// чтобы тесты могли проверить порядок действий.
// Сюда не импортируем node-appwrite: у этой папки нет своих зависимостей.

export class FakeAppwriteError extends Error {
    constructor(message, code, type) {
        super(message);
        this.name = 'AppwriteException';
        this.code = code;
        this.type = type;
    }
}

function parseQueries(queries = []) {
    return queries.map((query) => JSON.parse(query));
}

// Сравнение «меньше или равно» для дат в ISO-формате.
const notAfter = (value, limit) => Date.parse(value) <= Date.parse(limit);

// Фильтры `equal`, `lessThanEqual` (даты), `limit` и `cursorAfter` — больше функциям не нужно.
function matches(item, query) {
    if (query.method === 'equal') return query.values.includes(item[query.attribute]);
    if (query.method === 'lessThanEqual') return notAfter(item[query.attribute], query.values[0]);
    throw new Error(`Фейк не умеет фильтр ${query.method}`);
}

const isFilter = (query) => query.method === 'equal' || query.method === 'lessThanEqual';

function applyQueries(items, queries) {
    let result = items;
    let limit = 25;
    for (const query of parseQueries(queries)) {
        if (isFilter(query)) {
            result = result.filter((item) => matches(item, query));
        } else if (query.method === 'limit') {
            limit = query.values[0];
        } else if (query.method === 'cursorAfter') {
            const index = result.findIndex((item) => item.$id === query.values[0]);
            result = result.slice(index + 1);
        } else {
            throw new Error(`Фейк не умеет запрос ${query.method}`);
        }
    }
    return result.slice(0, limit);
}

export class FakeAppwrite {
    constructor() {
        this.calls = [];
        this.teamsById = new Map(); // teamId → массив членств
        this.userIds = new Set();
        this.tables = { records: new Map(), keyRequests: new Map(), invites: new Map() };
        this.nextId = 1;

        this.teams = {
            listMemberships: async ({ teamId, queries }) => {
                this.calls.push(['teams.listMemberships', teamId]);
                const memberships = this.#team(teamId);
                return { total: memberships.length, memberships: applyQueries(memberships, queries) };
            },
            createMembership: async ({ teamId, roles, userId }) => {
                this.calls.push(['teams.createMembership', teamId, userId]);
                const membership = this.membership(teamId, userId, { roles });
                this.#team(teamId).push(membership);
                return membership;
            },
            deleteMembership: async ({ teamId, membershipId }) => {
                this.calls.push(['teams.deleteMembership', teamId, membershipId]);
                const memberships = this.#team(teamId);
                const index = memberships.findIndex((m) => m.$id === membershipId);
                if (index === -1) throw new FakeAppwriteError('Membership not found', 404, 'membership_not_found');
                memberships.splice(index, 1);
                return {};
            },
            delete: async ({ teamId }) => {
                this.calls.push(['teams.delete', teamId]);
                this.#team(teamId);
                this.teamsById.delete(teamId);
                return {};
            },
        };

        this.users = {
            listMemberships: async ({ userId, queries }) => {
                this.calls.push(['users.listMemberships', userId]);
                const memberships = [...this.teamsById.values()].flat().filter((m) => m.userId === userId);
                return { total: memberships.length, memberships: applyQueries(memberships, queries) };
            },
            delete: async ({ userId }) => {
                this.calls.push(['users.delete', userId]);
                if (!this.userIds.delete(userId)) throw new FakeAppwriteError('User not found', 404, 'user_not_found');
                // Как настоящий Appwrite: вместе с пользователем пропадают его членства.
                for (const [teamId, memberships] of this.teamsById) {
                    this.teamsById.set(teamId, memberships.filter((m) => m.userId !== userId));
                }
                return {};
            },
        };

        this.tablesDB = {
            listRows: async ({ databaseId, tableId, queries }) => {
                this.calls.push(['tablesDB.listRows', tableId]);
                const rows = [...this.#table(databaseId, tableId).values()];
                return { total: rows.length, rows: applyQueries(rows, queries) };
            },
            createRow: async ({ databaseId, tableId, rowId, data, permissions }) => {
                this.calls.push(['tablesDB.createRow', tableId]);
                const table = this.#table(databaseId, tableId);
                const id = rowId === 'unique()' ? this.#id('row') : rowId;
                if (table.has(id)) throw new FakeAppwriteError('Row already exists', 409, 'row_already_exists');
                if (tableId === 'invites' && [...table.values()].some((row) => row.codeHash === data.codeHash)) {
                    throw new FakeAppwriteError('Row already exists', 409, 'row_already_exists');
                }
                const row = { $id: id, $permissions: permissions ?? [], ...data };
                table.set(id, row);
                return row;
            },
            deleteRow: async ({ databaseId, tableId, rowId }) => {
                this.calls.push(['tablesDB.deleteRow', tableId, rowId]);
                if (!this.#table(databaseId, tableId).delete(rowId)) {
                    throw new FakeAppwriteError('Row not found', 404, 'row_not_found');
                }
                return {};
            },
            deleteRows: async ({ databaseId, tableId, queries }) => {
                this.calls.push(['tablesDB.deleteRows', tableId]);
                const table = this.#table(databaseId, tableId);
                const filters = parseQueries(queries).filter(isFilter);
                if (filters.length === 0) throw new Error('Фейк: удаление всех строк без фильтра запрещено');
                const doomed = [...table.values()].filter((row) => filters.every((query) => matches(row, query)));
                for (const row of doomed) table.delete(row.$id);
                return { total: doomed.length, rows: doomed };
            },
        };
    }

    // То, что функции получают вместо настоящего SDK. Время по умолчанию — `FakeAppwrite.now`.
    services(overrides = {}) {
        return {
            tablesDB: this.tablesDB,
            teams: this.teams,
            users: this.users,
            now: () => new Date(FakeAppwrite.now),
            ...overrides,
        };
    }

    static now = '2026-10-11T12:00:00.000Z';

    // Подготовка данных для тестов.

    addUser(userId) {
        this.userIds.add(userId);
    }

    addTeam(teamId, userIds, { confirm = true } = {}) {
        for (const userId of userIds) this.addUser(userId);
        this.teamsById.set(
            teamId,
            userIds.map((userId) => this.membership(teamId, userId, { confirm })),
        );
    }

    // Новое членство (в команду не добавляет). Время создания растёт с каждым вызовом, как у настоящих.
    membership(teamId, userId, { confirm = true, roles = ['owner'] } = {}) {
        const $createdAt = new Date(Date.parse(FakeAppwrite.now) + this.nextId * 1000).toISOString();
        return { $id: this.#id('m'), $createdAt, teamId, userId, roles, confirm };
    }

    // Добавляет человека в существующую команду.
    join(teamId, userId, options) {
        this.addUser(userId);
        const membership = this.membership(teamId, userId, options);
        this.#team(teamId).push(membership);
        return membership;
    }

    addRow(tableId, row) {
        const id = row.$id ?? this.#id('row');
        this.tables[tableId].set(id, { $id: id, ...row });
        return id;
    }

    rows(tableId) {
        return [...this.tables[tableId].values()];
    }

    memberIds(teamId) {
        return (this.teamsById.get(teamId) ?? []).map((m) => m.userId);
    }

    #team(teamId) {
        const memberships = this.teamsById.get(teamId);
        if (!memberships) throw new FakeAppwriteError('Team not found', 404, 'team_not_found');
        return memberships;
    }

    #table(databaseId, tableId) {
        if (databaseId !== 'main') throw new FakeAppwriteError('Database not found', 404, 'database_not_found');
        const table = this.tables[tableId];
        if (!table) throw new FakeAppwriteError('Table not found', 404, 'table_not_found');
        return table;
    }

    #id(prefix) {
        return `${prefix}${this.nextId++}`;
    }
}

// Минимальный контекст open-runtimes (`req`, `res`, `log`, `error`) для тестов `main.js`.
export function fakeContext({ userId = '', body = '', headers = {} } = {}) {
    const logs = [];
    const context = {
        req: {
            headers: { 'x-appwrite-user-id': userId, 'x-appwrite-key': 'test-key', ...headers },
            bodyText: body,
        },
        res: {
            json: (data, statusCode = 200) => ({ data, statusCode }),
        },
        log: (message) => logs.push(['log', message]),
        error: (message) => logs.push(['error', message]),
        logs,
    };
    return context;
}
