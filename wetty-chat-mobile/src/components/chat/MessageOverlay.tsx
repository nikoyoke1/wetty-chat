import { useEffect, useLayoutEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { IonIcon } from '@ionic/react';
import type { Attachment } from '@/api/messages';
import { ChatBubbleBase } from './messages/ChatBubbleBase';
import styles from './MessageOverlay.module.scss';

export interface MessageOverlayAction {
  key: string;
  label: string;
  icon?: string;
  role?: 'destructive';
  disabled?: boolean;
  handler: () => void;
}

interface MessageOverlayProps {
  messageType?: 'text' | 'audio' | 'system' | 'invite';
  senderName: string;
  message: string;
  isSent: boolean;
  showName?: boolean;
  replyTo?: {
    senderName: string;
    message?: string | null;
    attachments?: Attachment[];
    firstAttachmentKind?: string | null;
    isDeleted?: boolean;
  };
  timestamp?: string;
  edited?: boolean;
  isConfirmed?: boolean;
  attachments?: Attachment[];
  sourceRect: DOMRect;
  actions: MessageOverlayAction[];
  reactions?: {
    emojis: string[];
    onReact: (emoji: string) => void;
  };
  onClose: () => void;
}

export function MessageOverlay({
  messageType = 'text',
  senderName,
  message,
  isSent,
  showName = true,
  replyTo,
  timestamp,
  edited,
  isConfirmed,
  attachments,
  sourceRect,
  actions,
  reactions,
  onClose,
}: MessageOverlayProps) {
  const contentRef = useRef<HTMLDivElement>(null);

  // Compute position after first render so we know the full content dimensions
  useLayoutEffect(() => {
    const content = contentRef.current;
    if (!content) return;
    const contentRect = content.getBoundingClientRect();
    const pad = 40;
    const visualViewport = window.visualViewport;
    const vh = visualViewport?.height ?? window.innerHeight;
    const vw = visualViewport?.width ?? window.innerWidth;
    const offsetTop = visualViewport?.offsetTop ?? 0;
    const offsetLeft = visualViewport?.offsetLeft ?? 0;

    // Start at the original bubble position, offset by the bubble clone's
    // position within the content container (reactions may be above it)
    const bubbleEl = content.querySelector('[data-bubble-clone]') as HTMLElement | null;
    const bubbleOffsetTop = bubbleEl ? bubbleEl.offsetTop : 0;

    let top = sourceRect.top - bubbleOffsetTop;

    // For sent messages, align right edge to source right edge
    let left = isSent ? sourceRect.right - contentRect.width : sourceRect.left;

    // Clamp vertically: ensure the entire content (reactions + bubble + actions) fits
    if (top + contentRect.height > offsetTop + vh - pad) {
      top = offsetTop + vh - pad - contentRect.height;
    }
    if (top < offsetTop + pad) {
      top = offsetTop + pad;
    }

    // Clamp horizontally
    if (left + contentRect.width > offsetLeft + vw - pad) {
      left = offsetLeft + vw - pad - contentRect.width;
    }
    if (left < offsetLeft + pad) {
      left = offsetLeft + pad;
    }

    content.style.top = `${top}px`;
    content.style.left = `${left}px`;
    content.style.visibility = 'visible';
  }, [isSent, sourceRect]);

  // Body scroll lock
  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);

  // Escape key dismissal
  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        onClose();
      }
    }
    document.addEventListener('keydown', onKeyDown);
    return () => document.removeEventListener('keydown', onKeyDown);
  }, [onClose]);

  function handleBackdropClick(e: React.MouseEvent) {
    if (e.target === e.currentTarget) {
      onClose();
    }
  }

  const overlay = (
    <div className={styles.overlay} onClick={handleBackdropClick}>
      <div
        ref={contentRef}
        className={`${styles.content} ${isSent ? styles.contentSent : ''} ${styles.contentVisible}`}
        style={{ top: sourceRect.top, left: sourceRect.left, visibility: 'hidden' }}
      >
        {/* Reaction bar */}
        {reactions && (
          <div className={styles.reactionBar}>
            {reactions.emojis.map((emoji) => (
              <button
                key={emoji}
                type="button"
                className={styles.reactionBtn}
                onClick={() => {
                  reactions.onReact(emoji);
                  onClose();
                }}
              >
                {emoji}
              </button>
            ))}
          </div>
        )}

        {/* Bubble clone */}
        <ChatBubbleBase
          messageType={messageType}
          senderName={senderName}
          message={message}
          isSent={isSent}
          showName={showName}
          showAvatar={false}
          replyTo={replyTo}
          timestamp={timestamp}
          edited={edited}
          isConfirmed={isConfirmed}
          attachments={attachments}
          layout="bubble-only"
          interactionMode="read-only"
          bubbleProps={{
            'data-bubble-clone': 'true',
            className: styles.bubbleClone,
            style: { width: sourceRect.width },
          }}
        />

        {/* Action list */}
        <div className={styles.actionList}>
          {actions.map((action) => (
            <button
              key={action.key}
              type="button"
              disabled={action.disabled}
              className={`${styles.actionItem} ${action.role === 'destructive' ? styles.actionDestructive : ''} ${action.disabled ? styles.actionDisabled : ''}`}
              onClick={() => {
                if (action.disabled) return;
                action.handler();
                onClose();
              }}
            >
              {action.icon && <IonIcon icon={action.icon} />}
              {action.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );

  return createPortal(overlay, document.body);
}
