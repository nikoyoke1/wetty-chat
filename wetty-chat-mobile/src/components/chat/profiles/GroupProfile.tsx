import { IonSpinner } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { UserAvatar } from '@/components/UserAvatar';
import { getChatDisplayName } from '@/utils/chatDisplay';
import styles from './GroupProfile.module.scss';

interface GroupProfileProps {
  chatId: string;
  name?: string | null;
  description?: string | null;
  avatarUrl?: string | null;
  visibility?: 'public' | 'private';
  avatarEditable?: boolean;
  avatarUploading?: boolean;
  onAvatarClick?: () => void;
}

export function GroupProfile({
  chatId,
  name,
  description,
  avatarUrl,
  avatarEditable = false,
  avatarUploading = false,
  onAvatarClick,
}: GroupProfileProps) {
  const displayName = getChatDisplayName(chatId, name);
  const trimmedDescription = description?.trim() || null;

  return (
    <section className={styles.card}>
      <button
        type="button"
        className={avatarEditable ? styles.avatarButton : styles.avatarStatic}
        onClick={avatarEditable ? onAvatarClick : undefined}
        disabled={!avatarEditable || avatarUploading}
        aria-label={avatarEditable ? t`Change group photo` : undefined}
      >
        <UserAvatar name={displayName} avatarUrl={avatarUrl} size={112} className={styles.avatar} />
        {avatarEditable ? (
          <span className={styles.avatarOverlay}>
            {avatarUploading ? (
              <>
                <IonSpinner className={styles.avatarOverlaySpinner} name="crescent" />
                <Trans>Uploading...</Trans>
              </>
            ) : (
              <Trans>Change</Trans>
            )}
          </span>
        ) : null}
      </button>
      <h2 className={styles.title}>{displayName}</h2>
      <p className={trimmedDescription ? styles.description : styles.descriptionMuted}>
        {trimmedDescription ?? <Trans>No group description yet.</Trans>}
      </p>
    </section>
  );
}
