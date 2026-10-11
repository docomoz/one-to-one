// Точка входа функции Appwrite `accept-invite`.
import { acceptInvite } from './accept-invite.js';
import { appwriteServices, run } from './shared/http.js';

export const handle = (context, makeServices = appwriteServices) => run(context, acceptInvite, makeServices);

export default (context) => handle(context);
