import { useState, useEffect, useCallback, useRef } from 'react';
import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonButton,
  IonButtons,
  IonSpinner,
  useIonToast,
  useIonAlert,
  useIonActionSheet,
} from '@ionic/react';
import { useParams } from 'react-router-dom';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { getMembers, addMember, removeMember, updateMemberRole, type MemberResponse } from '@/api/group';
import { Virtuoso } from 'react-virtuoso';
import { useSelector } from 'react-redux';
import type { RootState } from '@/store/index';
import { FeatureGate } from '@/components/FeatureGate';
import { BackButton } from '@/components/BackButton';
import type { BackAction } from '@/types/back-action';
import { ChatMemberRow } from '@/components/chat-members/ChatMemberRow';

const MEMBERS_PAGE_SIZE = 50;

function mergeMembers(existing: MemberResponse[], incoming: MemberResponse[]): MemberResponse[] {
  const seen = new Set(existing.map((member) => member.uid));
  const next = [...existing];

  for (const member of incoming) {
    if (seen.has(member.uid)) continue;
    seen.add(member.uid);
    next.push(member);
  }

  return next;
}

interface ChatMembersCoreProps {
  chatId?: string;
  backAction?: BackAction;
}

export default function ChatMembersCore({ chatId: propChatId, backAction }: ChatMembersCoreProps) {
  const { id } = useParams<{ id: string }>();
  const chatId = propChatId ?? (id ? String(id) : '');
  const currentUserId = useSelector((state: RootState) => state.user.uid);

  const [presentToast] = useIonToast();
  const [presentAlert] = useIonAlert();
  const [presentActionSheet] = useIonActionSheet();

  const [members, setMembers] = useState<MemberResponse[]>([]);
  const [initialLoading, setInitialLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [isAdmin, setIsAdmin] = useState(false);
  const [nextCursor, setNextCursor] = useState<number | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const loadingMoreRef = useRef(false);

  const showToast = useCallback((msg: string, duration = 3000) => {
    presentToast({ message: msg, duration });
  }, [presentToast]);

  const loadInitialMembers = useCallback(() => {
    if (!chatId) {
      setMembers([]);
      setInitialLoading(false);
      setLoadingMore(false);
      setNextCursor(null);
      setHasMore(false);
      setIsAdmin(false);
      return Promise.resolve();
    }

    loadingMoreRef.current = false;
    setInitialLoading(true);
    setLoadingMore(false);

    return getMembers(chatId, { limit: MEMBERS_PAGE_SIZE })
      .then((res) => {
        setMembers(res.data.members);
        setNextCursor(res.data.next_cursor);
        setHasMore(res.data.next_cursor != null);
        setIsAdmin(res.data.can_manage_members);
      })
      .catch((err: Error) => {
        showToast(err.message || t`Failed to load members`);
        setMembers([]);
        setNextCursor(null);
        setHasMore(false);
        setIsAdmin(false);
      })
      .finally(() => setInitialLoading(false));
  }, [chatId, showToast]);

  const loadMoreMembers = useCallback(() => {
    if (!chatId || !hasMore || nextCursor == null || loadingMoreRef.current) {
      return;
    }

    loadingMoreRef.current = true;
    setLoadingMore(true);

    getMembers(chatId, { limit: MEMBERS_PAGE_SIZE, after: nextCursor })
      .then((res) => {
        setMembers((current) => mergeMembers(current, res.data.members));
        setNextCursor(res.data.next_cursor);
        setHasMore(res.data.next_cursor != null);
        setIsAdmin(res.data.can_manage_members);
      })
      .catch((err: Error) => {
        showToast(err.message || t`Failed to load members`);
      })
      .finally(() => {
        loadingMoreRef.current = false;
        setLoadingMore(false);
      });
  }, [chatId, hasMore, nextCursor, showToast]);

  const resetAndReloadMembers = useCallback(() => {
    setMembers([]);
    setNextCursor(null);
    setHasMore(false);
    return loadInitialMembers();
  }, [loadInitialMembers]);

  useEffect(() => {
    loadInitialMembers();
  }, [loadInitialMembers]);

  const handleAddMember = () => {
    presentAlert({
      header: t`Add Member`,
      message: t`Enter user ID to add:`,
      inputs: [{ type: 'number', placeholder: t`User ID` }],
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: t`Add`,
          handler: (data: { 0: string }) => {
            const userId = parseInt(data[0], 10);
            if (isNaN(userId)) {
              showToast(t`Invalid user ID`, 2000);
              return;
            }
            addMember(chatId, { uid: userId })
              .then(() => {
                showToast(t`Member added`, 2000);
                resetAndReloadMembers();
              })
              .catch((err: Error) => {
                showToast(err.message || t`Failed to add member`);
              });
          },
        },
      ],
    });
  };

  const handleRemoveMember = (member: MemberResponse) => {
    const displayName = member.username || t`User ${member.uid}`;
    presentAlert({
      header: t`Remove Member`,
      message: t`Remove ${displayName} from this group?`,
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: t`Remove`,
          role: 'destructive',
          handler: () => {
            removeMember(chatId, member.uid)
              .then(() => {
                showToast(t`Member removed`, 2000);
                resetAndReloadMembers();
              })
              .catch((err: Error) => {
                showToast(err.message || t`Failed to remove member`);
              });
          },
        },
      ],
    });
  };

  const handleToggleRole = (member: MemberResponse) => {
    const newRole = member.role === 'admin' ? 'member' : 'admin';
    const isPromoting = newRole === 'admin';
    const displayName = member.username || t`User ${member.uid}`;
    presentAlert({
      header: isPromoting ? t`Promote Member` : t`Demote Member`,
      message: isPromoting
        ? t`Promote ${displayName} to admin?`
        : t`Demote ${displayName} to member?`,
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: isPromoting ? t`Promote` : t`Demote`,
          handler: () => {
            updateMemberRole(chatId, member.uid, { role: newRole })
              .then(() => {
                showToast(isPromoting ? t`Member promoted` : t`Member demoted`, 2000);
                resetAndReloadMembers();
              })
              .catch((err: Error) => {
                showToast(err.message || t`Failed to update role`);
              });
          },
        },
      ],
    });
  };

  const handleMemberTap = (member: MemberResponse) => {
    if (!isAdmin || member.uid === currentUserId) return;
    presentActionSheet({
      buttons: [
        {
          text: member.role === 'admin' ? t`Demote to Member` : t`Promote to Admin`,
          handler: () => handleToggleRole(member),
        },
        {
          text: t`Remove from Group`,
          role: 'destructive',
          handler: () => handleRemoveMember(member),
        },
        { text: t`Cancel`, role: 'cancel' },
      ],
    });
  };

  const renderMembersFooter = useCallback(() => {
    if (loadingMore) {
      return (
        <div style={{ display: 'flex', justifyContent: 'center', padding: '16px' }}>
          <IonSpinner />
        </div>
      );
    }

    if (members.length === 0) {
      return (
        <div style={{ padding: '16px', color: 'var(--ion-color-medium)' }}>
          <Trans>No members found.</Trans>
        </div>
      );
    }

    return null;
  }, [loadingMore, members.length]);

  return (
    <div className="ion-page">
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            {backAction && <BackButton action={backAction} />}
          </IonButtons>
          <IonTitle><Trans>Group Members</Trans></IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent scrollY={false}>
        {initialLoading ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '24px' }}>
            <IonSpinner />
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
            <FeatureGate>
              <div style={{ padding: '16px' }}>
                <IonButton expand="block" onClick={handleAddMember}>
                  <Trans>Add Member</Trans>
                </IonButton>
              </div>
            </FeatureGate>
            <div style={{ flex: 1, minHeight: 0 }}>
              <Virtuoso
                data={members}
                endReached={hasMore ? () => loadMoreMembers() : undefined}
                style={{ height: '100%' }}
                components={{ Footer: renderMembersFooter }}
                itemContent={(_, member) => (
                  <ChatMemberRow
                    member={member}
                    isAdmin={isAdmin}
                    isCurrentUser={member.uid === currentUserId}
                    onSelect={handleMemberTap}
                  />
                )}
              />
            </div>
          </div>
        )}
      </IonContent>
    </div>
  );
}

export function ChatMembersPage() {
  const { id } = useParams<{ id: string }>();
  return (
    <IonPage>
      <ChatMembersCore chatId={id} backAction={{ type: 'back', defaultHref: `/chats/chat/${id}` }} />
    </IonPage>
  );
}
