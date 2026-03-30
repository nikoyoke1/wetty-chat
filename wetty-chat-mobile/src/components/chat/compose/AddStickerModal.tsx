import { useRef } from 'react';
import { IonButton, IonButtons, IonContent, IonHeader, IonIcon, IonInput, IonItem, IonLabel, IonModal, IonTitle, IonToolbar } from '@ionic/react';
import { close } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import styles from './AddStickerModal.module.scss';

interface AddStickerModalProps {
  file: File | null;
  onDismiss: () => void;
  onAdd: (file: File, emoji: string, name: string) => void;
}

export function AddStickerModal({ file, onDismiss, onAdd }: AddStickerModalProps) {
  const emojiRef = useRef<HTMLIonInputElement>(null);
  const nameRef = useRef<HTMLIonInputElement>(null);

  const previewUrl = file ? URL.createObjectURL(file) : null;

  const handleAdd = () => {
    const emoji = String(emojiRef.current?.value ?? '').trim();
    if (!file || !emoji) return;
    const name = String(nameRef.current?.value ?? '').trim();
    onAdd(file, emoji, name);
  };

  return (
    <IonModal
      isOpen={file != null}
      onDidDismiss={onDismiss}
      initialBreakpoint={0.6}
      breakpoints={[0, 0.6]}
    >
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            <IonButton onClick={onDismiss} aria-label={t`Cancel`}>
              <IonIcon slot="icon-only" icon={close} />
            </IonButton>
          </IonButtons>
          <IonTitle>
            <Trans>Add Sticker</Trans>
          </IonTitle>
          <IonButtons slot="end">
            <IonButton strong onClick={handleAdd}>
              <Trans>Add</Trans>
            </IonButton>
          </IonButtons>
        </IonToolbar>
      </IonHeader>
      <IonContent className="ion-padding">
        {previewUrl && (
          <div className={styles.previewContainer}>
            {file?.type.startsWith('video/') ? (
              <video src={previewUrl} className={styles.previewMedia} autoPlay loop muted playsInline />
            ) : (
              <img src={previewUrl} alt={t`Sticker preview`} className={styles.previewMedia} />
            )}
          </div>
        )}
        <IonItem>
          <IonLabel position="stacked">
            <Trans>Emoji</Trans> *
          </IonLabel>
          <IonInput
            ref={emojiRef}
            placeholder="e.g. 😊"
            maxlength={32}
          />
        </IonItem>
        <IonItem>
          <IonLabel position="stacked">
            <Trans>Name</Trans>
          </IonLabel>
          <IonInput
            ref={nameRef}
            placeholder={t`Optional`}
            maxlength={255}
          />
        </IonItem>
      </IonContent>
    </IonModal>
  );
}
