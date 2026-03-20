import { useStore } from '../stores/store';
import { useTokenData } from '../hooks/useTokenData';
import { THEMES } from '@ritual-screen/shared';

export function Pulse() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];
  const {
    rateDisplay,
    todayTokensDisplay,
    todayCostDisplay,
    monthTokensDisplay,
    monthCostDisplay,
  } = useTokenData();

  return (
    <div style={{ ...styles.container, fontFamily: t.dataFont }}>
      <div style={styles.row}>
        <span style={styles.label}>rate</span>
        <span style={styles.value}>{rateDisplay}</span>
      </div>
      <div style={styles.divider} />
      <div style={styles.row}>
        <span style={styles.label}>today</span>
        <span style={styles.value}>
          {todayTokensDisplay}{' '}
          <span style={styles.cost}>{todayCostDisplay}</span>
        </span>
      </div>
      <div style={styles.row}>
        <span style={styles.label}>month</span>
        <span style={styles.value}>
          {monthTokensDisplay}{' '}
          <span style={styles.cost}>{monthCostDisplay}</span>
        </span>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    bottom: 24,
    left: 24,
    opacity: 0.5,
    fontSize: 13,
    lineHeight: 1.8,
    color: 'var(--text-secondary)',
    zIndex: 5,
  },
  row: {
    display: 'flex',
    gap: 12,
    alignItems: 'baseline',
  },
  label: {
    color: 'var(--text-muted)',
    minWidth: 48,
    textTransform: 'uppercase' as const,
    fontSize: 10,
    letterSpacing: 1,
  },
  value: {
    color: 'var(--text-secondary)',
    transition: 'color 0.3s',
  },
  cost: {
    color: 'var(--text-muted)',
    fontSize: 11,
  },
  divider: {
    width: 32,
    height: 1,
    background: 'var(--text-muted)',
    opacity: 0.3,
    margin: '4px 0',
  },
};
