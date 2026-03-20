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
        opacity: hovered ? 0.8 : 0.3,
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
  },
  playBtn: {
    background: 'none',
    border: 'none',
    color: 'var(--text-muted)',
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
  },
};
