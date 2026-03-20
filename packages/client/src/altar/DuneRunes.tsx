import { useStore } from '../stores/store';
import { THEMES } from '@ritual-screen/shared';

/**
 * Dune — Spice rune circles and sandworm silhouette
 * Ancient alien script in concentric circles, slow rotation
 */
export function DuneRunes() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];

  // Pseudo-Fremen/spice rune characters (geometric shapes suggesting alien script)
  const runeRing1 = '◇ ⬡ △ ◯ ⬢ ▽ ◇ ⬡ △ ◯ ⬢ ▽ ◇ ⬡ △ ◯ ⬢ ▽ ◇ ⬡ △ ◯ ⬢ ▽ ';
  const runeRing2 = '⟡ ⊕ ⊗ ⟐ ⊛ ⟡ ⊕ ⊗ ⟐ ⊛ ⟡ ⊕ ⊗ ⟐ ⊛ ⟡ ⊕ ⊗ ⟐ ⊛ ⟡ ⊕ ⊗ ⟐ ⊛ ';

  return (
    <div style={styles.container}>
      <svg viewBox="-200 -200 400 400" style={styles.svg}>
        {/* Outer rune circle - slow clockwise */}
        <defs>
          <path id="runeOuter" d="M 0,-170 A 170,170 0 1,1 -0.001,-170" fill="none" />
          <path id="runeInner" d="M 0,-130 A 130,130 0 1,1 -0.001,-130" fill="none" />
        </defs>

        <g style={{ animation: 'laughingManSpin 90s linear infinite' }}>
          <text fill={t.fireCore} fontSize="12" fontFamily="serif" opacity="0.2" letterSpacing="4">
            <textPath href="#runeOuter">{runeRing1}</textPath>
          </text>
        </g>

        {/* Inner rune circle - slow counter-clockwise */}
        <g style={{ animation: 'vkSpinReverse 70s linear infinite' }}>
          <text fill={t.fireCore} fontSize="10" fontFamily="serif" opacity="0.15" letterSpacing="3">
            <textPath href="#runeInner">{runeRing2}</textPath>
          </text>
        </g>

        {/* Decorative ring */}
        <circle cx="0" cy="0" r="155" fill="none" stroke={t.fireCore} strokeWidth="0.5" opacity="0.1" />
        <circle cx="0" cy="0" r="100" fill="none" stroke={t.fireCore} strokeWidth="0.5" opacity="0.08" />

        {/* Sandworm silhouette - subtle, at bottom */}
        <g opacity="0.07" transform="translate(0, 60)">
          {/* Worm body - undulating curve */}
          <path
            d="M -120,40 C -90,20 -60,35 -30,25 C 0,15 30,30 60,20 C 90,10 110,25 140,30"
            fill="none"
            stroke={t.fireCore}
            strokeWidth="3"
            strokeLinecap="round"
          />
          {/* Mouth segments */}
          <path
            d="M -120,40 C -130,30 -135,20 -120,10 C -110,20 -115,30 -120,40"
            fill="none"
            stroke={t.fireCore}
            strokeWidth="1.5"
          />
          <path
            d="M -120,40 C -130,45 -135,55 -120,60 C -110,50 -115,45 -120,40"
            fill="none"
            stroke={t.fireCore}
            strokeWidth="1.5"
          />
        </g>

        {/* "The spice must flow" - bottom arc */}
        <defs>
          <path id="duneArc" d="M -140,0 A 140,140 0 0,0 140,0" fill="none" />
        </defs>
        <text fill={t.fireCore} fontSize="7" fontFamily='"EB Garamond", serif' opacity="0.12" letterSpacing="3" fontStyle="italic">
          <textPath href="#duneArc" startOffset="15%">
            THE SPICE MUST FLOW · THE SLEEPER HAS AWAKENED
          </textPath>
        </text>

        {/* Cardinal points - small diamonds */}
        {[0, 90, 180, 270].map((angle) => (
          <g key={angle} transform={`rotate(${angle})`}>
            <polygon points="0,-165 3,-160 0,-155 -3,-160" fill={t.fireCore} opacity="0.15" />
          </g>
        ))}
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
  svg: {
    width: '100%',
    height: '100%',
  },
};
