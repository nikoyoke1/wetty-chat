import { useHistory } from 'react-router-dom';
import styles from './ChatBubble.module.scss';
import { useChatContext } from './ChatContext';

interface PermalinkInlineProps {
  targetChatId: string;
  targetMessageId: string;
  encoded: string;
  url: string;
}

export function PermalinkInline({ targetChatId, targetMessageId, encoded, url }: PermalinkInlineProps) {
  const history = useHistory();
  const ctx = useChatContext();

  return (
    <a
      href={url}
      className={styles.messageLink}
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        console.debug('[PermalinkInline] link click', {
          currentChatId: ctx?.chatId ?? null,
          targetChatId,
          targetMessageId,
          encoded,
          url,
        });

        if (ctx && ctx.chatId === targetChatId) {
          // Same chat/thread — scroll to message in place
          console.debug('[PermalinkInline] jumping within current chat', { targetMessageId });
          ctx.jumpToMessage(targetMessageId);
        } else {
          // Different chat — navigate through permalink resolver
          console.debug('[PermalinkInline] routing through permalink page', { encoded });
          history.push(`/m/${encoded}`);
        }
      }}
    >
      {url}
    </a>
  );
}
