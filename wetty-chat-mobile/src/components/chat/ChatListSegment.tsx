import { IonBadge, IonLabel, IonSegment, IonSegmentButton } from '@ionic/react';
import { Trans } from '@lingui/react/macro';
import styles from './ChatListSegment.module.scss';

export type ChatListTab = 'all' | 'groups' | 'threads';

interface ChatListSegmentProps {
  value: ChatListTab;
  onChange: (tab: ChatListTab) => void;
  allUnreadCount: number;
  groupsUnreadCount: number;
  threadsUnreadCount: number;
}

function UnreadBadge({ count }: { count: number }) {
  if (count <= 0) return null;
  return (
    <IonBadge mode="ios" color="primary" className={styles.badge}>
      {count > 99 ? '99+' : count}
    </IonBadge>
  );
}

export function ChatListSegment({
  value,
  onChange,
  allUnreadCount,
  groupsUnreadCount,
  threadsUnreadCount,
}: ChatListSegmentProps) {
  return (
    <div className={styles.segmentWrapper}>
      <IonSegment
        mode="ios"
        value={value}
        onIonChange={(e) => {
          const val = e.detail.value as ChatListTab | undefined;
          if (val) onChange(val);
        }}
      >
        <IonSegmentButton value="all">
          <IonLabel>
            <Trans>All</Trans>
            <UnreadBadge count={allUnreadCount} />
          </IonLabel>
        </IonSegmentButton>
        <IonSegmentButton value="groups">
          <IonLabel>
            <Trans>Groups</Trans>
            <UnreadBadge count={groupsUnreadCount} />
          </IonLabel>
        </IonSegmentButton>
        <IonSegmentButton value="threads">
          <IonLabel>
            <Trans>Threads</Trans>
            <UnreadBadge count={threadsUnreadCount} />
          </IonLabel>
        </IonSegmentButton>
      </IonSegment>
    </div>
  );
}
