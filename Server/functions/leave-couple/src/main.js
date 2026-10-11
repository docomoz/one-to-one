// Точка входа функции Appwrite `leave-couple`.
import { leaveCouple } from './leave-couple.js';
import { appwriteServices, run } from './shared/http.js';

export const handle = (context, makeServices = appwriteServices) => run(context, leaveCouple, makeServices);

export default (context) => handle(context);
