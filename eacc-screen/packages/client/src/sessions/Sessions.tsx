import { useEffect, useMemo, useState } from 'react';
import { useStore } from '../stores/store';
import { THEMES } from '@eacc/shared';

interface WorkspaceGroup {
  cwd: string;
  fullPath: string;
  projectName: string;
  trail: string;
  startedAt: number;
  sessionCount: number;
}

function formatDuration(startedAt: number, now: number): string {
  const ms = now - startedAt;
  const minutes = Math.floor(ms / 60_000);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const rem = minutes % 60;
  return `${hours}h ${rem}m`;
}

function compactPath(cwd: string): { projectName: string; trail: string; fullPath: string } {
  const fullPath = cwd.replace(/^\/Users\/[^/]+/, '~');
  const segments = fullPath.split('/').filter(Boolean);
  const projectName = segments[segments.length - 1] ?? fullPath;
  const parentSegments = segments.slice(0, -1);

  if (parentSegments.length === 0) {
    return { projectName, trail: fullPath.startsWith('/') ? '/' : '~', fullPath };
  }

  if (fullPath.startsWith('~')) {
    const visible = parentSegments.slice(-3);
    const trail = parentSegments.length > 3
      ? `~/.../${visible.join('/')}`
      : `~/${visible.join('/')}`;
    return { projectName, trail, fullPath };
  }

  const visible = parentSegments.slice(-3);
  const trail = parentSegments.length > 3
    ? `.../${visible.join('/')}`
    : `/${visible.join('/')}`;
  return { projectName, trail, fullPath };
}

export function Sessions() {
  const mode = useStore((s) => s.mode);
  const sessions = useStore((s) => s.sessions);
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];
  const [hovered, setHovered] = useState(false);
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    const interval = window.setInterval(() => setNow(Date.now()), 60_000);
    return () => window.clearInterval(interval);
  }, []);

  const workspaces = useMemo<WorkspaceGroup[]>(() => {
    const grouped = new Map<string, WorkspaceGroup>();

    for (const session of sessions) {
      const existing = grouped.get(session.cwd);
      const pathInfo = compactPath(session.cwd);

      if (existing) {
        existing.sessionCount += 1;
        existing.startedAt = Math.max(existing.startedAt, session.startedAt);
        continue;
      }

      grouped.set(session.cwd, {
        cwd: session.cwd,
        fullPath: pathInfo.fullPath,
        projectName: pathInfo.projectName,
        trail: pathInfo.trail,
        startedAt: session.startedAt,
        sessionCount: 1,
      });
    }

    return Array.from(grouped.values()).sort((a, b) => b.startedAt - a.startedAt);
  }, [sessions]);

  const visibleCount = hovered ? workspaces.length : Math.min(workspaces.length, 4);
  const visibleWorkspaces = workspaces.slice(0, visibleCount);
  const hiddenCount = workspaces.length - visibleWorkspaces.length;
  const hasMultipleSessions = sessions.length !== workspaces.length;

  if (mode !== 'cli' || sessions.length === 0) return null;

  return (
    <div
      style={{
        ...styles.container,
        fontFamily: t.dataFont,
        opacity: hovered ? 0.92 : 0.78,
        background: `linear-gradient(90deg, ${t.surfaceStrong} 0%, ${t.surfaceSoft} 58%, transparent 100%)`,
        textShadow: `0 0 12px ${t.accentGlow}`,
        borderBottom: `1px solid ${t.surfaceBorder}`,
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <div style={styles.summary}>
        <span style={styles.dot} />
        <span style={styles.summaryLabel}>workspaces</span>
        <span style={styles.count}>
          {workspaces.length}
        </span>
        {hasMultipleSessions && (
          <span style={styles.sessionMeta}>
            {sessions.length} live
          </span>
        )}
      </div>

      <div style={styles.expanded}>
        {visibleWorkspaces.map((workspace) => (
          <div key={workspace.cwd} style={styles.sessionRow} title={workspace.fullPath}>
            <div style={styles.pathBlock}>
              <span style={styles.projectName}>{workspace.projectName}</span>
              <span style={styles.sessionTrail}>{workspace.trail}</span>
            </div>
            <div style={styles.metaBlock}>
              {workspace.sessionCount > 1 && (
                <span style={styles.sessionCount}>x{workspace.sessionCount}</span>
              )}
              <span style={styles.sessionDuration}>{formatDuration(workspace.startedAt, now)}</span>
            </div>
          </div>
        ))}
        {hiddenCount > 0 && (
          <div style={styles.overflowRow}>
            <span style={styles.overflowText}>
              +{hiddenCount} more workspace{hiddenCount !== 1 ? 's' : ''}
            </span>
          </div>
        )}
      </div>

      <style>{keyframes}</style>
    </div>
  );
}

const keyframes = `
  @keyframes sessionPulse {
    0%, 100% { opacity: 0.6; }
    50% { opacity: 1; }
  }
`;

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    top: 24,
    left: 24,
    zIndex: 5,
    minWidth: 240,
    maxWidth: 360,
    padding: '10px 40px 14px 0',
    transition: 'opacity 0.3s ease',
    cursor: 'default',
  },
  summary: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    color: 'var(--text-secondary)',
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: '50%',
    backgroundColor: 'var(--fire-core)',
    animation: 'sessionPulse 2s ease-in-out infinite',
    flexShrink: 0,
    marginTop: 1,
  },
  summaryLabel: {
    color: 'var(--text-muted)',
    fontSize: 10,
    letterSpacing: 1.1,
    textTransform: 'uppercase' as const,
  },
  count: {
    color: 'var(--text-primary)',
    fontSize: 14,
    letterSpacing: 0.4,
    fontVariantNumeric: 'tabular-nums',
  },
  sessionMeta: {
    color: 'var(--text-muted)',
    fontSize: 10,
    letterSpacing: 0.6,
    textTransform: 'uppercase' as const,
    opacity: 0.85,
  },
  expanded: {
    marginTop: 10,
    display: 'flex',
    flexDirection: 'column',
    gap: 9,
  },
  sessionRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 16,
    minWidth: 0,
  },
  pathBlock: {
    display: 'flex',
    flexDirection: 'column',
    minWidth: 0,
    gap: 2,
  },
  projectName: {
    color: 'var(--text-primary)',
    fontSize: 13,
    lineHeight: 1.2,
    letterSpacing: 0.1,
    fontVariantNumeric: 'tabular-nums',
  },
  sessionTrail: {
    color: 'var(--text-secondary)',
    fontSize: 10,
    lineHeight: 1.35,
    letterSpacing: 0.5,
    opacity: 0.9,
    whiteSpace: 'nowrap' as const,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },
  metaBlock: {
    display: 'flex',
    alignItems: 'baseline',
    justifyContent: 'flex-end',
    gap: 8,
    flexShrink: 0,
    minWidth: 72,
  },
  sessionCount: {
    color: 'var(--text-muted)',
    fontSize: 9,
    letterSpacing: 0.8,
    textTransform: 'uppercase' as const,
  },
  sessionDuration: {
    color: 'var(--text-secondary)',
    fontSize: 11,
    fontVariantNumeric: 'tabular-nums',
    whiteSpace: 'nowrap' as const,
  },
  overflowRow: {
    marginTop: 2,
  },
  overflowText: {
    color: 'var(--text-muted)',
    fontSize: 10,
    letterSpacing: 0.7,
    textTransform: 'uppercase' as const,
    opacity: 0.8,
  },
};
