import { IonChip, IonItem, IonLabel, IonNote } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { UserAvatar } from '@/components/UserAvatar';
import styles from './ChatMemberRow.module.scss';

type ChatMemberRowMember = {
  uid: number;
  username: string | null;
  avatarUrl?: string | null;
};

interface ChatMemberRowProps<TMember extends ChatMemberRowMember = ChatMemberRowMember> {
  member: TMember;
  isAdmin?: boolean;
  isCurrentUser?: boolean;
  subtitle?: string | null;
  endLabel?: string | null;
  disabled?: boolean;
  onSelect?: (member: TMember) => void;
  role?: string | null;
}

export function ChatMemberRow<TMember extends ChatMemberRowMember>(props: ChatMemberRowProps<TMember>) {
  const { member, subtitle = null, endLabel = null, disabled = false, onSelect, role = null } = props;
  const displayName = member.username || t`User ${member.uid}`;
  const isClickable = !disabled && !!onSelect;
  const showRoleChip = !!role;

  return (
    <IonItem
      className={`${styles.row} ${disabled ? styles.rowDisabled : ''}`}
      button={isClickable}
      detail={false}
      onClick={isClickable ? () => onSelect?.(member) : undefined}
    >
      <UserAvatar name={displayName} avatarUrl={member.avatarUrl} size={40} className={styles.avatar} />
      <IonLabel className={styles.label}>
        <h3>{displayName}</h3>
        {subtitle ? <p>{subtitle}</p> : null}
      </IonLabel>
      {showRoleChip ? (
        <IonChip className={styles.roleChip} color={role === 'admin' ? 'primary' : 'medium'} slot="end">
          {role}
        </IonChip>
      ) : null}
      {!showRoleChip && endLabel ? (
        <IonNote className={styles.endNote} color="medium" slot="end">
          {endLabel}
        </IonNote>
      ) : null}
    </IonItem>
  );
}
