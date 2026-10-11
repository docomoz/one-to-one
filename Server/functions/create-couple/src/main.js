// Точка входа функции Appwrite `create-couple`.
import { createCouple } from './create-couple.js';
import { appwriteServices, run } from './shared/http.js';

export const handle = (context, makeServices = appwriteServices) => run(context, createCouple, makeServices);

export default (context) => handle(context);
