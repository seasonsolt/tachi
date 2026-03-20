import { useStore } from '../stores/store';
import { THEMES } from '@ritual-screen/shared';

/**
 * Laughing Man — Ghost in the Shell: Stand Alone Complex
 * Based on the 1KB vector SVG by Johan Sundström
 * https://gist.github.com/johan/1066590
 *
 * Very subtle watermark — felt more than seen.
 * Text ring rotates, face stays still.
 */
export function LaughingMan() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];
  const c = t.fireCore;
  const bg = t.bg;

  return (
    <div style={styles.container}>
      <svg viewBox="-170 -170 340 340" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <path id="lm-text-path" d="m123,0a123,123 0,0 1-246,0a123,123 0,0 1 246,0" />
        </defs>

        {/* === ROTATING: outer ring + text — barely visible === */}
        <g style={{ animation: 'laughingManSpin 50s linear infinite', transformOrigin: '0 0' }}>
          <circle r="160" fill={c} opacity="0.06" />
          <circle r="150" fill={bg} />
          <text
            fill={c}
            fontSize="28"
            fontStretch="condensed"
            fontFamily="Impact, 'Arial Narrow', sans-serif"
            opacity="0.18"
          >
            <textPath href="#lm-text-path">
              I thought what I'd do was, I'd pretend I was one of those deaf-mutes
            </textPath>
          </text>
        </g>

        {/* === STATIC: the face — ghost-like === */}
        <g fill={c} opacity="0.08">
          <circle r="115" />
          <circle r="95" fill={bg} />
          <path d="m-8-119h16 l2,5h-20z" />
          <circle cx="160" cy="0" r="40" />
          <path d="m-95-20v-20h255a40,40 0,0 1 0,80h-55v-20z" />
          <path d="m-85 0a85,85 0,0 0 170,0h-20a65,65 0,0 1-130,0z" />
          <path d="m-65 20v20h140v-20z" />
          <path d="m-115-20v10h25v30h250a20,20 0,0 0 0,-40z" fill={bg} opacity="0.7" />
          <path d="m-20 10c-17-14-27-14-44 0 6-25 37-25 44 0z" />
          <path d="m60 10c-17-14-27-14-44 0 6-25 37-25 44 0z" />
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
    width: '65vh',
    height: '65vh',
    maxWidth: '650px',
    maxHeight: '650px',
    pointerEvents: 'none',
    zIndex: 2,
  },
};
