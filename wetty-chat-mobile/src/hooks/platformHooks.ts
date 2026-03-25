import { isPlatform } from '@ionic/react';
import { useEffect, useState } from 'react';

const DESKTOP_QUERY = '(min-width: 900px)';
let hasMouseDetected = false;
let mouseDetectionAttached = false;
const mouseSubscribers = new Set<(value: boolean) => void>();

function notifyMouseSubscribers(value: boolean) {
  for (const subscriber of mouseSubscribers) {
    subscriber(value);
  }
}

function enableMouseDetected() {
  if (hasMouseDetected) {
    return;
  }

  hasMouseDetected = true;
  notifyMouseSubscribers(true);
}

function attachMouseDetection() {
  if (mouseDetectionAttached || typeof window === 'undefined') {
    return;
  }

  mouseDetectionAttached = true;

  const handleMouseActivity = () => {
    enableMouseDetected();
    window.removeEventListener('mousemove', handleMouseActivity);
    window.removeEventListener('mousedown', handleMouseActivity);
    window.removeEventListener('pointerdown', handlePointerDown);
  };

  const handlePointerDown = (event: PointerEvent) => {
    if (event.pointerType === 'mouse') {
      handleMouseActivity();
    }
  };

  window.addEventListener('mousemove', handleMouseActivity, { passive: true });
  window.addEventListener('mousedown', handleMouseActivity, { passive: true });
  window.addEventListener('pointerdown', handlePointerDown, { passive: true });
}

export function useIsDesktop(): boolean {
  const [isDesktop, setIsDesktop] = useState(() => window.matchMedia(DESKTOP_QUERY).matches);

  useEffect(() => {
    const mq = window.matchMedia(DESKTOP_QUERY);
    const handler = (e: MediaQueryListEvent) => setIsDesktop(e.matches);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);

  return isDesktop;
}

const DARK_MODE_QUERY = '(prefers-color-scheme: dark)';

export function useIsDarkMode(): boolean {
  const [isDarkMode, setIsDarkMode] = useState(() => window.matchMedia(DARK_MODE_QUERY).matches);

  useEffect(() => {
    const mq = window.matchMedia(DARK_MODE_QUERY);
    const handler = (e: MediaQueryListEvent) => setIsDarkMode(e.matches);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);

  return isDarkMode;
}

export function useIsPWA(): boolean {
  const [isPWA, setIsPWA] = useState(() => (typeof window !== 'undefined' ? isPlatform('pwa') : false));

  useEffect(() => {
    if (typeof window === 'undefined' || window.matchMedia == null) {
      return;
    }

    const mediaQuery = window.matchMedia('(display-mode: standalone)');
    const updateIsPWA = () => {
      setIsPWA(mediaQuery.matches || isPlatform('pwa'));
    };

    updateIsPWA();
    mediaQuery.addEventListener('change', updateIsPWA);

    return () => {
      mediaQuery.removeEventListener('change', updateIsPWA);
    };
  }, []);

  return isPWA;
}

export function useMouseDetected(): boolean {
  const [mouseDetected, setMouseDetected] = useState(hasMouseDetected);

  useEffect(() => {
    mouseSubscribers.add(setMouseDetected);
    attachMouseDetection();

    return () => {
      mouseSubscribers.delete(setMouseDetected);
    };
  }, []);

  return mouseDetected;
}
