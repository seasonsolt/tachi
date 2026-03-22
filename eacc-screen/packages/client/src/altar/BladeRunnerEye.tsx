import { useStore } from '../stores/store';
import { THEMES } from '@eacc/shared';

/**
 * Blade Runner — Voight-Kampff eye scan rings
 * Concentric scanning circles with crosshair, rotating at different speeds
 */
export function BladeRunnerEye() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];

  return (
    <div style={styles.container}>
      <svg viewBox="-200 -200 400 400" style={styles.svg}>
        {/* Outer scanning ring - slow rotation */}
        <g className="vk-outer" style={{ animation: 'vkSpin 45s linear infinite' }}>
          <circle cx="0" cy="0" r="180" fill="none" stroke={t.fireCore} strokeWidth="0.8" opacity="0.2" />
          <circle cx="0" cy="0" r="175" fill="none" stroke={t.fireCore} strokeWidth="0.3" opacity="0.1" strokeDasharray="2 6" />
          {/* Tick marks */}
          {Array.from({ length: 72 }, (_, i) => (
            <line key={i} x1="0" y1="-180" x2="0" y2={i % 6 === 0 ? "-170" : "-176"}
              stroke={t.fireCore} strokeWidth={i % 6 === 0 ? "1" : "0.3"} opacity="0.2"
              transform={`rotate(${i * 5})`} />
          ))}
        </g>

        {/* Middle ring - opposite rotation */}
        <g style={{ animation: 'vkSpinReverse 30s linear infinite' }}>
          <circle cx="0" cy="0" r="140" fill="none" stroke={t.fireCore} strokeWidth="0.5" opacity="0.15" />
          <circle cx="0" cy="0" r="135" fill="none" stroke={t.fireCore} strokeWidth="0.3" opacity="0.1" strokeDasharray="8 4" />
          {/* Arc segments */}
          {[0, 90, 180, 270].map((a) => (
            <path key={a} d={`M ${130 * Math.cos((a - 20) * Math.PI / 180)} ${130 * Math.sin((a - 20) * Math.PI / 180)} A 130 130 0 0 1 ${130 * Math.cos((a + 20) * Math.PI / 180)} ${130 * Math.sin((a + 20) * Math.PI / 180)}`}
              fill="none" stroke={t.fireCore} strokeWidth="2" opacity="0.15" />
          ))}
        </g>

        {/* Inner iris ring */}
        <g style={{ animation: 'vkSpin 20s linear infinite' }}>
          <circle cx="0" cy="0" r="90" fill="none" stroke={t.fireCore} strokeWidth="1" opacity="0.12" />
          {/* Iris segments */}
          {Array.from({ length: 24 }, (_, i) => {
            const angle = i * 15 * Math.PI / 180;
            const inner = 70;
            const outer = 88;
            return (
              <line key={i}
                x1={inner * Math.cos(angle)} y1={inner * Math.sin(angle)}
                x2={outer * Math.cos(angle)} y2={outer * Math.sin(angle)}
                stroke={t.fireCore} strokeWidth="1" opacity="0.1" />
            );
          })}
        </g>

        {/* Pupil */}
        <circle cx="0" cy="0" r="50" fill="none" stroke={t.fireCore} strokeWidth="0.8" opacity="0.1" />
        <circle cx="0" cy="0" r="8" fill={t.fireCore} opacity="0.06" />

        {/* Crosshair */}
        <line x1="-195" y1="0" x2="-160" y2="0" stroke={t.fireCore} strokeWidth="0.5" opacity="0.15" />
        <line x1="160" y1="0" x2="195" y2="0" stroke={t.fireCore} strokeWidth="0.5" opacity="0.15" />
        <line x1="0" y1="-195" x2="0" y2="-160" stroke={t.fireCore} strokeWidth="0.5" opacity="0.15" />
        <line x1="0" y1="160" x2="0" y2="195" stroke={t.fireCore} strokeWidth="0.5" opacity="0.15" />

        {/* Small data labels */}
        <text x="165" y="-5" fill={t.fireCore} fontSize="6" fontFamily="monospace" opacity="0.15">VK-01</text>
        <text x="-190" y="-5" fill={t.fireCore} fontSize="6" fontFamily="monospace" opacity="0.15">SCAN</text>
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
