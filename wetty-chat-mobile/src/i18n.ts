import { i18n } from '@lingui/core';
import { detectLocale, supportedLocales } from './store/settingsSlice';
import { kvSet } from './utils/db';

export async function dynamicActivate(locale: string) {
  const { messages } = await import(`../locales/${locale}/messages.po`);
  i18n.load(locale, messages);
  i18n.activate(locale);
  document.documentElement.lang = locale;
}

export async function activateDetectedLocale(savedLocale?: string | null) {
  const locale = savedLocale && supportedLocales.includes(savedLocale) ? savedLocale : detectLocale();
  await dynamicActivate(locale);
  void kvSet('effective_locale', locale);
}

export { i18n };
