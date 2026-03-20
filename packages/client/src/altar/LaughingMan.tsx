import { useStore } from '../stores/store';
import { THEMES } from '@ritual-screen/shared';

/**
 * Laughing Man logo from Ghost in the Shell: SAC
 * Text ring rotates. Face stays still.
 * Based on the original: circle of text + grinning face with cap visor
 */
export function LaughingMan() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];
  const c = t.fireCore;

  const quote = "I thought what I'd do was, I'd pretend I was one of those deaf-mutes";

  return (
    <div style={styles.container}>
      <svg viewBox="-200 -200 400 400" style={{ width: '100%', height: '100%' }}>
        {/* === ROTATING PART: outer rings + text === */}
        <g style={{ animation: 'laughingManSpin 40s linear infinite', transformOrigin: 'center' }}>
          {/* Outer thick ring */}
          <circle cx="0" cy="0" r="185" fill="none" stroke={c} strokeWidth="8" opacity="0.25" />
          {/* Inner ring border */}
          <circle cx="0" cy="0" r="145" fill="none" stroke={c} strokeWidth="3" opacity="0.2" />

          {/* Text path */}
          <defs>
            <path id="lmTextPath" d="M 0,-165 A 165,165 0 1,1 -0.001,-165" fill="none" />
          </defs>
          <text
            fill={c}
            fontSize="14"
            fontFamily='"Fira Code", monospace'
            fontWeight="700"
            letterSpacing="2"
            opacity="0.45"
          >
            <textPath href="#lmTextPath">
              {quote}
            </textPath>
          </text>
        </g>

        {/* === STATIC PART: the face (does NOT rotate) === */}
        <g opacity="0.2">
          {/* Face outline - large circle */}
          <circle cx="0" cy="5" r="110" fill="none" stroke={c} strokeWidth="3" />

          {/* Cap visor - the iconic bar across the face */}
          <ellipse cx="0" cy="-25" rx="95" ry="12" fill={c} opacity="0.5" />
          {/* Visor outline */}
          <ellipse cx="0" cy="-25" rx="95" ry="12" fill="none" stroke={c} strokeWidth="2" />

          {/* Cap top dome */}
          <path
            d="M -70,-30 C -70,-80 -40,-105 0,-110 C 40,-105 70,-80 70,-30"
            fill="none"
            stroke={c}
            strokeWidth="2.5"
          />

          {/* Eyes - happy squinting arcs */}
          <path
            d="M -40,-5 C -35,-18 -20,-18 -15,-5"
            fill="none" stroke={c} strokeWidth="4" strokeLinecap="round"
          />
          <path
            d="M 15,-5 C 20,-18 35,-18 40,-5"
            fill="none" stroke={c} strokeWidth="4" strokeLinecap="round"
          />

          {/* Big grin - wide smile */}
          <path
            d="M -55,25 C -40,65 40,65 55,25"
            fill="none" stroke={c} strokeWidth="4" strokeLinecap="round"
          />

          {/* Smile line / teeth line */}
          <line x1="-45" y1="35" x2="45" y2="35" stroke={c} strokeWidth="1.5" opacity="0.6" />
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
    width: '55vh',
    height: '55vh',
    maxWidth: '550px',
    maxHeight: '550px',
    pointerEvents: 'none',
    zIndex: 2,
  },
};
