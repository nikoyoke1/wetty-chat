/// <reference lib="webworker" />
import { cleanupOutdatedCaches, createHandlerBoundToURL, precacheAndRoute } from 'workbox-precaching';
import { NavigationRoute, registerRoute } from 'workbox-routing';
import { getHighWaterMark, kvGet, setHighWaterMark } from './utils/db';
import { formatNotificationBody, getNotificationPreviewLabels, type PreviewMessage } from './utils/messagePreview';

declare let self: ServiceWorkerGlobalScope;

interface PushPayload {
  type?: 'newMessage';
  title?: string;
  body?: string;
  senderName?: string;
  messagePreview?: PreviewMessage;
  data?: {
    chatId?: string;
    messageId?: string;
  };
}

async function updateHighWaterMarkIdb(chatId: string, messageId: string): Promise<void> {
  try {
    const id = BigInt(messageId);
    const current = await getHighWaterMark(chatId);
    if (current == null || id > BigInt(current)) {
      await setHighWaterMark(chatId, messageId);
    }
  } catch {
    /* non-numeric id, ignore */
  }
}

async function isAlreadyNotified(chatId: string, messageId: string): Promise<boolean> {
  try {
    const id = BigInt(messageId);
    const mark = await getHighWaterMark(chatId);
    return mark != null && id <= BigInt(mark);
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
      event.waitUntil(updateHighWaterMarkIdb(String(chatId), String(messageId)));
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
  if (!event.data) return;

  event.waitUntil(
    (async () => {
      try {
        const payload = event.data!.json() as PushPayload;
        const title = payload.title || 'New Message';
        let body = payload.body ?? '';

        if (payload.messagePreview) {
          try {
            const locale = await kvGet<string>('effective_locale');
            body = formatNotificationBody(
              payload.senderName ?? 'Someone',
              payload.messagePreview,
              getNotificationPreviewLabels(locale),
            );
          } catch (err) {
            console.error('Failed to localize push preview, using legacy body', err);
          }
        }

        const chatId = payload.data?.chatId;
        const messageId = payload.data?.messageId;

        if (chatId && messageId && (await isAlreadyNotified(String(chatId), String(messageId)))) {
          return;
        }

        if (chatId && messageId) {
          await updateHighWaterMarkIdb(String(chatId), String(messageId));
        }

        const tag = messageId ? `msg_${messageId}` : undefined;

        await self.registration.showNotification(title, {
          body,
          icon: '/icon/pwa-192x192.png',
          badge: '/icon/pwa-64x64.png',
          tag,
          data: payload,
        });
      } catch (err) {
        console.error('Failed to parse push event payload', err);
      }
    })(),
  );
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
