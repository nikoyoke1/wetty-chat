/// <reference lib="webworker" />
import { cleanupOutdatedCaches, createHandlerBoundToURL, precacheAndRoute } from 'workbox-precaching';
import { NavigationRoute, registerRoute } from 'workbox-routing';

declare let self: ServiceWorkerGlobalScope;

/** Per-chat high-water mark of the largest message ID we already notified about. */
const notifiedHighWaterMark = new Map<string, bigint>();

function updateHighWaterMark(chatId: string, messageId: string): void {
  try {
    const id = BigInt(messageId);
    const prev = notifiedHighWaterMark.get(chatId);
    if (prev == null || id > prev) {
      notifiedHighWaterMark.set(chatId, id);
    }
  } catch {
    /* non-numeric id, ignore */
  }
}

function isAlreadyNotified(chatId: string, messageId: string): boolean {
  try {
    const id = BigInt(messageId);
    const mark = notifiedHighWaterMark.get(chatId);
    return mark != null && id <= mark;
  } catch {
    return false;
  }
}

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  if (event.data && event.data.type === 'NOTIFIED') {
    const { chatId, messageId } = event.data;
    if (chatId && messageId) {
      updateHighWaterMark(String(chatId), String(messageId));
    }
  }
});

const manifest = self.__WB_MANIFEST;
precacheAndRoute(manifest);

// clean old assets
cleanupOutdatedCaches();

// Catch routing to index.html for SPA
let allowlist: undefined | RegExp[];
if (import.meta.env.DEV) {
  allowlist = [/^\/$/];
}

// Workaround for dev server: only register navigation route if index.html is precached
const hasPrecachedIndex = manifest.some((entry) => (typeof entry === 'string' ? entry : entry.url) === 'index.html');

if (hasPrecachedIndex) {
  registerRoute(
    new NavigationRoute(createHandlerBoundToURL('index.html'), {
      allowlist,
      denylist: [/^\/_api/],
    }),
  );
}

self.addEventListener('push', (event) => {
  if (event.data) {
    try {
      const payload = event.data.json();
      const title = payload.title || 'New Message';
      const body = payload.body;

      const chatId = payload.data?.chat_id;
      const messageId = payload.data?.message_id;

      // Deduplicate: skip if WS (or an earlier push) already notified a newer message in this chat
      if (chatId && messageId && isAlreadyNotified(String(chatId), String(messageId))) {
        return;
      }

      if (chatId && messageId) {
        updateHighWaterMark(String(chatId), String(messageId));
      }

      const tag = messageId ? `msg_${messageId}` : undefined;

      const promiseChain = self.registration.showNotification(title, {
        body: body,
        icon: '/icon/pwa-192x192.png',
        badge: '/icon/pwa-64x64.png',
        tag,
        data: payload,
      });

      event.waitUntil(promiseChain);
    } catch (err) {
      console.error('Failed to parse push event payload', err);
    }
  }
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  // Attempt to focus the app main window if it is open, else open it
  event.waitUntil(
    self.clients.matchAll({ type: 'window' }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.startsWith(self.registration.scope) && 'focus' in client) {
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(`${import.meta.env.BASE_URL}`);
      }
    }),
  );
});
