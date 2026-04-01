const RECOVERY_ATTEMPT_KEY = `wetty-chat:recovery-attempt:${__APP_VERSION__}`;
const RECOVERY_SCREEN_ID = 'wetty-chat-recovery-screen';

let recoveryInProgress = false;

function hasAttemptedRecovery(): boolean {
  try {
    return sessionStorage.getItem(RECOVERY_ATTEMPT_KEY) === '1';
  } catch {
    return false;
  }
}

function markRecoveryAttempted(): void {
  try {
    sessionStorage.setItem(RECOVERY_ATTEMPT_KEY, '1');
  } catch {
    // Ignore storage failures.
  }
}

function renderRecoveryScreen(message: string): void {
  if (document.getElementById(RECOVERY_SCREEN_ID)) {
    return;
  }

  const container = document.createElement('div');
  container.id = RECOVERY_SCREEN_ID;
  container.setAttribute('role', 'alert');
  container.style.position = 'fixed';
  container.style.inset = '0';
  container.style.zIndex = '999999';
  container.style.display = 'flex';
  container.style.flexDirection = 'column';
  container.style.alignItems = 'center';
  container.style.justifyContent = 'center';
  container.style.padding = '24px';
  container.style.background = '#f5f1e9';
  container.style.color = '#2c241b';
  container.style.fontFamily = '"SF Pro Display", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
  container.style.textAlign = 'center';

  const title = document.createElement('h1');
  title.textContent = 'Updating app…';
  title.style.margin = '0 0 12px';
  title.style.fontSize = '28px';

  const body = document.createElement('p');
  body.textContent = message;
  body.style.margin = '0';
  body.style.maxWidth = '320px';
  body.style.fontSize = '16px';
  body.style.lineHeight = '1.5';

  container.append(title, body);
  document.body.appendChild(container);
}

async function waitForInstalledWorker(registration: ServiceWorkerRegistration, timeoutMs = 10000): Promise<boolean> {
  if (registration.waiting) {
    return true;
  }

  return new Promise((resolve) => {
    let timeoutId = 0;
    let installingWorker: ServiceWorker | null = null;

    const finish = (installed: boolean) => {
      window.clearTimeout(timeoutId);
      registration.removeEventListener('updatefound', handleUpdateFound);
      installingWorker?.removeEventListener('statechange', handleStateChange);
      resolve(installed || Boolean(registration.waiting));
    };

    const handleStateChange = () => {
      if (!installingWorker) {
        return;
      }

      if (installingWorker.state === 'installed') {
        finish(true);
        return;
      }

      if (installingWorker.state === 'redundant') {
        finish(false);
      }
    };

    const watchInstallingWorker = (worker: ServiceWorker | null) => {
      if (!worker || worker === installingWorker) {
        return;
      }

      installingWorker?.removeEventListener('statechange', handleStateChange);
      installingWorker = worker;

      if (installingWorker.state === 'installed') {
        finish(true);
        return;
      }

      installingWorker.addEventListener('statechange', handleStateChange);
    };

    const handleUpdateFound = () => {
      watchInstallingWorker(registration.installing);
    };

    timeoutId = window.setTimeout(() => finish(false), timeoutMs);
    registration.addEventListener('updatefound', handleUpdateFound);
    watchInstallingWorker(registration.installing);
  });
}

async function attemptRecoveryUpgrade(reason: string): Promise<void> {
  if (recoveryInProgress || hasAttemptedRecovery()) {
    return;
  }

  recoveryInProgress = true;
  markRecoveryAttempted();

  renderRecoveryScreen('The app hit an unexpected error. Trying to load the latest version now.');
  console.error('Attempting recovery upgrade after fatal frontend error', { reason, version: __APP_VERSION__ });

  try {
    if (!('serviceWorker' in navigator)) {
      renderRecoveryScreen('The app could not update automatically. Please reload this page.');
      return;
    }

    const registration = await navigator.serviceWorker.getRegistration();
    if (!registration) {
      renderRecoveryScreen('No app update is installed yet. Please reload this page.');
      return;
    }

    const reloadOnce = () => {
      navigator.serviceWorker.removeEventListener('controllerchange', reloadOnce);
      window.location.reload();
    };

    navigator.serviceWorker.addEventListener('controllerchange', reloadOnce);

    if (!registration.waiting) {
      await registration.update();
    }

    if (!(await waitForInstalledWorker(registration))) {
      navigator.serviceWorker.removeEventListener('controllerchange', reloadOnce);
      renderRecoveryScreen('No newer version is available yet. Please try again in a moment.');
      recoveryInProgress = false;
      return;
    }

    registration.waiting?.postMessage({ type: 'SKIP_WAITING' });
  } catch (error) {
    console.error('Recovery upgrade failed', error);
    renderRecoveryScreen('The app update failed. Please reload this page.');
    recoveryInProgress = false;
  }
}

export function installBootstrapRecoveryHandlers(): void {
  const handleWindowError = (event: ErrorEvent) => {
    void attemptRecoveryUpgrade(event.message || 'window.error');
  };

  const handleUnhandledRejection = (event: PromiseRejectionEvent) => {
    const reason = event.reason instanceof Error ? event.reason.message : String(event.reason ?? 'unhandledrejection');
    void attemptRecoveryUpgrade(reason);
  };

  window.addEventListener('error', handleWindowError);
  window.addEventListener('unhandledrejection', handleUnhandledRejection);
}
