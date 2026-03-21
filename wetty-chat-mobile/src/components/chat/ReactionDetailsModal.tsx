import { useState, useEffect } from 'react';
import { IonModal, IonContent, IonIcon } from '@ionic/react';
import { close } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { getReactionDetails, type ReactionReactor } from '@/api/messages';
import { useIsDesktop } from '@/hooks/useIsDesktop';

function getInitials(name: string): string {
  return name.slice(0, 2).toUpperCase();
}

function colorForUser(name: string): string {
  let hash = 0;
  for (const char of name) {
    hash = (hash << 5) - hash + char.charCodeAt(0);
    hash |= 0;
  }
  const hue = ((hash * 137) % 360 + 360) % 360;
  return `hsl(${hue}, 55%, 50%)`;
}

interface ReactionGroup {
  emoji: string;
  reactors: ReactionReactor[];
}

interface ReactionDetailsModalProps {
  chatId: string;
  messageId: string | null;
  initialEmoji?: string;
  onDismiss: () => void;
}

export function ReactionDetailsModal({ chatId, messageId, initialEmoji, onDismiss }: ReactionDetailsModalProps) {
  const isDesktop = useIsDesktop();
  const [groups, setGroups] = useState<ReactionGroup[]>([]);
  const [selectedEmoji, setSelectedEmoji] = useState<string | undefined>(initialEmoji);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!messageId) {
      setGroups([]);
      return;
    }
    setLoading(true);
    setSelectedEmoji(initialEmoji);
    getReactionDetails(chatId, messageId)
      .then(res => {
        setGroups(res.data.reactions);
        if (!initialEmoji && res.data.reactions.length > 0) {
          setSelectedEmoji(res.data.reactions[0].emoji);
        }
      })
      .catch(() => setGroups([]))
      .finally(() => setLoading(false));
  }, [chatId, messageId, initialEmoji]);

  const activeGroup = groups.find(g => g.emoji === selectedEmoji) ?? groups[0];

  return (
    <IonModal
      isOpen={messageId != null}
      onDidDismiss={onDismiss}
      {...(!isDesktop ? { initialBreakpoint: 0.5, breakpoints: [0, 0.5, 0.75] } : {})}
    >
      <IonContent className="ion-padding">
        <button
          onClick={onDismiss}
          aria-label={t`Close`}
          style={{
            position: 'absolute', top: 12, right: 12,
            background: 'var(--ion-color-light)', border: 'none', borderRadius: '50%',
            width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', zIndex: 1,
          }}
        >
          <IonIcon icon={close} style={{ fontSize: 20 }} />
        </button>

        {/* Emoji tabs */}
        <div style={{ display: 'flex', gap: 8, paddingTop: 8, paddingBottom: 16, flexWrap: 'wrap' }}>
          {groups.map(g => (
            <button
              key={g.emoji}
              onClick={() => setSelectedEmoji(g.emoji)}
              style={{
                padding: '4px 12px',
                borderRadius: 16,
                border: g.emoji === activeGroup?.emoji ? '2px solid var(--ion-color-primary)' : '1px solid var(--ion-color-light-shade)',
                background: g.emoji === activeGroup?.emoji ? 'rgba(var(--ion-color-primary-rgb), 0.1)' : 'transparent',
                cursor: 'pointer',
                fontSize: 18,
              }}
            >
              {g.emoji} {g.reactors.length}
            </button>
          ))}
        </div>

        {/* Reactor list */}
        {loading ? (
          <p style={{ textAlign: 'center', opacity: 0.6 }}>{t`Loading...`}</p>
        ) : activeGroup ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {activeGroup.reactors.map(reactor => {
              const displayName = reactor.name ?? `User ${reactor.uid}`;
              return (
                <div key={reactor.uid} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  {reactor.avatar_url ? (
                    <img
                      src={reactor.avatar_url}
                      alt={displayName}
                      style={{ width: 36, height: 36, borderRadius: '50%', objectFit: 'cover' }}
                    />
                  ) : (
                    <div style={{
                      width: 36, height: 36, borderRadius: '50%',
                      backgroundColor: colorForUser(displayName),
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      color: '#fff', fontSize: 14, fontWeight: 600, flexShrink: 0,
                    }}>
                      {getInitials(displayName)}
                    </div>
                  )}
                  <span style={{ fontSize: 15 }}>{displayName}</span>
                </div>
              );
            })}
          </div>
        ) : null}
      </IonContent>
    </IonModal>
  );
}
