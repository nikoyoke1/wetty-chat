import { prepareRichInline, measureRichInlineStats, type RichInlineItem } from '@chenglou/pretext/rich-inline';

export const URL_REGEX = /(https?:\/\/[A-Za-z0-9\-._~:/?#@!$&'()*+,;=%]+)/g;
export const TRAILING_PUNCT = /[.,);!?]+$/;
export const MENTION_TEST = /@\[uid:\d+\]/;
export const MENTION_REGEX = /@\[uid:(\d+)\]/g;

export function parseChatBubbleContentToRichItems(
  message: string,
  mentions: { uid: number; username?: string | null }[] | undefined,
  baseFont: string,
): RichInlineItem[] {
  const items: RichInlineItem[] = [];
  if (!message) return items;

  const mentionMap = new Map<number, string>();
  if (mentions) {
    for (const m of mentions) {
      if (m.username) mentionMap.set(m.uid, m.username);
    }
  }

  const regex = new RegExp(MENTION_REGEX);
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  const parseLinks = (text: string) => {
    const parts = text.split(URL_REGEX);
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (!part) continue;

      if (i % 2 === 1) {
        const trimmed = part.replace(TRAILING_PUNCT, '');
        const suffix = part.slice(trimmed.length);
        items.push({ text: trimmed, font: baseFont, break: 'normal' });
        if (suffix) {
          items.push({ text: suffix, font: baseFont });
        }
      } else {
        items.push({ text: part, font: baseFont });
      }
    }
  };

  while ((match = regex.exec(message)) !== null) {
    if (match.index > lastIndex) {
      parseLinks(message.slice(lastIndex, match.index));
    }

    const uid = parseInt(match[1], 10);
    const username = mentionMap.get(uid);
    items.push({
      text: `@${username ?? `User ${uid}`}`,
      font: baseFont,
      break: 'never',
      extraWidth: 0,
    });

    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < message.length) {
    parseLinks(message.slice(lastIndex));
  }

  return items;
}

export function getMessageLayoutStats(items: RichInlineItem[], maxWidth: number) {
  return measureRichInlineStats(prepareRichInline(items), maxWidth);
}

export const getChatBaseFont = (fontSize: string) =>
  `${fontSize} -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif`;

export function getChatBubbleMaxWidth(): number {
  if (typeof window === 'undefined') return 300;
  return window.innerWidth * 0.75 - 24;
}
