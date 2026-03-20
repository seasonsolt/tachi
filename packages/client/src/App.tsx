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
        <AltarScene />
        <Scripture />
        <Pulse />
        <Chant />
        <button
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
  input[type="range"]::-webkit-slider-thumb {
    -webkit-appearance: none;
    width: 8px;
    height: 8px;
    background: var(--text-secondary);
    border: none;
    cursor: pointer;
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
    top: 16,
    right: 16,
    background: 'none',
    border: 'none',
    color: 'var(--text-muted)',
    fontSize: 20,
    cursor: 'pointer',
    opacity: 0.4,
    zIndex: 10,
    padding: 8,
    transition: 'opacity 0.3s',
  },
};
