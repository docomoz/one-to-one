// Точка входа функции Appwrite `create-invite`.
import { createInvite } from './create-invite.js';
import { appwriteServices, run } from './shared/http.js';

export const handle = (context, makeServices = appwriteServices) => run(context, createInvite, makeServices);

export default (context) => handle(context);
