import { useEffect, useCallback } from 'react';
import { useStore } from './stores/store';
import { useWebSocket } from './hooks/useWebSocket';
import { useApiPolling } from './hooks/useApiPolling';
import { THEMES } from '@eacc/shared';
import { AltarScene } from './altar/AltarScene';
import { Pulse } from './pulse/Pulse';
import { Scripture } from './scripture/Scripture';
import { Chant } from './chant/Chant';
import { Sessions } from './sessions/Sessions';
import { Setup } from './setup/Setup';
import { useAudioController } from './hooks/useAudio';
import { useFocusTimerController } from './hooks/useFocusTimer';
import { FocusTimer } from './focus/FocusTimer';
import { MarketRite } from './market/MarketRite';
import type { ThemeName } from '@eacc/shared';

interface AltarControlProfile {
  marketSigil: string;
  marketLabel: string;
  setupLabel: string;
}

const SETUP_CONTROL_SIGIL = '⚙';

const ALTAR_CONTROL_PROFILES: Record<ThemeName, AltarControlProfile> = {
  cyber: {
    marketSigil: '⌬',
    marketLabel: 'relay',
    setupLabel: 'shell',
  },
  matrix: {
    marketSigil: '∴',
    marketLabel: 'thread',
    setupLabel: 'node',
  },
  amber: {
    marketSigil: '◈',
    marketLabel: 'covenant',
    setupLabel: 'unicorn',
  },
  void: {
    marketSigil: '▮',
    marketLabel: 'archive',
    setupLabel: 'monolith',
  },
};

export function App() {
  const theme = useStore((s) => s.theme);
  const tokenData = useStore((s) => s.tokenData);
  const setupOpen = useStore((s) => s.setupOpen);
  const toggleSetup = useStore((s) => s.toggleSetup);
  const setSetupOpen = useStore((s) => s.setSetupOpen);
  const marketOpen = useStore((s) => s.marketOpen);
  const toggleMarket = useStore((s) => s.toggleMarket);
  const setMarketOpen = useStore((s) => s.setMarketOpen);
  const marketState = useStore((s) => s.marketState);
  const { send } = useWebSocket();
  useApiPolling();
  useAudioController();
  useFocusTimerController();
  const t = THEMES[theme];
  const controlProfile = ALTAR_CONTROL_PROFILES[theme];
  const hasMarketSignals = Boolean(
    marketState && (
      marketState.listings.length > 0
      || marketState.seller
      || marketState.serverMode !== 'standalone'
      || marketState.operatorControlsAvailable
      || marketState.blacklist.length > 0
    )
  );

  // Set color-scheme for light/dark themes
  useEffect(() => {
    document.documentElement.style.colorScheme = t.isLightTheme ? 'light' : 'dark';
  }, [t.isLightTheme]);

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

  const openMarketFromSetup = useCallback(() => {
    setSetupOpen(false);
    setMarketOpen(true);
  }, [setMarketOpen, setSetupOpen]);

  const cssVars = {
    '--bg': t.bg,
    '--surface-strong': t.surfaceStrong,
    '--surface-soft': t.surfaceSoft,
    '--surface-border': t.surfaceBorder,
    '--fire-core': t.fireCore,
    '--fire-edge': t.fireEdge,
    '--particle-color': t.particleColor,
    '--text-primary': t.textPrimary,
    '--text-secondary': t.textSecondary,
    '--text-muted': t.textMuted,
    '--accent-glow': t.accentGlow,
    '--scripture-font': t.scriptureFont,
    '--data-font': t.dataFont,
    '--crt-opacity': t.isLightTheme ? '0.03' : '0.07',
    '--vignette-strength': t.isLightTheme ? 'rgba(0, 0, 0, 0.12)' : 'rgba(0, 0, 0, 0.46)',
    '--ambient-top': t.isLightTheme ? 'rgba(236, 236, 230, 0.88)' : t.surfaceStrong,
    '--ambient-mid': t.isLightTheme ? 'rgba(255, 255, 255, 0.08)' : 'rgba(0, 0, 0, 0.14)',
    '--ambient-bottom': t.isLightTheme ? 'rgba(222, 222, 216, 0.82)' : t.surfaceSoft,
    '--ambient-side': t.isLightTheme ? 'rgba(0, 0, 0, 0.1)' : 'rgba(0, 0, 0, 0.22)',
    '--focus-core': t.isLightTheme ? 'rgba(255, 255, 255, 0.58)' : t.surfaceSoft,
    '--focus-ring': t.isLightTheme ? 'rgba(0, 0, 0, 0.08)' : 'rgba(0, 0, 0, 0.12)',
    '--focus-side-left': t.isLightTheme ? 'rgba(0, 0, 0, 0.12)' : 'rgba(0, 0, 0, 0.3)',
    '--focus-side-right': t.isLightTheme ? 'rgba(0, 0, 0, 0.1)' : 'rgba(0, 0, 0, 0.28)',
  } as React.CSSProperties;

  const controlBackground = t.isLightTheme
    ? 'linear-gradient(180deg, rgba(255,255,255,0.9), rgba(226,226,220,0.78))'
    : `linear-gradient(180deg, ${t.surfaceSoft}, rgba(0,0,0,0.02))`;
  const controlBorder = t.isLightTheme ? 'rgba(0,0,0,0.18)' : t.surfaceBorder;
  const controlBoxShadow = t.isLightTheme
    ? '0 0 0 1px rgba(255,255,255,0.4) inset'
    : 'none';
  const sharedControlButtonStyle = {
    borderColor: controlBorder,
    background: controlBackground,
    boxShadow: controlBoxShadow,
  };
  const setupButtonLeft = hasMarketSignals ? 'calc(50% + 30px)' : '50%';

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
        <div className="ambient-veil" />
        <div className="focus-halo" />
        <AltarScene />
        <Scripture />
        <Sessions />
        <FocusTimer />
        <Pulse />
        <Chant />
        {(hasMarketSignals || marketOpen) && (
          <button
            className="market-btn"
            onClick={(e) => { e.stopPropagation(); toggleMarket(); }}
            style={{
              ...styles.marketButton,
              ...sharedControlButtonStyle,
              opacity: t.isLightTheme ? 0.62 : styles.marketButton.opacity,
            }}
            title="Market Rite"
            aria-label="Open Market Rite"
          >
            <span style={{ ...styles.controlGlyph, color: t.fireCore }}>{controlProfile.marketSigil}</span>
            <span
              style={{
                ...styles.controlLabel,
                color: t.isLightTheme ? t.fireCore : styles.controlLabel.color,
                opacity: t.isLightTheme ? 0.82 : styles.controlLabel.opacity,
              }}
            >
              {controlProfile.marketLabel}
            </span>
          </button>
        )}
        <button
          className="setup-btn"
          onClick={(e) => { e.stopPropagation(); toggleSetup(); }}
          style={{
            ...styles.setupButton,
            ...sharedControlButtonStyle,
            left: setupButtonLeft,
            opacity: t.isLightTheme ? 0.56 : styles.setupButton.opacity,
          }}
          title="Configure"
          aria-label="Open Configure panel"
        >
          <span style={{ ...styles.controlGlyph, color: t.textSecondary }}>{SETUP_CONTROL_SIGIL}</span>
          <span
            style={{
              ...styles.controlLabel,
              color: t.isLightTheme ? t.textSecondary : styles.controlLabel.color,
              opacity: t.isLightTheme ? 0.78 : styles.controlLabel.opacity,
            }}
          >
            {controlProfile.setupLabel}
          </span>
        </button>
        {marketOpen && <MarketRite onClose={toggleMarket} />}
        {setupOpen && <Setup send={send} onClose={toggleSetup} onOpenMarket={openMarketFromSetup} hasMarketSignals={hasMarketSignals} />}
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

  /* CRT scanlines — all themes, reduced for void */
  .crt-scanlines {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 8;
    background: repeating-linear-gradient(
      0deg,
      rgba(0, 0, 0, var(--crt-opacity, 0.07)) 0px,
      rgba(0, 0, 0, var(--crt-opacity, 0.07)) 1px,
      transparent 1px,
      transparent 4px
    );
    mix-blend-mode: multiply;
  }

  /* Film grain noise — animated */
  .film-grain {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 9;
    opacity: 0.035;
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
      transparent 44%,
      var(--vignette-strength, rgba(0, 0, 0, 0.46)) 100%
    );
  }

  .ambient-veil {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 3;
    background:
      linear-gradient(180deg, var(--ambient-top) 0%, var(--ambient-mid) 16%, rgba(0, 0, 0, 0.04) 55%, var(--ambient-bottom) 100%),
      linear-gradient(90deg, var(--ambient-side) 0%, transparent 18%, transparent 82%, var(--ambient-side) 100%);
  }

  @keyframes haloBreathe {
    0%, 100% { opacity: 0.8; transform: scale(1); }
    50% { opacity: 1; transform: scale(1.04); }
  }

  @keyframes eclipseCorona {
    0%, 100% { opacity: 0.7; transform: translate(-50%, -50%) scale(1); }
    50% { opacity: 1; transform: translate(-50%, -50%) scale(1.06); }
  }

  @keyframes eclipseRays {
    0%, 100% { opacity: 0.5; transform: translate(-50%, -50%) scale(1); }
    33% { opacity: 0.8; transform: translate(-50%, -50%) scale(1.08); }
    66% { opacity: 0.6; transform: translate(-50%, -50%) scale(0.96); }
  }

  @keyframes eclipseDiamond {
    0%, 100% { opacity: 0.4; transform: translateX(-50%) scale(0.8); }
    40% { opacity: 1; transform: translateX(-50%) scale(1.2); }
    70% { opacity: 0.6; transform: translateX(-50%) scale(1); }
  }

  .focus-halo {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 4;
    background:
      radial-gradient(circle at 50% 44%, var(--focus-core) 0%, var(--focus-ring) 20%, transparent 42%),
      radial-gradient(circle at 15% 85%, var(--focus-side-left) 0%, transparent 30%),
      radial-gradient(circle at 85% 85%, var(--focus-side-right) 0%, transparent 28%);
    animation: haloBreathe 8s ease-in-out infinite;
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
  .market-btn:hover {
    opacity: 0.8 !important;
  }
  .market-btn:hover, .setup-btn:hover {
    transform: translateX(-50%) translateY(-2px);
  }

  /* Focus visible for keyboard accessibility */
  button:focus-visible, input:focus-visible, textarea:focus-visible {
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
    isolation: 'isolate',
  },
  setupButton: {
    position: 'absolute',
    bottom: 12,
    transform: 'translateX(-50%)',
    appearance: 'none',
    borderWidth: 1,
    borderStyle: 'solid',
    cursor: 'pointer',
    opacity: 0.4,
    zIndex: 10,
    padding: '6px 10px',
    minWidth: 56,
    minHeight: 44,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    transition: 'opacity 0.3s, transform 0.3s, box-shadow 0.3s',
    gap: 2,
    borderRadius: 0,
  },
  marketButton: {
    position: 'absolute',
    bottom: 12,
    left: 'calc(50% - 30px)',
    transform: 'translateX(-50%)',
    appearance: 'none',
    borderWidth: 1,
    borderStyle: 'solid',
    cursor: 'pointer',
    opacity: 0.48,
    zIndex: 10,
    padding: '6px 10px',
    minWidth: 56,
    minHeight: 44,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    transition: 'opacity 0.3s, transform 0.3s, box-shadow 0.3s',
    gap: 2,
    borderRadius: 0,
  },
  controlGlyph: {
    fontSize: 15,
    lineHeight: 1,
  },
  controlLabel: {
    fontSize: 8,
    letterSpacing: '0.22em',
    textTransform: 'uppercase',
    color: 'var(--text-secondary)',
    lineHeight: 1,
    opacity: 0.72,
  },
};
