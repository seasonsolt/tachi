import { useStore } from '../stores/store';
import { THEMES } from '@eacc/shared';

const PAPER = {
  highlight: '#edf0f2',
  main: '#a3adb8',
  shade: '#59636f',
  deep: '#1a1c23',
};

function facet(points: string, fill: string, opacity = 1) {
  return (
    <polygon
      points={points}
      fill={fill}
      opacity={opacity}
      stroke="rgba(255,255,255,0.1)"
      strokeWidth="1"
      strokeLinejoin="round"
    />
  );
}

/**
 * Origami Unicorn — panel-led amber motif.
 * Cold folded planes with a restrained amber horn glow replace the legacy eye scan.
 */
export function OrigamiUnicorn() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];

  return (
    <div style={styles.container}>
      <svg viewBox="-220 -220 440 440" style={styles.svg}>
        <defs>
          <radialGradient id="unicornAmbient" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor={t.fireCore} stopOpacity="0.16" />
            <stop offset="60%" stopColor={t.fireCore} stopOpacity="0.06" />
            <stop offset="100%" stopColor={t.fireCore} stopOpacity="0" />
          </radialGradient>
          <radialGradient id="hornGlow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor={t.fireCore} stopOpacity="0.72" />
            <stop offset="100%" stopColor={t.fireCore} stopOpacity="0" />
          </radialGradient>
          <linearGradient id="pedestalFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="rgba(38,43,51,0.9)" />
            <stop offset="100%" stopColor="rgba(12,12,15,0.92)" />
          </linearGradient>
        </defs>

        <ellipse cx="-10" cy="138" rx="96" ry="24" fill="rgba(0,0,0,0.18)" filter="blur(8px)" />
        <ellipse cx="-18" cy="32" rx="118" ry="42" fill="url(#unicornAmbient)" filter="blur(16px)" />
        <circle cx="92" cy="-116" r="34" fill="url(#hornGlow)" filter="blur(10px)" />

        <g opacity="0.95">
          <rect x="-98" y="132" width="154" height="18" fill="url(#pedestalFill)" rx="0" />
          <rect x="-54" y="118" width="10" height="16" fill="rgba(255,255,255,0.18)" />
        </g>

        <g opacity="0.9">
          <animateTransform
            attributeName="transform"
            type="rotate"
            values="-2 0 0;2 0 0;-2 0 0"
            dur="20s"
            repeatCount="indefinite"
          />
          <animateTransform
            attributeName="transform"
            additive="sum"
            type="translate"
            values="0 0;0 -5;0 0"
            dur="12s"
            repeatCount="indefinite"
          />

          {facet('-124 28 -164 6 -138 48', PAPER.shade, 0.88)}
          {facet('-112 20 -66 8 -36 52 -80 90 -122 54', PAPER.shade, 0.9)}
          {facet('-70 12 16 -6 88 14 56 60 -6 74 -62 48', PAPER.main, 0.94)}
          {facet('-20 34 16 42 6 104 -34 104 -52 62', PAPER.highlight, 0.94)}
          {facet('-8 18 14 -60 40 18 10 44', PAPER.highlight, 0.9)}
          {facet('12 18 34 -92 72 -90 80 4 42 48 10 40', PAPER.main, 0.96)}
          {facet('62 -90 108 -102 148 -70 130 -18 82 -18 54 -46', PAPER.highlight, 0.96)}
          {facet('110 -96 168 -80 128 -30 86 -36', PAPER.main, 0.92)}
          {facet('74 -90 82 -126 102 -78', PAPER.highlight, 0.94)}
          {facet('88 -118 108 -182 124 -112', t.fireCore, 0.9)}
          {facet('-88 74 -64 60 -70 144 -96 150', PAPER.deep, 0.92)}
          {facet('-42 70 -20 68 -18 144 -46 148', PAPER.shade, 0.92)}
          {facet('2 74 26 72 24 144 -2 148', PAPER.highlight, 0.94)}
          {facet('44 74 68 72 82 152 50 156', PAPER.main, 0.94)}

          <polyline
            points="-70 48 -8 18 14 -60 62 -90 112 -94"
            fill="none"
            stroke="rgba(255,255,255,0.16)"
            strokeWidth="1.5"
            strokeLinejoin="round"
          />
          <polyline
            points="-6 74 38 48 82 -18 126 -34"
            fill="none"
            stroke="rgba(0,0,0,0.18)"
            strokeWidth="1.2"
            strokeLinejoin="round"
          />
        </g>
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
    width: '58vh',
    height: '58vh',
    maxWidth: '580px',
    maxHeight: '580px',
    pointerEvents: 'none',
    zIndex: 2,
  },
  svg: {
    width: '100%',
    height: '100%',
    overflow: 'visible',
  },
};
