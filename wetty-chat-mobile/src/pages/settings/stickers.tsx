import { useState } from 'react';
import {
  IonBackButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonItem,
  IonLabel,
  IonList,
  IonListHeader,
  IonNote,
  IonPage,
  IonTitle,
  IonToolbar,
  useIonAlert,
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { addOutline, cubeOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { BackButton } from '@/components/BackButton';
import type { BackAction } from '@/types/back-action';

interface MockStickerPack {
  id: string;
  name: string;
  icon: string;
  stickerCount: number;
  owned: boolean;
}

const MOCK_OWNED_PACKS: MockStickerPack[] = [
  { id: 'smileys', name: 'Smileys', icon: '😀', stickerCount: 12, owned: true },
];

const MOCK_SUBSCRIBED_PACKS: MockStickerPack[] = [
  { id: 'animals', name: 'Animals', icon: '🐶', stickerCount: 10, owned: false },
  { id: 'food', name: 'Food', icon: '🍕', stickerCount: 8, owned: false },
];

interface StickerSettingsCoreProps {
  backAction?: BackAction;
  onOpenPack?: (packId: string) => void;
}

export function StickerSettingsCore({ backAction, onOpenPack }: StickerSettingsCoreProps) {
  const history = useHistory();
  const [presentAlert] = useIonAlert();
  const [ownedPacks, setOwnedPacks] = useState(MOCK_OWNED_PACKS);

  const handleOpenPack = (packId: string) => {
    if (onOpenPack) {
      onOpenPack(packId);
      return;
    }
    history.push(`/settings/stickers/${packId}`);
  };

  const handleCreatePack = () => {
    presentAlert({
      header: t`New Sticker Pack`,
      inputs: [{ name: 'name', type: 'text', placeholder: t`Pack name` }],
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: t`Create`,
          handler: (data: { name: string }) => {
            const name = data.name.trim();
            if (!name) return false;
            const id = `pack-${Date.now()}`;
            console.log('Create sticker pack (placeholder):', name);
            setOwnedPacks((prev) => [
              ...prev,
              { id, name, icon: '📦', stickerCount: 0, owned: true },
            ]);
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
            {backAction ? <BackButton action={backAction} /> : <IonBackButton defaultHref="/settings" />}
          </IonButtons>
          <IonTitle>
            <Trans>Stickers</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light" className="ion-no-padding">
        <IonListHeader>
          <IonLabel>
            <Trans>My Packs</Trans>
          </IonLabel>
        </IonListHeader>
        <IonList inset>
          {ownedPacks.map((pack) => (
            <IonItem key={pack.id} button detail onClick={() => handleOpenPack(pack.id)}>
              <span slot="start" style={{ fontSize: 26, width: 32, textAlign: 'center' }}>
                {pack.icon}
              </span>
              <IonLabel>{pack.name}</IonLabel>
              <IonNote slot="end" color="medium">
                {pack.stickerCount}
              </IonNote>
            </IonItem>
          ))}
          <IonItem button detail={false} onClick={handleCreatePack}>
            <IonIcon aria-hidden="true" icon={addOutline} slot="start" color="primary" />
            <IonLabel color="primary">
              <Trans>Create New Pack</Trans>
            </IonLabel>
          </IonItem>
        </IonList>

        <IonListHeader>
          <IonLabel>
            <Trans>Subscribed Packs</Trans>
          </IonLabel>
        </IonListHeader>
        <IonList inset>
          {MOCK_SUBSCRIBED_PACKS.length === 0 ? (
            <IonItem>
              <IonIcon aria-hidden="true" icon={cubeOutline} slot="start" color="medium" />
              <IonLabel color="medium">
                <Trans>No subscribed packs</Trans>
              </IonLabel>
            </IonItem>
          ) : (
            MOCK_SUBSCRIBED_PACKS.map((pack) => (
              <IonItem key={pack.id} button detail onClick={() => handleOpenPack(pack.id)}>
                <span slot="start" style={{ fontSize: 26, width: 32, textAlign: 'center' }}>
                  {pack.icon}
                </span>
                <IonLabel>{pack.name}</IonLabel>
                <IonNote slot="end" color="medium">
                  {pack.stickerCount}
                </IonNote>
              </IonItem>
            ))
          )}
        </IonList>
      </IonContent>
    </IonPage>
  );
}

export default function StickerSettingsPage() {
  return <StickerSettingsCore />;
}
