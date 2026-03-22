import { useRef, useEffect, useState } from 'react';
import { useStore } from '../stores/store';
import { useTokenData } from '../hooks/useTokenData';
import { THEMES, formatTokenCount, formatUSD } from '@ritual-screen/shared';

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
    <span style={{ ...style, opacity: fading ? 0.4 : 1, filter: fading ? 'blur(2px)' : 'blur(0px)', transition: 'all 0.15s ease' }}>
      {display}
    </span>
  );
}

interface SourceRow {
  label: string;
  tokens: string;
  cost: string;
}

function getSourceRows(
  sources: { claudeCode: { todayTokens: number; todayCostUSD: number; monthTokens: number; monthCostUSD: number; connected: boolean; inputTokens: number; outputTokens: number; totalTokens: number }; anthropicApi: { todayTokens: number; todayCostUSD: number; monthTokens: number; monthCostUSD: number; connected: boolean }; openaiApi: { todayTokens: number; todayCostUSD: number; monthTokens: number; monthCostUSD: number; connected: boolean } },
  period: 'today' | 'month',
  isCli: boolean,
): SourceRow[] {
  const rows: SourceRow[] = [];
  if (isCli && sources.claudeCode.connected) {
    const tokens = period === 'today' ? sources.claudeCode.todayTokens : sources.claudeCode.monthTokens;
    const cost = period === 'today' ? sources.claudeCode.todayCostUSD : sources.claudeCode.monthCostUSD;
    if (tokens > 0) rows.push({ label: 'CC', tokens: formatTokenCount(tokens), cost: formatUSD(cost) });
  }
  if (sources.anthropicApi.connected) {
    const tokens = period === 'today' ? sources.anthropicApi.todayTokens : sources.anthropicApi.monthTokens;
    const cost = period === 'today' ? sources.anthropicApi.todayCostUSD : sources.anthropicApi.monthCostUSD;
    if (tokens > 0) rows.push({ label: 'AN', tokens: formatTokenCount(tokens), cost: formatUSD(cost) });
  }
  if (sources.openaiApi.connected) {
    const tokens = period === 'today' ? sources.openaiApi.todayTokens : sources.openaiApi.monthTokens;
    const cost = period === 'today' ? sources.openaiApi.todayCostUSD : sources.openaiApi.monthCostUSD;
    if (tokens > 0) rows.push({ label: 'OA', tokens: formatTokenCount(tokens), cost: formatUSD(cost) });
  }
  return rows;
}

export function Pulse() {
  const theme = useStore((s) => s.theme);
  const mode = useStore((s) => s.mode);
  const tokenData = useStore((s) => s.tokenData);
  const t = THEMES[theme];
  const [hovered, setHovered] = useState(false);
  const {
    rateDisplay,
    todayTokensDisplay,
    todayCostDisplay,
    monthTokensDisplay,
    monthCostDisplay,
  } = useTokenData();

  const isCli = mode === 'cli';
  const sources = tokenData?.sources;
  const hasBreakdown = hovered && sources;

  const todayRows = hasBreakdown ? getSourceRows(sources, 'today', isCli) : [];
  const monthRows = hasBreakdown ? getSourceRows(sources, 'month', isCli) : [];
  const showBreakdown = todayRows.length > 0 || monthRows.length > 0;

  // in/out and cache stats
  const showIoCache = hasBreakdown && isCli && sources.claudeCode.connected;
  const totalInput = sources ? sources.claudeCode.inputTokens + sources.anthropicApi.inputTokens + sources.openaiApi.inputTokens : 0;
  const totalOutput = sources ? sources.claudeCode.outputTokens + sources.anthropicApi.outputTokens + sources.openaiApi.outputTokens : 0;

  return (
    <div
      style={{
        ...styles.container,
        fontFamily: t.dataFont,
        opacity: hovered ? 0.95 : 0.82,
        background: `linear-gradient(90deg, ${t.surfaceStrong} 0%, ${t.surfaceSoft} 68%, transparent 100%)`,
        textShadow: `0 0 12px ${t.accentGlow}`,
        borderTop: `1px solid ${t.surfaceBorder}`,
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <div style={styles.row}>
        <span style={styles.label}>rate</span>
        <AnimatedValue value={rateDisplay} style={styles.value} />
      </div>
      {tokenData && tokenData.totalTokens > 0 && (
        <>
          <div style={styles.divider} />
          <div style={styles.row}>
            <span style={styles.label}>total</span>
            <span style={styles.value}>
              <AnimatedValue value={formatTokenCount(tokenData.totalTokens)} />{' '}
              <span style={styles.cost}><AnimatedValue value={formatUSD(tokenData.totalCostUSD)} /></span>
            </span>
          </div>
        </>
      )}
      {showBreakdown && <div style={styles.wideDivider} />}
      {!showBreakdown && <div style={styles.divider} />}
      <div style={styles.row}>
        <span style={styles.label}>today</span>
        <span style={styles.value}>
          <AnimatedValue value={todayTokensDisplay} />{' '}
          <AnimatedValue value={todayCostDisplay} style={styles.cost} />
        </span>
      </div>
      {showBreakdown && todayRows.map((r) => (
        <div key={`today-${r.label}`} style={styles.sourceRow}>
          <span style={styles.sourceLabel}>{r.label}</span>
          <span style={styles.sourceValue}>
            {r.tokens}{'  '}<span style={styles.cost}>{r.cost}</span>
          </span>
        </div>
      ))}
      <div style={styles.row}>
        <span style={styles.label}>month</span>
        <span style={styles.value}>
          <AnimatedValue value={monthTokensDisplay} />{' '}
          <AnimatedValue value={monthCostDisplay} style={styles.cost} />
        </span>
      </div>
      {showBreakdown && monthRows.map((r) => (
        <div key={`month-${r.label}`} style={styles.sourceRow}>
          <span style={styles.sourceLabel}>{r.label}</span>
          <span style={styles.sourceValue}>
            {r.tokens}{'  '}<span style={styles.cost}>{r.cost}</span>
          </span>
        </div>
      ))}
      {showBreakdown && (showIoCache || totalInput > 0) && (
        <>
          <div style={styles.wideDivider} />
          {totalInput > 0 && (
            <div style={styles.sourceRow}>
              <span style={styles.sourceLabel}>in/out</span>
              <span style={styles.sourceValue}>
                {formatTokenCount(totalInput)} / {formatTokenCount(totalOutput)}
              </span>
            </div>
          )}
        </>
      )}
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    opacity: 0.5,
    fontSize: 13,
    lineHeight: 1.8,
    color: 'var(--text-secondary)',
    zIndex: 5,
    transition: 'opacity 0.3s ease',
    cursor: 'default',
    padding: '16px 42px 16px 24px',
    minWidth: 220,
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
    color: 'var(--text-primary)',
  },
  cost: {
    color: 'var(--text-muted)',
    fontSize: 11,
    opacity: 0.95,
  },
  divider: {
    width: 32,
    height: 1,
    background: 'var(--text-muted)',
    opacity: 0.3,
    margin: '4px 0',
  },
  wideDivider: {
    width: 120,
    height: 1,
    background: 'var(--text-muted)',
    opacity: 0.2,
    margin: '4px 0',
  },
  sourceRow: {
    display: 'flex',
    gap: 12,
    alignItems: 'baseline',
    paddingLeft: 16,
  },
  sourceLabel: {
    color: 'var(--text-muted)',
    minWidth: 32,
    textTransform: 'uppercase' as const,
    fontSize: 9,
    letterSpacing: 1,
    opacity: 0.7,
  },
  sourceValue: {
    color: 'var(--text-secondary)',
    fontSize: 11,
    opacity: 0.9,
  },
};
