import { v4 as uuidv4 } from 'uuid';

const CLIENT_ID_STORAGE_KEY = 'client_id';
const CLIENT_ID_CACHE_NAME = 'wetty-chat-client-id';
const CLIENT_ID_CACHE_PATH = `${import.meta.env.BASE_URL}__client_id__`;

function generateClientId(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  return uuidv4();
}

function isValidClientId(value: string): boolean {
  return value.length > 0 && value.length <= 64 && /^[A-Za-z0-9_-]+$/.test(value);
}

export async function persistClientIdForServiceWorker(clientId: string): Promise<void> {
  if (typeof caches === 'undefined') return;

  const cache = await caches.open(CLIENT_ID_CACHE_NAME);
  await cache.put(
    CLIENT_ID_CACHE_PATH,
    new Response(clientId, {
      headers: { 'Content-Type': 'text/plain' },
    }),
  );
}

export async function loadClientIdForServiceWorker(): Promise<string | null> {
  if (typeof caches === 'undefined') return null;

  const cache = await caches.open(CLIENT_ID_CACHE_NAME);
  const response = await cache.match(CLIENT_ID_CACHE_PATH);
  if (!response) return null;

  const clientId = (await response.text()).trim();
  return isValidClientId(clientId) ? clientId : null;
}

export function getOrCreateClientId(): string {
  let clientId: string | null = null;

  if (typeof window !== 'undefined') {
    try {
      const stored = window.localStorage.getItem(CLIENT_ID_STORAGE_KEY);
      if (stored && isValidClientId(stored)) {
        clientId = stored;
      }
    } catch {
      // ignore storage access failures
    }
  }

  if (!clientId) {
    clientId = generateClientId();
    if (typeof window !== 'undefined') {
      try {
        window.localStorage.setItem(CLIENT_ID_STORAGE_KEY, clientId);
      } catch {
        // ignore storage access failures
      }
    }
  }

  void persistClientIdForServiceWorker(clientId);
  return clientId;
}

export function initializeClientId(): string {
  return getOrCreateClientId();
}
