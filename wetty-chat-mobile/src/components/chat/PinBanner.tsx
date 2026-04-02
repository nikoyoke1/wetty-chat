import { IonIcon, useIonAlert } from '@ionic/react';
import { chatbubbles, close, listOutline, pin } from 'ionicons/icons';
import { useCallback } from 'react';
import { useSelector } from 'react-redux';
import { t } from '@lingui/core/macro';
import type { RootState } from '@/store/index';
import { selectLatestPin, selectPinsForChat } from '@/store/pinsSlice';
import { selectEffectiveLocale } from '@/store/settingsSlice';
import { deletePin } from '@/api/pins';
import { formatMessagePreview, getNotificationPreviewLabels } from '@/utils/messagePreview';
import styles from './PinBanner.module.scss';

interface PinBannerProps {
  chatId: string;
  onClickPin: (messageId: string) => void;
  onClickThread: (messageId: string) => void;
  onClickCounter: () => void;
}

export function PinBanner({ chatId, onClickPin, onClickThread, onClickCounter }: PinBannerProps) {
  const [presentAlert] = useIonAlert();
  const latestPin = useSelector((state: RootState) => selectLatestPin(state, chatId));
  const pins = useSelector((state: RootState) => selectPinsForChat(state, chatId));
  const locale = useSelector(selectEffectiveLocale);

  const handleUnpin = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      e.stopPropagation();
      if (!latestPin) return;
      presentAlert({
        header: t`Unpin Message`,
        message: t`Are you sure you want to unpin this message?`,
        buttons: [
          { text: t`Cancel`, role: 'cancel' },
          {
            text: t`Unpin`,
            role: 'destructive',
            handler: () => {
              deletePin(chatId, latestPin.id).catch(() => {});
            },
          },
        ],
      });
    },
    [chatId, latestPin, presentAlert],
  );

  const handleThreadClick = useCallback(
    (e: React.MouseEvent) => {
      e.stopPropagation();
      if (latestPin) {
        onClickThread(latestPin.message.id);
      }
    },
    [latestPin, onClickThread],
  );

  const handleCounterClick = useCallback(
    (e: React.MouseEvent) => {
      e.stopPropagation();
      onClickCounter();
    },
    [onClickCounter],
  );

  if (!latestPin) return null;

  const msg = latestPin.message;
  const previewText = formatMessagePreview(msg, getNotificationPreviewLabels(locale)) || t`Message`;

  return (
    <div className={styles.banner}>
      <div
        className={styles.pinContent}
        onClick={() => onClickPin(msg.id)}
        role="button"
        tabIndex={0}
        aria-label={t`Pinned message`}
      >
        <IonIcon icon={pin} className={styles.pinIcon} />
        <div className={styles.text}>
          <span className={styles.senderName}>{msg.sender.name ?? `User ${msg.sender.uid}`}</span>
          <span className={styles.messageText}>{previewText}</span>
        </div>
      </div>

      {msg.threadInfo && (
        <button className={styles.threadBtn} onClick={handleThreadClick} aria-label={t`Open thread`}>
          <IonIcon icon={chatbubbles} />
        </button>
      )}

      {pins.length > 1 && (
        <button className={styles.listBtn} onClick={handleCounterClick} aria-label={t`View all pinned messages`}>
          <IonIcon icon={listOutline} />
          <span className={styles.listCount}>{pins.length}</span>
        </button>
      )}

      <button className={styles.closeBtn} onClick={handleUnpin} aria-label={t`Unpin`}>
        <IonIcon icon={close} />
      </button>
    </div>
  );
}
