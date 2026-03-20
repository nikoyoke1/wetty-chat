import { IonChip, IonItem, IonLabel } from '@ionic/react';
import { t } from '@lingui/core/macro';
import type { MemberResponse } from '@/api/group';

interface ChatMemberRowProps {
  member: MemberResponse;
  isAdmin: boolean;
  isCurrentUser: boolean;
  onSelect: (member: MemberResponse) => void;
}

export function ChatMemberRow({
  member,
  isAdmin,
  isCurrentUser,
  onSelect,
}: ChatMemberRowProps) {
  return (
    <IonItem
      button={isAdmin && !isCurrentUser}
      detail={false}
      onClick={() => onSelect(member)}
    >
      <IonLabel>{member.username || t`User ${member.uid}`}</IonLabel>
      <IonChip
        color={member.role === 'admin' ? 'primary' : 'medium'}
        slot="end"
      >
        {member.role}
      </IonChip>
    </IonItem>
  );
}
