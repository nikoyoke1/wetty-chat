import VoicemailPlayer from 'react-voicemail-player';
import 'react-voicemail-player/dist/react-voicemail-player.css';
import styles from './ChatBubble.module.scss';

interface VoiceMessageBubbleProps {
  src: string;
}

export function VoiceMessageBubble({ src }: VoiceMessageBubbleProps) {
  return (
    <VoicemailPlayer className={styles.voicemailPlayer}>
      {(ref) => <audio ref={ref} src={src} preload="metadata" />}
    </VoicemailPlayer>
  );
}
