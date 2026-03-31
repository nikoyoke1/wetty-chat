import { v4 as uuidv4 } from 'uuid';

const CLIENT_ID_STORAGE_KEY = 'client_id';

function generateClientId(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  return uuidv4();
}

function isValidClientId(value: string): boolean {
  return value.length > 0 && value.length <= 64 && /^[A-Za-z0-9_-]+$/.test(value);
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

  return clientId;
}

export function initializeClientId(): string {
  return getOrCreateClientId();
}
