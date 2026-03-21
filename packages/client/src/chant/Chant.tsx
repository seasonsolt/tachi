import { useState, useCallback } from 'react';
import { useStore } from '../stores/store';
import { useAudio } from '../hooks/useAudio';
import { THEMES } from '@ritual-screen/shared';

export function Chant() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];
  const { playing, toggle, volume, setVolume } = useAudio();
  const [hovered, setHovered] = useState(false);

  const handleVolumeChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      setVolume(parseFloat(e.target.value));
    },
    [setVolume],
  );

  return (
    <div
      style={{
        ...styles.container,
        fontFamily: t.dataFont,
        opacity: hovered ? 0.96 : 0.78,
        background: `linear-gradient(270deg, ${t.bg}ee 0%, ${t.bg}d0 68%, transparent 100%)`,
        textShadow: `0 0 14px ${t.accentGlow}`,
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <button onClick={toggle} style={styles.playBtn}>
        {playing ? '⏸' : '▶'}
      </button>
      <input
        type="range"
        min={0}
        max={1}
        step={0.01}
        value={volume}
        onChange={handleVolumeChange}
        style={styles.slider}
      />
      <span style={styles.track}>ambient</span>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    bottom: 24,
    right: 24,
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    fontSize: 11,
    color: 'var(--text-muted)',
    transition: 'opacity 0.4s ease',
    zIndex: 5,
    padding: '8px 0 8px 28px',
  },
  playBtn: {
    background: 'none',
    border: 'none',
    color: 'var(--text-secondary)',
    fontSize: 14,
    cursor: 'pointer',
    padding: 12,
    minWidth: 44,
    minHeight: 44,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    lineHeight: 1,
  },
  slider: {
    width: 60,
    height: 44,
    appearance: 'none' as const,
    WebkitAppearance: 'none',
    background: 'transparent',
    outline: 'none',
    cursor: 'pointer',
    borderRadius: 0,
  },
  track: {
    textTransform: 'uppercase' as const,
    letterSpacing: 1,
    fontSize: 9,
    color: 'var(--text-secondary)',
  },
};
