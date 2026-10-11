// Каждая функция выкладывается на сервер отдельной папкой и не видит соседей, поэтому общий код
// (`Server/functions/shared/`) лежит копией в `src/shared/` каждой функции. Тест падает, если копия отстала.
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const sharedDir = fileURLToPath(new URL('../shared/', import.meta.url));

export function assertSharedCopiesMatch(functionDir) {
    const copyDir = join(functionDir, 'src', 'shared');
    const hint = 'Общий код поменялся: выполни Server/functions/sync-shared.sh';
    assert.deepEqual(readdirSync(copyDir).sort(), readdirSync(sharedDir).sort(), hint);
    for (const file of readdirSync(sharedDir)) {
        assert.equal(
            readFileSync(join(copyDir, file), 'utf8'),
            readFileSync(join(sharedDir, file), 'utf8'),
            `${file}: ${hint}`,
        );
    }
}
