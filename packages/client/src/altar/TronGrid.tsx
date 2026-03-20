import { useStore } from '../stores/store';
import { THEMES } from '@ritual-screen/shared';

/**
 * TRON: Legacy — Glowing perspective grid horizon
 * Receding grid lines creating depth, with glow
 */
export function TronGrid() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];

  const verticalLines = 25;
  const horizontalLines = 12;

  return (
    <div style={styles.container}>
      <svg viewBox="0 0 1000 400" preserveAspectRatio="none" style={styles.svg}>
        <defs>
          <linearGradient id="tronFade" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={t.fireCore} stopOpacity="0" />
            <stop offset="40%" stopColor={t.fireCore} stopOpacity="0.15" />
            <stop offset="100%" stopColor={t.fireCore} stopOpacity="0.4" />
          </linearGradient>
          <filter id="tronGlow">
            <feGaussianBlur stdDeviation="2" result="blur" />
            <feMerge>
              <feMergeNode in="blur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        {/* Horizon line */}
        <line x1="0" y1="160" x2="1000" y2="160" stroke={t.fireCore} strokeWidth="1.5" opacity="0.3" filter="url(#tronGlow)" />

        {/* Vertical perspective lines */}
        {Array.from({ length: verticalLines }, (_, i) => {
          const x = (i / (verticalLines - 1)) * 1000;
          const topX = 500 + (x - 500) * 0.05;
          return (
            <line key={`v${i}`}
              x1={topX} y1="160"
              x2={x} y2="400"
              stroke={t.fireCore}
              strokeWidth={Math.abs(i - Math.floor(verticalLines / 2)) < 3 ? "0.8" : "0.4"}
              opacity="0.2"
            />
          );
        })}

        {/* Horizontal receding lines */}
        {Array.from({ length: horizontalLines }, (_, i) => {
          const progress = (i + 1) / horizontalLines;
          const y = 160 + progress * progress * 240;
          const squeeze = 1 - (1 - progress) * 0.95;
          const x1 = 500 - 500 * squeeze;
          const x2 = 500 + 500 * squeeze;
          return (
            <line key={`h${i}`}
              x1={x1} y1={y}
              x2={x2} y2={y}
              stroke={t.fireCore}
              strokeWidth={progress > 0.7 ? "0.8" : "0.4"}
              opacity={0.1 + progress * 0.15}
            />
          );
        })}

        {/* Center glow on horizon */}
        <circle cx="500" cy="160" r="80" fill={t.fireCore} opacity="0.04" filter="url(#tronGlow)" />

        {/* "Sun" disc on horizon */}
        <circle cx="500" cy="160" r="30" fill="none" stroke={t.fireCore} strokeWidth="1" opacity="0.15" />
        <circle cx="500" cy="160" r="15" fill="none" stroke={t.fireCore} strokeWidth="0.5" opacity="0.1" />
      </svg>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: '45%',
    pointerEvents: 'none',
    zIndex: 1,
    opacity: 0.6,
  },
  svg: {
    width: '100%',
    height: '100%',
  },
};
