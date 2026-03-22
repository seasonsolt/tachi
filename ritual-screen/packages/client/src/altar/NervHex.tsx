import { useStore } from '../stores/store';
import { THEMES } from '@ritual-screen/shared';

/**
 * Neon Genesis Evangelion — NERV hexagonal warning pattern
 * Hexagonal grid with warning stripes and NERV-style labels
 */
export function NervHex() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];

  return (
    <div style={styles.container}>
      <svg viewBox="-200 -200 400 400" style={styles.svg}>
        {/* NERV-style concentric hexagons */}
        {[180, 150, 120, 90].map((r, idx) => {
          const points = Array.from({ length: 6 }, (_, i) => {
            const angle = (i * 60 - 30) * Math.PI / 180;
            return `${r * Math.cos(angle)},${r * Math.sin(angle)}`;
          }).join(' ');
          return (
            <polygon key={r}
              points={points}
              fill="none"
              stroke={t.fireCore}
              strokeWidth={idx === 0 ? "1.5" : "0.5"}
              opacity={0.08 + idx * 0.04}
            />
          );
        })}

        {/* Warning stripe segments at top and bottom */}
        <defs>
          <pattern id="nervStripes" width="12" height="12" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
            <rect width="6" height="12" fill={t.fireCore} opacity="0.15" />
          </pattern>
        </defs>
        <rect x="-180" y="-195" width="360" height="8" fill="url(#nervStripes)" opacity="0.5" />
        <rect x="-180" y="187" width="360" height="8" fill="url(#nervStripes)" opacity="0.5" />

        {/* NERV leaf logo (simplified) */}
        <g opacity="0.1" transform="translate(0, 0)">
          {/* Half leaf / fig leaf shape */}
          <path
            d="M 0,-60 C 30,-55 45,-30 45,0 C 45,30 25,55 0,60 C -25,55 -45,30 -45,0 C -45,-30 -30,-55 0,-60 Z"
            fill="none"
            stroke={t.fireCore}
            strokeWidth="2"
          />
          {/* Center vein */}
          <line x1="0" y1="-55" x2="0" y2="55" stroke={t.fireCore} strokeWidth="1.5" />
          {/* Side veins */}
          <line x1="0" y1="-30" x2="30" y2="-10" stroke={t.fireCore} strokeWidth="0.8" />
          <line x1="0" y1="-30" x2="-30" y2="-10" stroke={t.fireCore} strokeWidth="0.8" />
          <line x1="0" y1="0" x2="35" y2="15" stroke={t.fireCore} strokeWidth="0.8" />
          <line x1="0" y1="0" x2="-35" y2="15" stroke={t.fireCore} strokeWidth="0.8" />
          <line x1="0" y1="25" x2="25" y2="40" stroke={t.fireCore} strokeWidth="0.8" />
          <line x1="0" y1="25" x2="-25" y2="40" stroke={t.fireCore} strokeWidth="0.8" />
        </g>

        {/* Corner labels */}
        <text x="-175" y="-175" fill={t.fireCore} fontSize="7" fontFamily="monospace" opacity="0.2">NERV</text>
        <text x="140" y="-175" fill={t.fireCore} fontSize="7" fontFamily="monospace" opacity="0.2">MAGI-01</text>
        <text x="-175" y="185" fill={t.fireCore} fontSize="7" fontFamily="monospace" opacity="0.2">PRIBNOW</text>
        <text x="130" y="185" fill={t.fireCore} fontSize="7" fontFamily="monospace" opacity="0.2">LCL:OK</text>

        {/* "God's in his heaven, all's right with the world" text arc */}
        <defs>
          <path id="nervArc" d="M -160,0 A 160,160 0 0,1 160,0" fill="none" />
        </defs>
        <text fill={t.fireCore} fontSize="6" fontFamily="monospace" opacity="0.12" letterSpacing="2">
          <textPath href="#nervArc" startOffset="10%">
            GOD'S IN HIS HEAVEN · ALL'S RIGHT WITH THE WORLD
          </textPath>
        </text>
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
