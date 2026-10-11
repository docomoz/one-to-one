// Код приглашения: 8 символов без похожих (нет 0/O, 1/I/L). На сервере хранится только SHA-256 кода.
// Источник правды — Server/functions/shared/, в функциях лежат копии (Server/functions/sync-shared.sh).
import { createHash, randomInt as cryptoRandomInt } from 'node:crypto';

export const INVITE_ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
export const INVITE_CODE_LENGTH = 8;
export const INVITE_LIFETIME_MS = 7 * 24 * 60 * 60 * 1000;

// `crypto.randomInt` — криптостойкий и без перекоса в сторону первых букв.
export function generateInviteCode(randomInt = cryptoRandomInt) {
    let code = '';
    for (let index = 0; index < INVITE_CODE_LENGTH; index++) {
        code += INVITE_ALPHABET[randomInt(INVITE_ALPHABET.length)];
    }
    return code;
}

// Код, как его ввёл человек («abcd-2345 »), → канонический вид или `null`, если такого кода быть не может.
export function normalizeInviteCode(input) {
    if (typeof input !== 'string') return null;
    const code = input.toUpperCase().replace(/[\s-]/g, '');
    const valid = code.length === INVITE_CODE_LENGTH && [...code].every((char) => INVITE_ALPHABET.includes(char));
    return valid ? code : null;
}

export function hashInviteCode(code) {
    return createHash('sha256').update(code, 'utf8').digest('hex');
}
