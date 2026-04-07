import { useCallback, useEffect, useState } from 'react';
import {
  IonBackButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonItem,
  IonLabel,
  IonList,
  IonPage,
  IonTitle,
  IonToggle,
  IonToolbar,
  useIonAlert,
  useIonToast,
  IonBadge,
  IonReorder,
  IonReorderGroup,
  type ItemReorderEventDetail,
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { addOutline, cubeOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { BackButton } from '@/components/BackButton';
import { StickerImage } from '@/components/shared/StickerImage';
import {
  createStickerPack,
  getOwnedStickerPacks,
  getSubscribedStickerPacks,
  type StickerPackSummary,
} from '@/api/stickers';
import { kvGet, kvSet } from '@/utils/db';
import { usersApi, type StickerPackOrderItem } from '@/api/users';
import type { BackAction } from '@/types/back-action';

interface StickerSettingsCoreProps {
  backAction?: BackAction;
  onOpenPack?: (packId: string) => void;
}

export function StickerSettingsCore({ backAction, onOpenPack }: StickerSettingsCoreProps) {
  const history = useHistory();
  const [presentAlert] = useIonAlert();
  const [presentToast] = useIonToast();
  const [ownedPacks, setOwnedPacks] = useState<StickerPackSummary[]>([]);
  const [allPacks, setAllPacks] = useState<StickerPackSummary[]>([]);
  const [autoSort, setAutoSort] = useState<boolean>(false);
  const [packOrder, setPackOrder] = useState<StickerPackOrderItem[]>([]);
  const [initialized, setInitialized] = useState(false);

  useEffect(() => {
    const initStorage = async () => {
      try {
        const storedAutoSort = await kvGet<boolean>('autoSortStickerPacks');
        setAutoSort(storedAutoSort ?? false);

        const storedOrderRaw = await kvGet<any[]>('stickerPackOrder');
        let storedOrder = storedOrderRaw ?? [];
        if (storedOrder.length > 0 && typeof storedOrder[0] === 'string') {
          storedOrder = storedOrder.map((id) => ({ stickerPackId: id, lastUsedOn: 0 }));
          void kvSet('stickerPackOrder', storedOrder);
        }
        setPackOrder(storedOrder);
      } catch (error) {
        console.error('Failed to init sticker storage', error);
      } finally {
        setInitialized(true);
      }
    };
    void initStorage();

    const handleOrderChange = async () => {
      try {
        const _orderRaw = await kvGet<any[]>('stickerPackOrder');
        let order = _orderRaw ?? [];
        if (order.length > 0 && typeof order[0] === 'string') {
          order = order.map((id) => ({ stickerPackId: id, lastUsedOn: 0 }));
        }
        setPackOrder(order);
        setAllPacks((prev) => {
          const copy = [...prev];
          if (order.length > 0) {
            copy.sort((a, b) => {
              const itemA = order.find((o: StickerPackOrderItem) => o.stickerPackId === a.id);
              const itemB = order.find((o: StickerPackOrderItem) => o.stickerPackId === b.id);
              const timeA = itemA ? itemA.lastUsedOn : 0;
              const timeB = itemB ? itemB.lastUsedOn : 0;
              return timeB - timeA;
            });
          }
          return copy;
        });
      } catch (e) {
        console.error('Failed to handle order change', e);
      }
    };

    window.addEventListener('stickerPackOrderChanged', handleOrderChange);
    return () => {
      window.removeEventListener('stickerPackOrderChanged', handleOrderChange);
    };
  }, []);

  const loadPacks = useCallback(async () => {
    try {
      const [ownedRes, subscribedRes, currentOrder] = await Promise.all([
        getOwnedStickerPacks(),
        getSubscribedStickerPacks(),
        kvGet<any[]>('stickerPackOrder'),
      ]);
      setOwnedPacks(ownedRes.data.packs);
      const subs = subscribedRes.data.packs.filter(
        (pack) => !ownedRes.data.packs.some((ownedPack) => ownedPack.id === pack.id),
      );

      const merged = [...ownedRes.data.packs, ...subs];
      let order = currentOrder ?? [];
      if (order.length > 0 && typeof order[0] === 'string') {
        const now = Date.now();
        order = order.map((id, index) => ({ stickerPackId: id, lastUsedOn: now - index * 60000 }));
        void kvSet('stickerPackOrder', order);
        void usersApi.updateStickerPackOrder(order).catch(console.error);
      }

      // Assure everything rendered gets an initial lastUsedOn spacing to prevent zero-tie issues
      const unassigned = merged.filter((pack) => !order.some((o: StickerPackOrderItem) => o.stickerPackId === pack.id));
      if (unassigned.length > 0) {
        const now = Date.now();
        const base = order.length > 0 ? Math.min(...order.map((o: StickerPackOrderItem) => o.lastUsedOn)) - 60000 : now;
        const newOrderItems = unassigned.map((pack, i) => ({
          stickerPackId: pack.id,
          lastUsedOn: base - i * 60000,
        }));
        order = [...order, ...newOrderItems];
        void kvSet('stickerPackOrder', order);
        void usersApi.updateStickerPackOrder(newOrderItems).catch(console.error);
      }

      if (order.length > 0) {
        merged.sort((a, b) => {
          const itemA = order.find((o: StickerPackOrderItem) => o.stickerPackId === a.id);
          const itemB = order.find((o: StickerPackOrderItem) => o.stickerPackId === b.id);
          const timeA = itemA ? itemA.lastUsedOn : 0;
          const timeB = itemB ? itemB.lastUsedOn : 0;
          return timeB - timeA;
        });
      }

      setAllPacks(merged);
      setPackOrder(order);
    } catch (error) {
      console.error('Failed to load sticker packs', error);
      presentToast({ message: t`Failed to load sticker packs`, duration: 2000, position: 'bottom' });
    }
  }, [presentToast]);

  useEffect(() => {
    if (!initialized) return;
    const run = async () => {
      await loadPacks();
    };

    void run();
  }, [loadPacks, initialized]);

  const handleReorder = (event: CustomEvent<ItemReorderEventDetail>) => {
    const toIndex = event.detail.to;
    const newItems = event.detail.complete(allPacks);
    setAllPacks(newItems);

    const movedPack = newItems[toIndex];
    const prevPack = toIndex > 0 ? newItems[toIndex - 1] : null;
    const nextPack = toIndex < newItems.length - 1 ? newItems[toIndex + 1] : null;

    let newLastUsedOn = Date.now();
    if (prevPack && nextPack) {
      const pLast = packOrder.find((o) => o.stickerPackId === prevPack.id)?.lastUsedOn ?? 0;
      const nLast = packOrder.find((o) => o.stickerPackId === nextPack.id)?.lastUsedOn ?? 0;
      if (pLast === nLast) {
        newLastUsedOn = pLast - 10000;
      } else {
        newLastUsedOn = Math.floor((pLast + nLast) / 2);
      }
    } else if (prevPack) {
      const pLast = packOrder.find((o) => o.stickerPackId === prevPack.id)?.lastUsedOn ?? 0;
      newLastUsedOn = pLast - 10000;
    } else if (nextPack) {
      const nLast = packOrder.find((o) => o.stickerPackId === nextPack.id)?.lastUsedOn ?? 0;
      newLastUsedOn = nLast + 10000;
    }

    const updatedItem = { stickerPackId: movedPack.id, lastUsedOn: newLastUsedOn };
    const newOrderObjects = packOrder.map((o) => (o.stickerPackId === updatedItem.stickerPackId ? updatedItem : o));
    if (!newOrderObjects.some((o) => o.stickerPackId === updatedItem.stickerPackId)) {
      newOrderObjects.push(updatedItem);
    }

    setPackOrder(newOrderObjects);
    void kvSet('stickerPackOrder', newOrderObjects);
    void usersApi
      .updateStickerPackOrder([updatedItem])
      .catch((e) => console.error('Failed to sync sticker pack order', e));
    window.dispatchEvent(new Event('stickerPackOrderChanged'));
  };

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
          handler: async (data: { name: string }) => {
            const name = data.name.trim();
            if (!name) return false;
            try {
              const res = await createStickerPack({ name });
              setOwnedPacks((prev) => [res.data, ...prev]);
              setAllPacks((prev) => [res.data, ...prev]);
              const newItem = { stickerPackId: res.data.id, lastUsedOn: Date.now() };
              const newOrderObjects = [newItem, ...packOrder];
              setPackOrder(newOrderObjects);
              void kvSet('stickerPackOrder', newOrderObjects);

              handleOpenPack(res.data.id);
            } catch (error) {
              console.error('Failed to create sticker pack', error);
              presentToast({ message: t`Failed to create sticker pack`, duration: 2000, position: 'bottom' });
            }
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
            {backAction ? <BackButton action={backAction} /> : <IonBackButton text={t`Back`} defaultHref="/settings" />}
          </IonButtons>
          <IonTitle>
            <Trans>Stickers</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light" className="ion-no-padding">
        <IonList inset>
          <IonItem lines="none">
            <IonLabel>
              <Trans>Auto-sort packs by recent use</Trans>
            </IonLabel>
            <IonToggle
              slot="end"
              checked={autoSort}
              onIonChange={(e) => {
                const val = e.detail.checked;
                setAutoSort(val);
                void kvSet('autoSortStickerPacks', val);
              }}
            />
          </IonItem>
        </IonList>

        <IonList inset>
          <IonItem button detail={false} onClick={handleCreatePack}>
            <IonIcon aria-hidden="true" icon={addOutline} slot="start" color="primary" />
            <IonLabel color="primary">
              <Trans>Create New Pack</Trans>
            </IonLabel>
          </IonItem>

          <IonReorderGroup disabled={false} onIonItemReorder={handleReorder}>
            {allPacks.map((pack) => {
              const isOwned = ownedPacks.some((p) => p.id === pack.id);
              return (
                <IonItem key={pack.id} button detail={false} onClick={() => handleOpenPack(pack.id)}>
                  <span
                    slot="start"
                    style={{ width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                  >
                    {pack.previewSticker ? (
                      <StickerImage
                        src={pack.previewSticker.media.url}
                        alt=""
                        style={{ width: '100%', height: '100%', objectFit: 'contain', borderRadius: 4 }}
                      />
                    ) : (
                      <IonIcon aria-hidden="true" icon={cubeOutline} color="medium" style={{ fontSize: 24 }} />
                    )}
                  </span>
                  <IonLabel>
                    <h2 style={{ display: 'flex', alignItems: 'center' }}>
                      {isOwned && (
                        <IonBadge
                          color="primary"
                          style={{ marginRight: 8, fontSize: '0.55rem', fontWeight: 'normal', flexShrink: 0 }}
                        >
                          <Trans>Owned</Trans>
                        </IonBadge>
                      )}
                      <span style={{ textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
                        {pack.name}
                      </span>
                    </h2>
                    <p style={{ fontSize: '0.85em', color: 'var(--ion-color-medium)', marginTop: 2 }}>
                      {pack.stickerCount} <Trans>stickers</Trans>
                    </p>
                  </IonLabel>
                  <IonReorder slot="end" onClick={(e) => e.stopPropagation()} />
                </IonItem>
              );
            })}
          </IonReorderGroup>
        </IonList>
      </IonContent>
    </IonPage>
  );
}

export default function StickerSettingsPage() {
  return <StickerSettingsCore />;
}
