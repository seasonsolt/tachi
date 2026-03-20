import { useEffect, useCallback } from 'react';
import { useStore } from './stores/store';
import { useWebSocket } from './hooks/useWebSocket';
import { THEMES } from '@ritual-screen/shared';
import { AltarScene } from './altar/AltarScene';
import { Pulse } from './pulse/Pulse';
import { Scripture } from './scripture/Scripture';
import { Chant } from './chant/Chant';
import { Setup } from './setup/Setup';

export function App() {
  const theme = useStore((s) => s.theme);
  const tokenData = useStore((s) => s.tokenData);
  const setupOpen = useStore((s) => s.setupOpen);
  const toggleSetup = useStore((s) => s.toggleSetup);
  const { send } = useWebSocket();
  const t = THEMES[theme];

  useEffect(() => {
    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault();
      e.returnValue = 'Your offering has been received.';
    };
    window.addEventListener('beforeunload', handler);
    return () => window.removeEventListener('beforeunload', handler);
  }, []);

  const handleFirstClick = useCallback(() => {
    if (!tokenData && !setupOpen) {
      toggleSetup();
    }
  }, [tokenData, setupOpen, toggleSetup]);

  const cssVars = {
    '--bg': t.bg,
    '--fire-core': t.fireCore,
    '--fire-edge': t.fireEdge,
    '--particle-color': t.particleColor,
    '--text-primary': t.textPrimary,
    '--text-secondary': t.textSecondary,
    '--text-muted': t.textMuted,
    '--accent-glow': t.accentGlow,
    '--scripture-font': t.scriptureFont,
    '--data-font': t.dataFont,
  } as React.CSSProperties;

  return (
    <div style={{ ...cssVars, ...styles.root }} onClick={handleFirstClick}>
      <style>{globalStyles}</style>
      <div className="mobile-block" style={styles.mobileBlock}>
        <p style={{ fontFamily: t.scriptureFont, fontSize: 20 }}>
          Please use a computer.
        </p>
        <p style={{ fontFamily: t.dataFont, fontSize: 12, marginTop: 16, opacity: 0.5 }}>
          The altar requires a wider viewport.
        </p>
      </div>
      <div className="desktop-container" style={styles.desktopContainer}>
        <div className="crt-scanlines" />
        <div className="film-grain" />
        <div className="vignette" />
        <AltarScene />
        <Scripture />
        <Pulse />
        <Chant />
        <button
          className="setup-btn"
          onClick={(e) => { e.stopPropagation(); toggleSetup(); }}
          style={styles.setupButton}
          title="Configure"
        >
          ⚙
        </button>
        {setupOpen && <Setup send={send} onClose={toggleSetup} />}
      </div>
    </div>
  );
}

const globalStyles = `
  @media (max-width: 767px) {
    .desktop-container { display: none !important; }
    .mobile-block { display: flex !important; }
  }
  @media (min-width: 768px) {
    .desktop-container { display: block !important; }
    .mobile-block { display: none !important; }
  }

  @keyframes slideIn {
    from { transform: translateX(100%); }
    to { transform: translateX(0); }
  }

  /* CRT scanlines — all themes */
  .crt-scanlines {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 8;
    background: repeating-linear-gradient(
      0deg,
      rgba(0, 0, 0, 0.12) 0px,
      rgba(0, 0, 0, 0.12) 1px,
      transparent 1px,
      transparent 3px
    );
    mix-blend-mode: multiply;
  }

  /* Film grain noise — animated */
  .film-grain {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 9;
    opacity: 0.06;
    animation: grainShift 0.3s steps(4) infinite;
  }
  .film-grain::before {
    content: '';
    position: absolute;
    inset: -50%;
    width: 200%;
    height: 200%;
    background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='1'/%3E%3C/svg%3E");
    background-size: 256px 256px;
  }

  @keyframes grainShift {
    0% { transform: translate(0, 0); }
    25% { transform: translate(-2%, -3%); }
    50% { transform: translate(1%, 2%); }
    75% { transform: translate(-1%, 1%); }
    100% { transform: translate(2%, -2%); }
  }

  /* Vignette — subtle darkened edges */
  .vignette {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 7;
    background: radial-gradient(
      ellipse at center,
      transparent 50%,
      rgba(0, 0, 0, 0.4) 100%
    );
  }

  @keyframes laughingManSpin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  @keyframes vkSpin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  @keyframes vkSpinReverse {
    from { transform: rotate(0deg); }
    to { transform: rotate(-360deg); }
  }

  @keyframes milestoneGlow {
    0%, 100% { opacity: 0.9; }
    50% { opacity: 0.5; }
  }

  @keyframes particleRise {
    0% {
      transform: translateY(0) translateX(0);
      opacity: 0;
    }
    10% {
      opacity: 0.8;
    }
    50% {
      opacity: 0.6;
    }
    100% {
      transform: translateY(-60vh) translateX(var(--drift, 0px));
      opacity: 0;
    }
  }

  .setup-btn:hover {
    opacity: 0.8 !important;
  }

  /* Focus visible for keyboard accessibility */
  button:focus-visible, input:focus-visible {
    outline: 2px solid var(--fire-core);
    outline-offset: 2px;
  }

  /* Reduced motion preference */
  @media (prefers-reduced-motion: reduce) {
    .fire-particle, * {
      animation-duration: 0.01ms !important;
      animation-iteration-count: 1 !important;
      transition-duration: 0.01ms !important;
    }
  }

  /* Range slider styling */
  input[type="range"] {
    -webkit-appearance: none;
    appearance: none;
    height: 2px;
    background: var(--text-muted);
    outline: none;
    border-radius: 0;
  }
  input[type="range"]::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: 8px;
    height: 8px;
    background: var(--text-secondary);
    border: none;
    cursor: pointer;
    border-radius: 0;
  }
  input[type="range"]::-moz-range-thumb {
    width: 8px;
    height: 8px;
    background: var(--text-secondary);
    border: none;
    cursor: pointer;
    border-radius: 0;
  }

  /* Number transition helper */
  .pulse-value {
    transition: opacity 0.3s ease;
  }
`;

const styles: Record<string, React.CSSProperties> = {
  root: {
    width: '100%',
    height: '100%',
    background: 'var(--bg)',
    color: 'var(--text-primary)',
    position: 'relative',
    overflow: 'hidden',
    transition: 'background 1s ease',
  },
  mobileBlock: {
    display: 'none',
    width: '100%',
    height: '100%',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    textAlign: 'center',
    padding: 32,
  },
  desktopContainer: {
    width: '100%',
    height: '100%',
    position: 'relative',
  },
  setupButton: {
    position: 'absolute',
    top: 8,
    right: 8,
    background: 'none',
    border: 'none',
    color: 'var(--text-muted)',
    fontSize: 20,
    cursor: 'pointer',
    opacity: 0.4,
    zIndex: 10,
    padding: 12,
    minWidth: 44,
    minHeight: 44,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    transition: 'opacity 0.3s',
  },
};
