// Точка входа функции Appwrite `delete-account`.
import { deleteAccount } from './delete-account.js';
import { appwriteServices, run } from './shared/http.js';

export const handle = (context, makeServices = appwriteServices) => run(context, deleteAccount, makeServices);

export default (context) => handle(context);
