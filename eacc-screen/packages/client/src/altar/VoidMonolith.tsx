import { useStore } from '../stores/store';
import { THEMES } from '@eacc/shared';

/**
 * 2001: A Space Odyssey — the monolith eclipsing a star
 * SVG mask subtracts the slab from a circular corona,
 * creating perfect crescent edges. 45-degree projection above.
 */
export function VoidMonolith() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];

  return (
    <div style={styles.container}>
      <svg viewBox="-60 -140 120 280" style={styles.svg}>
        <defs>
          {/* Monolith gradient */}
          <linearGradient id="monolithFace" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="#0a0a0a" />
            <stop offset="35%" stopColor="#0e0e0e" />
            <stop offset="100%" stopColor="#060606" />
          </linearGradient>

          {/* Projection gradient */}
          <linearGradient id="projFade" x1="0" y1="1" x2="0" y2="0">
            <stop offset="0%" stopColor="rgba(0,0,0,0.18)" />
            <stop offset="40%" stopColor="rgba(0,0,0,0.08)" />
            <stop offset="100%" stopColor="rgba(0,0,0,0)" />
          </linearGradient>

          {/* Corona radial gradient — golden, hot center to cool edge */}
          <radialGradient id="coronaFill">
            <stop offset="0%" stopColor="rgba(210,175,80,0.0)" />
            <stop offset="55%" stopColor="rgba(210,175,80,0.0)" />
            <stop offset="70%" stopColor="rgba(210,175,80,0.35)" />
            <stop offset="80%" stopColor="rgba(220,185,90,0.20)" />
            <stop offset="90%" stopColor="rgba(200,165,70,0.08)" />
            <stop offset="100%" stopColor="rgba(190,155,60,0.0)" />
          </radialGradient>

          {/* Eclipse mask: show everything EXCEPT the slab area */}
          <mask id="eclipseMask">
            <rect x="-60" y="-140" width="120" height="280" fill="white" />
            <rect x="-20" y="-100" width="40" height="200" fill="black" />
          </mask>

          {/* Filters */}
          <filter id="projBlur"><feGaussianBlur stdDeviation="2" /></filter>
          <filter id="slabEdge">
            <feDropShadow dx="0" dy="0" stdDeviation="0.8" floodColor="#ffffff" floodOpacity="0.04" />
          </filter>
          <filter id="groundBlur"><feGaussianBlur stdDeviation="4" /></filter>
          <filter id="coronaSoft"><feGaussianBlur stdDeviation="1.5" /></filter>
          <filter id="hazeBlur"><feGaussianBlur stdDeviation="5" /></filter>
          <filter id="diamondGlow"><feGaussianBlur stdDeviation="2" /></filter>
        </defs>

        {/* === ECLIPSE CORONA (masked — slab area cut out) === */}
        <g mask="url(#eclipseMask)">
          {/* Outer haze */}
          <circle cx="0" cy="0" r="48"
            fill="none"
            stroke="rgba(185,150,65,0.15)"
            strokeWidth="14"
            filter="url(#hazeBlur)"
          >
            <animate attributeName="opacity" values="0.5;0.8;0.5" dur="8s" repeatCount="indefinite" />
          </circle>

          {/* Main corona disc — radial gradient with hot ring */}
          <circle cx="0" cy="0" r="38"
            fill="url(#coronaFill)"
          >
            <animate attributeName="opacity" values="0.8;1;0.8" dur="6s" repeatCount="indefinite" />
          </circle>

          {/* Corona ring stroke — crisp golden edge */}
          <circle cx="0" cy="0" r="30"
            fill="none"
            stroke="rgba(215,180,80,0.50)"
            strokeWidth="3"
          >
            <animate attributeName="opacity" values="0.7;1;0.7" dur="6s" repeatCount="indefinite" />
          </circle>

          {/* Softer outer ring */}
          <circle cx="0" cy="0" r="34"
            fill="none"
            stroke="rgba(200,165,70,0.30)"
            strokeWidth="4"
            filter="url(#coronaSoft)"
          >
            <animate attributeName="opacity" values="0.6;0.9;0.6" dur="6s" begin="-2s" repeatCount="indefinite" />
          </circle>

          {/* Inner hot ring — closest to slab edge */}
          <circle cx="0" cy="0" r="26"
            fill="none"
            stroke="rgba(230,200,110,0.40)"
            strokeWidth="2"
          >
            <animate attributeName="opacity" values="0.7;1;0.7" dur="6s" begin="-3s" repeatCount="indefinite" />
          </circle>
        </g>

        {/* Diamond ring flares — NOT masked, sit on top at corona edges */}
        <circle cx="22" cy="-22" r="3"
          fill="rgba(230,195,90,0.80)"
          filter="url(#diamondGlow)"
        >
          <animate attributeName="opacity" values="0.3;1;0.3" dur="6s" repeatCount="indefinite" />
        </circle>
        <circle cx="-24" cy="14" r="2.2"
          fill="rgba(225,190,85,0.55)"
          filter="url(#diamondGlow)"
        >
          <animate attributeName="opacity" values="0.2;0.7;0.2" dur="6s" begin="-2s" repeatCount="indefinite" />
        </circle>

        {/* === 45° PROJECTION === */}
        <polygon
          points="-20,-100 20,-100 12,-132 -12,-132"
          fill="url(#projFade)"
          filter="url(#projBlur)"
        />

        {/* === GROUND SHADOW === */}
        <ellipse cx="0" cy="104" rx="24" ry="4"
          fill="rgba(0,0,0,0.10)"
          filter="url(#groundBlur)"
        />

        {/* === THE SLAB === */}
        <rect x="-20" y="-100" width="40" height="200"
          fill="url(#monolithFace)"
          filter="url(#slabEdge)"
        />
        <line x1="0" y1="-88" x2="0" y2="88"
          stroke="rgba(255,255,255,0.02)"
          strokeWidth="0.8"
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
    overflow: 'visible',
  },
};
