import { useRef, useState } from 'react';
import {
  IonBackButton,
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonPage,
  IonTitle,
  IonToolbar,
  useIonAlert,
  useIonToast,
} from '@ionic/react';
import { useParams } from 'react-router-dom';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { BackButton } from '@/components/BackButton';
import { AddStickerModal } from '@/components/chat/compose/AddStickerModal';
import type { BackAction } from '@/types/back-action';
import styles from './StickerPackDetail.module.scss';

interface MockSticker {
  id: string;
  emoji: string;
  label: string;
}

// Same mock packs keyed by id — in real impl this would come from API/store
const MOCK_PACK_DATA: Record<string, { name: string; icon: string; owned: boolean; stickers: MockSticker[] }> = {
  smileys: {
    name: 'Smileys',
    icon: '😀',
    owned: true,
    stickers: [
      { id: 'sml-1', emoji: '😀', label: 'Grinning' },
      { id: 'sml-2', emoji: '😄', label: 'Grinning with big eyes' },
      { id: 'sml-3', emoji: '😆', label: 'Grinning squinting' },
      { id: 'sml-4', emoji: '🤣', label: 'Rolling on the floor' },
      { id: 'sml-5', emoji: '😅', label: 'Sweat smile' },
      { id: 'sml-6', emoji: '😊', label: 'Smiling face' },
      { id: 'sml-7', emoji: '🥰', label: 'Smiling with hearts' },
      { id: 'sml-8', emoji: '😍', label: 'Heart eyes' },
      { id: 'sml-9', emoji: '🤩', label: 'Star-struck' },
      { id: 'sml-10', emoji: '😎', label: 'Cool' },
      { id: 'sml-11', emoji: '🔥', label: 'Fire' },
      { id: 'sml-12', emoji: '😏', label: 'Smirking' },
    ],
  },
  animals: {
    name: 'Animals',
    icon: '🐶',
    owned: false,
    stickers: [
      { id: 'ani-1', emoji: '🐶', label: 'Dog' },
      { id: 'ani-2', emoji: '🐱', label: 'Cat' },
      { id: 'ani-3', emoji: '🐭', label: 'Mouse' },
      { id: 'ani-4', emoji: '🐹', label: 'Hamster' },
      { id: 'ani-5', emoji: '🐰', label: 'Rabbit' },
      { id: 'ani-6', emoji: '🦊', label: 'Fox' },
      { id: 'ani-7', emoji: '🐻', label: 'Bear' },
      { id: 'ani-8', emoji: '🐼', label: 'Panda' },
      { id: 'ani-9', emoji: '🐨', label: 'Koala' },
      { id: 'ani-10', emoji: '🐯', label: 'Tiger' },
    ],
  },
  food: {
    name: 'Food',
    icon: '🍕',
    owned: false,
    stickers: [
      { id: 'food-1', emoji: '🍕', label: 'Pizza' },
      { id: 'food-2', emoji: '🍔', label: 'Burger' },
      { id: 'food-3', emoji: '🌮', label: 'Taco' },
      { id: 'food-4', emoji: '🍜', label: 'Noodles' },
      { id: 'food-5', emoji: '🍣', label: 'Sushi' },
      { id: 'food-6', emoji: '🍩', label: 'Donut' },
      { id: 'food-7', emoji: '🍦', label: 'Ice cream' },
      { id: 'food-8', emoji: '🧋', label: 'Bubble tea' },
    ],
  },
};

interface StickerPackDetailCoreProps {
  packId: string;
  backAction?: BackAction;
}

export function StickerPackDetailCore({ packId, backAction }: StickerPackDetailCoreProps) {
  const packData = MOCK_PACK_DATA[packId];
  const [stickers, setStickers] = useState<MockSticker[]>(packData?.stickers ?? []);
  const [addStickerFile, setAddStickerFile] = useState<File | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [presentAlert] = useIonAlert();
  const [presentToast] = useIonToast();

  if (!packData) {
    return (
      <IonPage>
        <IonHeader>
          <IonToolbar>
            <IonButtons slot="start">
              {backAction ? <BackButton action={backAction} /> : <IonBackButton defaultHref="/settings/stickers" />}
            </IonButtons>
            <IonTitle>
              <Trans>Pack</Trans>
            </IonTitle>
          </IonToolbar>
        </IonHeader>
        <IonContent className="ion-padding">
          <p>
            <Trans>Pack not found.</Trans>
          </p>
        </IonContent>
      </IonPage>
    );
  }

  const { name, owned } = packData;

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0] ?? null;
    e.target.value = '';
    if (file) setAddStickerFile(file);
  };

  const handleAddSticker = (file: File, emoji: string, stickerName: string) => {
    console.log('Add sticker to pack (placeholder):', { packId, emoji, name: stickerName, file: file.name });
    setStickers((prev) => [
      ...prev,
      { id: `new-${Date.now()}`, emoji, label: stickerName || emoji },
    ]);
    setAddStickerFile(null);
    presentToast({ message: t`Sticker added`, duration: 1500, position: 'bottom' });
  };

  const handleRemoveSticker = (stickerId: string) => {
    presentAlert({
      header: t`Remove Sticker`,
      message: t`Remove this sticker from the pack?`,
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: t`Remove`,
          role: 'destructive',
          handler: () => {
            console.log('Remove sticker (placeholder):', stickerId);
            setStickers((prev) => prev.filter((s) => s.id !== stickerId));
          },
        },
      ],
    });
  };

  const handleUnsubscribe = () => {
    presentAlert({
      header: t`Unsubscribe`,
      message: t`Remove this pack from your collection?`,
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: t`Unsubscribe`,
          role: 'destructive',
          handler: () => {
            console.log('Unsubscribe from pack (placeholder):', packId);
          },
        },
      ],
    });
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            {backAction ? <BackButton action={backAction} /> : <IonBackButton defaultHref="/settings/stickers" />}
          </IonButtons>
          <IonTitle>{name}</IonTitle>
          {!owned && (
            <IonButtons slot="end">
              <IonButton color="danger" onClick={handleUnsubscribe}>
                <Trans>Unsubscribe</Trans>
              </IonButton>
            </IonButtons>
          )}
        </IonToolbar>
      </IonHeader>
      <IonContent color="light">
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*,video/webm"
          style={{ display: 'none' }}
          onChange={handleFileChange}
        />
        <div className={styles.grid}>
          {owned && (
            <button
              type="button"
              className={`${styles.cell} ${styles.addCell}`}
              aria-label={t`Add sticker`}
              onClick={() => fileInputRef.current?.click()}
            >
              <span className={styles.addIcon} aria-hidden="true">+</span>
            </button>
          )}
          {stickers.map((sticker) => (
            <button
              key={sticker.id}
              type="button"
              className={styles.cell}
              aria-label={sticker.label}
              onClick={owned ? () => handleRemoveSticker(sticker.id) : undefined}
              style={{ cursor: owned ? 'pointer' : 'default' }}
            >
              <span className={styles.emoji} aria-hidden="true">{sticker.emoji}</span>
              {owned && <span className={styles.removeHint} aria-hidden="true">✕</span>}
            </button>
          ))}
        </div>
      </IonContent>
      <AddStickerModal
        file={addStickerFile}
        onDismiss={() => setAddStickerFile(null)}
        onAdd={handleAddSticker}
      />
    </IonPage>
  );
}

export default function StickerPackDetailPage() {
  const { packId } = useParams<{ packId: string }>();
  return (
    <StickerPackDetailCore
      packId={packId}
      backAction={{ type: 'back', defaultHref: '/settings/stickers' }}
    />
  );
}
