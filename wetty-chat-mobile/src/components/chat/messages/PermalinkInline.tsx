import { useIonToast } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { useHistory } from 'react-router-dom';
import { useIsDesktop } from '@/hooks/platformHooks';
import { openPermalinkTarget } from '@/utils/openPermalinkTarget';
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
  const isDesktop = useIsDesktop();
  const [presentToast] = useIonToast();

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

        if (ctx && ctx.chatId === targetChatId && !ctx.threadId) {
          // Same main chat (not inside a thread) — scroll to message in place
          console.debug('[PermalinkInline] jumping within current chat', { targetMessageId });
          ctx.jumpToMessage(targetMessageId);
        } else {
          // Different chat — resolve the destination directly to avoid flashing the resolver page
          console.debug('[PermalinkInline] resolving direct permalink navigation', {
            targetChatId,
            targetMessageId,
            encoded,
            isDesktop,
          });
          void openPermalinkTarget({
            chatId: targetChatId,
            messageId: targetMessageId,
            isDesktop,
            preserveCurrentEntry: true,
          }).catch((err) => {
            console.debug('[PermalinkInline] direct permalink navigation failed, falling back to resolver route', {
              targetChatId,
              targetMessageId,
              encoded,
              status: err?.response?.status,
              err,
            });
            presentToast({
              message: err?.response?.status === 404 ? t`Message not found` : t`Failed to open link`,
              duration: 2000,
              color: 'danger',
            });
            history.push(`/m/${encoded}`);
          });
        }
      }}
    >
      {url}
    </a>
  );
}
