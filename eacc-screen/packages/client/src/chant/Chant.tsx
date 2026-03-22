import { useState, useCallback } from 'react';
import { useStore } from '../stores/store';
import { useAudio } from '../hooks/useAudio';
import { THEMES } from '@eacc/shared';

export function Chant() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];
  const { audioSource, error, playing, ready, toggle, volume, setVolume } = useAudio();
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
        background: `linear-gradient(270deg, ${t.surfaceStrong} 0%, ${t.surfaceSoft} 68%, transparent 100%)`,
        textShadow: `0 0 10px ${t.accentGlow}`,
        borderTop: `1px solid ${t.surfaceBorder}`,
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
      <div style={styles.trackBlock}>
        <span style={styles.track}>{audioSource.label}</span>
        <span style={styles.meta}>
          {error ? error : ready ? audioSource.kind : 'loading'}
        </span>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    fontSize: 11,
    color: 'var(--text-muted)',
    transition: 'opacity 0.4s ease',
    zIndex: 5,
    padding: '12px 24px 12px 32px',
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
    maxWidth: 132,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap' as const,
  },
  trackBlock: {
    display: 'flex',
    flexDirection: 'column',
    gap: 2,
    minWidth: 0,
  },
  meta: {
    fontSize: 9,
    letterSpacing: 0.8,
    color: 'var(--text-muted)',
    maxWidth: 160,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap' as const,
  },
};
