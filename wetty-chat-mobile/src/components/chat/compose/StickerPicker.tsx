import { useRef, useState } from 'react';
import { useIonActionSheet, useIonAlert } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { AddStickerModal } from './AddStickerModal';
import styles from './StickerPicker.module.scss';

interface Sticker {
  id: string;
  emoji: string;
  label: string;
}

interface StickerPack {
  id: string;
  name: string;
  icon: string;
  owned: boolean;
  stickers: Sticker[];
}

const INITIAL_PACKS: StickerPack[] = [
  {
    id: 'favorites',
    name: 'Favorites',
    icon: '⭐',
    owned: false,
    stickers: [
      { id: 'fav-1', emoji: '⭐', label: 'Star' },
      { id: 'fav-2', emoji: '❤️', label: 'Heart' },
      { id: 'fav-3', emoji: '🔥', label: 'Fire' },
      { id: 'fav-4', emoji: '💯', label: '100' },
      { id: 'fav-5', emoji: '🎉', label: 'Party' },
      { id: 'fav-6', emoji: '👍', label: 'Thumbs up' },
      { id: 'fav-7', emoji: '😂', label: 'Laughing' },
      { id: 'fav-8', emoji: '🥹', label: 'Holding back tears' },
    ],
  },
  {
    id: 'smileys',
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
      { id: 'sml-11', emoji: '🤔', label: 'Thinking' },
      { id: 'sml-12', emoji: '😏', label: 'Smirking' },
    ],
  },
  {
    id: 'animals',
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
  {
    id: 'food',
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
];

interface StickerPickerProps {
  isOpen: boolean;
  onStickerSelect: (stickerId: string) => void;
}

export function StickerPicker({ isOpen, onStickerSelect }: StickerPickerProps) {
  const [packs, setPacks] = useState<StickerPack[]>(INITIAL_PACKS);
  const [selectedPackId, setSelectedPackId] = useState(INITIAL_PACKS[0].id);
  const [addStickerFile, setAddStickerFile] = useState<File | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [presentAlert] = useIonAlert();
  const [presentActionSheet] = useIonActionSheet();

  if (!isOpen) return null;

  const activePack = packs.find((p) => p.id === selectedPackId) ?? packs[0];

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
            const newPack: StickerPack = {
              id,
              name,
              icon: '📦',
              owned: true,
              stickers: [],
            };
            setPacks((prev) => [...prev, newPack]);
            setSelectedPackId(id);
          },
        },
      ],
    });
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0] ?? null;
    e.target.value = '';
    if (file) setAddStickerFile(file);
  };

  const handleAddSticker = (file: File, emoji: string, name: string) => {
    console.log('Add sticker (placeholder):', { packId: activePack.id, emoji, name, file: file.name });
    const newSticker: Sticker = {
      id: `new-${Date.now()}`,
      emoji,
      label: name || emoji,
    };
    setPacks((prev) =>
      prev.map((p) =>
        p.id === activePack.id ? { ...p, stickers: [...p.stickers, newSticker] } : p,
      ),
    );
    setAddStickerFile(null);
  };

  const handleStickerLongPress = (sticker: Sticker) => {
    if (activePack.id !== 'favorites') return;
    presentActionSheet({
      buttons: [
        {
          text: t`Remove from Favorites`,
          role: 'destructive',
          handler: () => {
            console.log('Remove from favorites (placeholder):', sticker.id);
            setPacks((prev) =>
              prev.map((p) =>
                p.id === 'favorites'
                  ? { ...p, stickers: p.stickers.filter((s) => s.id !== sticker.id) }
                  : p,
              ),
            );
          },
        },
        { text: t`Cancel`, role: 'cancel' },
      ],
    });
  };

  return (
    <div className={styles.container}>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*,video/webm"
        style={{ display: 'none' }}
        onChange={handleFileChange}
      />

      <div className={styles.stickerGrid} role="grid" aria-label={activePack.name}>
        {activePack.owned && (
          <button
            type="button"
            className={`${styles.stickerItem} ${styles.addStickerBtn}`}
            aria-label={t`Add sticker`}
            onClick={() => fileInputRef.current?.click()}
          >
            <span className={styles.addStickerIcon} aria-hidden="true">+</span>
          </button>
        )}
        {activePack.stickers.map((sticker) => (
          <StickerButton
            key={sticker.id}
            sticker={sticker}
            onSelect={onStickerSelect}
            onLongPress={activePack.id === 'favorites' ? handleStickerLongPress : undefined}
          />
        ))}
      </div>

      <div className={styles.packBar} role="tablist" aria-label={t`Sticker packs`}>
        {packs.map((pack) => (
          <button
            key={pack.id}
            type="button"
            role="tab"
            aria-selected={pack.id === selectedPackId}
            aria-label={pack.name}
            className={`${styles.packTab}${pack.id === selectedPackId ? ` ${styles.packTabActive}` : ''}`}
            onClick={() => setSelectedPackId(pack.id)}
          >
            <span className={styles.packIcon} aria-hidden="true">
              {pack.icon}
            </span>
          </button>
        ))}
        <button
          type="button"
          className={`${styles.packTab} ${styles.createPackBtn}`}
          aria-label={t`Create new sticker pack`}
          onClick={handleCreatePack}
        >
          <span className={styles.packIcon} aria-hidden="true">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
              <path d="M10 4a1 1 0 011 1v4h4a1 1 0 110 2h-4v4a1 1 0 11-2 0v-4H5a1 1 0 110-2h4V5a1 1 0 011-1z" />
            </svg>
          </span>
        </button>
      </div>

      <AddStickerModal
        file={addStickerFile}
        onDismiss={() => setAddStickerFile(null)}
        onAdd={handleAddSticker}
      />
    </div>
  );
}

// Separate component to handle long-press cleanly
function StickerButton({
  sticker,
  onSelect,
  onLongPress,
}: {
  sticker: Sticker;
  onSelect: (id: string) => void;
  onLongPress?: (sticker: Sticker) => void;
}) {
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const handleTouchStart = () => {
    if (!onLongPress) return;
    longPressTimer.current = setTimeout(() => {
      onLongPress(sticker);
    }, 500);
  };

  const handleTouchEnd = () => {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  };

  return (
    <button
      type="button"
      role="gridcell"
      aria-label={sticker.label}
      className={styles.stickerItem}
      onClick={() => onSelect(sticker.id)}
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
      onTouchCancel={handleTouchEnd}
      onContextMenu={(e) => {
        e.preventDefault();
        onLongPress?.(sticker);
      }}
    >
      <span className={styles.stickerEmoji} aria-hidden="true">
        {sticker.emoji}
      </span>
    </button>
  );
}
