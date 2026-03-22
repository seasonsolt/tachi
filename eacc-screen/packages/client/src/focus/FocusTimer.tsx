import { useStore } from '../stores/store';
import { useFocusTimer } from '../hooks/useFocusTimer';
import { THEMES } from '@eacc/shared';

export function FocusTimer() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];
  const {
    durationMinutes,
    remainingLabel,
    running,
    completedAt,
    start,
    pause,
    reset,
  } = useFocusTimer();

  const status = completedAt
    ? 'complete'
    : running
      ? 'live'
      : 'ready';

  return (
    <div
      style={{
        ...styles.container,
        fontFamily: t.dataFont,
        background: `linear-gradient(270deg, ${t.surfaceStrong} 0%, ${t.surfaceSoft} 68%, transparent 100%)`,
        borderBottom: `1px solid ${t.surfaceBorder}`,
        textShadow: `0 0 10px ${t.accentGlow}`,
      }}
    >
      <div style={styles.header}>
        <span style={styles.label}>focus</span>
        <span style={styles.status}>{status}</span>
      </div>
      <div style={styles.time}>{remainingLabel}</div>
      <div style={styles.meta}>{durationMinutes} min ritual</div>
      <div style={styles.actions}>
        <button
          type="button"
          onClick={running ? pause : start}
          style={{ ...styles.button, color: 'var(--text-secondary)', borderColor: t.surfaceBorder }}
        >
          {running ? 'Pause' : 'Start'}
        </button>
        <button
          type="button"
          onClick={reset}
          style={{ ...styles.button, color: 'var(--text-muted)', borderColor: t.surfaceBorder }}
        >
          Reset
        </button>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    top: 56,
    right: 0,
    minWidth: 184,
    padding: '12px 24px 14px 28px',
    zIndex: 6,
    display: 'flex',
    flexDirection: 'column',
    gap: 6,
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  label: {
    color: 'var(--text-muted)',
    fontSize: 10,
    textTransform: 'uppercase' as const,
    letterSpacing: 1,
  },
  status: {
    color: 'var(--text-secondary)',
    fontSize: 9,
    textTransform: 'uppercase' as const,
    letterSpacing: 1,
  },
  time: {
    color: 'var(--text-primary)',
    fontSize: 28,
    lineHeight: 1,
    fontVariantNumeric: 'tabular-nums',
    letterSpacing: '-0.03em',
  },
  meta: {
    color: 'var(--text-muted)',
    fontSize: 10,
    letterSpacing: 0.8,
    textTransform: 'uppercase' as const,
  },
  actions: {
    display: 'flex',
    gap: 8,
    marginTop: 2,
  },
  button: {
    background: 'transparent',
    border: '1px solid',
    borderRadius: 0,
    padding: '6px 10px',
    fontSize: 9,
    textTransform: 'uppercase' as const,
    letterSpacing: 0.9,
    cursor: 'pointer',
    fontFamily: 'inherit',
  },
};
