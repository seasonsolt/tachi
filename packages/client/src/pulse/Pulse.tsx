import { useRef, useEffect, useState } from 'react';
import { useStore } from '../stores/store';
import { useTokenData } from '../hooks/useTokenData';
import { THEMES } from '@ritual-screen/shared';

function AnimatedValue({ value, style }: { value: string; style?: React.CSSProperties }) {
  const [display, setDisplay] = useState(value);
  const [fading, setFading] = useState(false);
  const prevRef = useRef(value);

  useEffect(() => {
    if (value !== prevRef.current) {
      setFading(true);
      const t = setTimeout(() => {
        setDisplay(value);
        setFading(false);
        prevRef.current = value;
      }, 150);
      return () => clearTimeout(t);
    }
  }, [value]);

  return (
    <span style={{ ...style, opacity: fading ? 0.4 : 1, transition: 'opacity 0.15s ease' }}>
      {display}
    </span>
  );
}

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
        <AnimatedValue value={rateDisplay} style={styles.value} />
      </div>
      <div style={styles.divider} />
      <div style={styles.row}>
        <span style={styles.label}>today</span>
        <span style={styles.value}>
          <AnimatedValue value={todayTokensDisplay} />{' '}
          <AnimatedValue value={todayCostDisplay} style={styles.cost} />
        </span>
      </div>
      <div style={styles.row}>
        <span style={styles.label}>month</span>
        <span style={styles.value}>
          <AnimatedValue value={monthTokensDisplay} />{' '}
          <AnimatedValue value={monthCostDisplay} style={styles.cost} />
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
