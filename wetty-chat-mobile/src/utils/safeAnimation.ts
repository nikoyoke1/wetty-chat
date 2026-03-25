import { createAnimation, iosTransitionAnimation } from '@ionic/react';
import type { AnimationBuilder } from '@ionic/core/components';

let programmaticNav = false;
let browserBack = false;

const originalBack = history.back.bind(history);
const originalGo = history.go.bind(history);

history.back = (...args) => {
  programmaticNav = true;
  return originalBack(...args);
};

history.go = (...args) => {
  programmaticNav = true;
  return originalGo(...args);
};

window.addEventListener('popstate', () => {
  if (programmaticNav) {
    programmaticNav = false;
  } else {
    browserBack = true;
    requestAnimationFrame(() => {
      browserBack = false;
    });
  }
});

export const safeAnimation: AnimationBuilder = (baseEl, opts) => {
  if (browserBack) {
    return createAnimation();
  }
  return iosTransitionAnimation(baseEl, opts);
};
