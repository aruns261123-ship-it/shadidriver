import { store } from '../store/memory-store.js';
import { newId } from '../utils/crypto.js';

export function notify(userId, title, body, dataPayload = {}) {
  const item = {
    id: newId(),
    userId,
    title,
    body,
    isRead: false,
    createdAt: new Date().toISOString(),
    dataPayload,
  };
  store.notifications.push(item);
  return item;
}

export const notificationsService = {
  list(user) {
    return store.notifications
      .filter((n) => n.userId === user.id)
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .map(({ id, title, body, isRead, createdAt }) => ({ id, title, body, isRead, createdAt }));
  },

  markRead(user, id) {
    const item = store.notifications.find((n) => n.id === id && n.userId === user.id);
    if (item) item.isRead = true;
    return { read: true };
  },
};
