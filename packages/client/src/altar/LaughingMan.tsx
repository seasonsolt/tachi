import { useStore } from '../stores/store';
import { THEMES } from '@ritual-screen/shared';

/**
 * Laughing Man — Ghost in the Shell: Stand Alone Complex
 * Faithful recreation: text ring rotates, face is static
 */
export function LaughingMan() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];
  const c = t.fireCore;

  return (
    <div style={styles.container}>
      <svg viewBox="-210 -210 420 420" style={{ width: '100%', height: '100%', overflow: 'visible' }}>

        {/* === ROTATING: text band + outer ring === */}
        <g style={{ animation: 'laughingManSpin 40s linear infinite', transformOrigin: '0 0' }}>
          {/* Thick outer band background */}
          <circle cx="0" cy="0" r="195" fill="none" stroke={c} strokeWidth="35" opacity="0.12" />
          {/* Outer edge */}
          <circle cx="0" cy="0" r="210" fill="none" stroke={c} strokeWidth="2" opacity="0.25" />
          {/* Inner edge of band */}
          <circle cx="0" cy="0" r="178" fill="none" stroke={c} strokeWidth="1.5" opacity="0.25" />

          {/* Circular text */}
          <defs>
            <path id="lmText" d="M 0,-193 A 193,193 0 1,1 -0.001,-193" fill="none" />
          </defs>
          <text
            fill={c}
            fontSize="17"
            fontFamily='"Fira Code", "Courier New", monospace'
            fontWeight="700"
            opacity="0.5"
            letterSpacing="1.5"
          >
            <textPath href="#lmText">
              I thought what I'd do was, I'd pretend I was one of those deaf-mutes
            </textPath>
          </text>
        </g>

        {/* === STATIC: the face === */}
        <g opacity="0.35">
          {/* Head circle */}
          <circle cx="0" cy="10" r="140" fill="none" stroke={c} strokeWidth="4" />

          {/* Cap top - rounded dome */}
          <path
            d="M -90,-40 C -90,-110 -50,-150 0,-155 C 50,-150 90,-110 90,-40"
            fill={c}
            opacity="0.15"
            stroke={c}
            strokeWidth="3"
          />

          {/* Cap brim - THE signature element: thick horizontal bar */}
          <rect x="-125" y="-50" width="250" height="24" rx="12" fill={c} opacity="0.8" />
          {/* Brim outline */}
          <rect x="-125" y="-50" width="250" height="24" rx="12" fill="none" stroke={c} strokeWidth="2.5" />

          {/* Eyes - small happy squinting arcs (the key: they're SMALL) */}
          <path
            d="M -50,-10 C -42,-25 -28,-25 -20,-10"
            fill="none" stroke={c} strokeWidth="5" strokeLinecap="round"
          />
          <path
            d="M 20,-10 C 28,-25 42,-25 50,-10"
            fill="none" stroke={c} strokeWidth="5" strokeLinecap="round"
          />

          {/* THE GRIN - very wide, the most prominent feature */}
          {/* Upper lip line */}
          <path
            d="M -80,30 C -65,90 65,90 80,30"
            fill={c}
            opacity="0.2"
            stroke={c}
            strokeWidth="4.5"
            strokeLinecap="round"
          />
          {/* Mouth opening / teeth line */}
          <path
            d="M -70,45 L 70,45"
            fill="none" stroke={c} strokeWidth="3" opacity="0.6"
          />
          {/* Lower lip */}
          <path
            d="M -60,55 C -35,72 35,72 60,55"
            fill="none" stroke={c} strokeWidth="2.5" opacity="0.5"
          />
        </g>
      </svg>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    top: '45%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
    width: '60vh',
    height: '60vh',
    maxWidth: '600px',
    maxHeight: '600px',
    pointerEvents: 'none',
    zIndex: 2,
  },
};
