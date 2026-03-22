import { useStore } from '../stores/store';
import { THEMES } from '@eacc/shared';

/**
 * 2001: A Space Odyssey — the monolith
 * A tall, thin black rectangle with subtle shadow
 */
export function VoidMonolith() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];

  return (
    <div style={styles.container}>
      <svg viewBox="-60 -120 120 240" style={styles.svg}>
        <defs>
          <filter id="monolithShadow">
            <feDropShadow dx="0" dy="0" stdDeviation="6" floodColor={t.fireCore} floodOpacity="0.15" />
          </filter>
        </defs>
        <rect
          x="-20"
          y="-100"
          width="40"
          height="200"
          fill="#0a0a0a"
          filter="url(#monolithShadow)"
        />
      </svg>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    top: '40%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
    width: '55vh',
    height: '55vh',
    maxWidth: '550px',
    maxHeight: '550px',
    pointerEvents: 'none',
    zIndex: 2,
  },
  svg: {
    width: '100%',
    height: '100%',
  },
};
