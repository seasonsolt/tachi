import { useEffect, useMemo, useRef, useState } from 'react';
import { useStore } from '../stores/store';
import { THEMES } from '@eacc/shared';
import type { SessionInfo, SessionStatus, SessionTool } from '@eacc/shared';
import { isSessionCompleted, isSessionVisible, sessionStateLabel } from './session-state';

interface SessionRow {
  id: string;
  fullPath: string;
  projectName: string;
  trail: string;
  startedAt: number;
  alive: boolean;
  status?: SessionStatus;
  tool?: SessionTool;
  taskLabel?: string;
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

function sessionToolLabel(tool?: SessionTool): string | null {
  switch (tool) {
    case 'claude_code':
      return 'CLAUDE';
    case 'claude_design':
      return 'DESIGN';
    case 'codex':
      return 'CODEX';
    case 'open_code':
      return 'OPEN';
    case 'pencil':
      return 'PENCIL';
    default:
      return null;
  }
}

function compactTaskText(raw?: string): string | undefined {
  if (!raw) return undefined;
  let text = raw.trim();
  if (!text) return undefined;

  text = text.replace(/^\s*[=\-:#>\[\]()]+\s*/, '').replace(/\s*[=\-:#>\[\]()]+\s*$/, '');

  for (const delimiter of ['。', '！', '？', '. ', '! ', '? ', '\n']) {
    const index = text.indexOf(delimiter);
    if (index >= 10) {
      text = text.slice(0, index).trim();
      break;
    }
  }

  const colonIndex = text.indexOf(': ');
  if (colonIndex > 0 && colonIndex < 18) {
    const tail = text.slice(colonIndex + 2).trim();
    if (tail.length >= 10) {
      text = tail;
    }
  }

  if (!text || looksLikeOnlyAPath(text)) return undefined;
  return text.length <= 84 ? text : `${text.slice(0, 81)}...`;
}

function looksLikeOnlyAPath(text: string): boolean {
  const slashCount = Array.from(text).filter((char) => char === '/').length;
  if (text.startsWith('/') && slashCount >= 2) return true;
  return text.includes('/Users/') || text.includes('/src/') || text.includes('/main/');
}

function taskLabelForSession(session: SessionInfo): string | undefined {
  return compactTaskText(session.taskSummary) ?? compactTaskText(session.taskTitle);
}

export function Sessions() {
  const mode = useStore((s) => s.mode);
  const sessions = useStore((s) => s.sessions);
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];
  const [hovered, setHovered] = useState(false);
  const [now, setNow] = useState(() => Date.now());
  const completedSessionObservedAt = useRef(new Map<string, number>());

  useEffect(() => {
    const interval = window.setInterval(() => setNow(Date.now()), 1_000);
    return () => window.clearInterval(interval);
  }, []);

  const sessionRows = useMemo<SessionRow[]>(() => {
    const currentKeys = new Set<string>();
    const rows = [...sessions]
      .filter((session) => {
        const key = `${session.tool ?? 'session'}:${session.sessionId}`;
        currentKeys.add(key);
        if (!isSessionCompleted(session)) {
          completedSessionObservedAt.current.delete(key);
          return true;
        }

        const observedAt = completedSessionObservedAt.current.get(key) ?? now;
        completedSessionObservedAt.current.set(key, observedAt);
        return isSessionVisible(session, now, observedAt);
      })
      .sort((a, b) => b.startedAt - a.startedAt)
      .map((session) => {
        const pathInfo = compactPath(session.cwd);
        return {
          id: `${session.tool ?? 'session'}:${session.sessionId}:${session.pid}`,
          fullPath: pathInfo.fullPath,
          projectName: pathInfo.projectName,
          trail: pathInfo.trail,
          startedAt: session.startedAt,
          alive: session.alive,
          status: session.status,
          tool: session.tool,
          taskLabel: taskLabelForSession(session),
        };
      });

    for (const key of completedSessionObservedAt.current.keys()) {
      if (!currentKeys.has(key)) completedSessionObservedAt.current.delete(key);
    }
    return rows;
  }, [sessions, now]);

  const visibleCount = hovered ? sessionRows.length : Math.min(sessionRows.length, 4);
  const visibleSessions = sessionRows.slice(0, visibleCount);
  const hiddenCount = sessionRows.length - visibleSessions.length;
  const openCount = sessionRows.filter((session) => session.status
    ? session.status !== 'completed'
    : session.alive).length;

  if (mode !== 'cli' || sessionRows.length === 0) return null;

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
        <span style={styles.summaryLabel}>sessions</span>
        <span style={styles.count}>
          {sessionRows.length}
        </span>
        <span style={styles.sessionMeta}>{openCount} open</span>
      </div>

      <div style={styles.expanded}>
        {visibleSessions.map((session) => (
          <div key={session.id} style={styles.sessionRow} title={session.fullPath}>
            <div style={styles.pathBlock}>
              <div style={styles.projectRow}>
                <span style={styles.projectName}>{session.projectName}</span>
                {session.tool && (
                  <span style={styles.toolBadge}>{sessionToolLabel(session.tool)}</span>
                )}
              </div>
              {session.taskLabel && (
                <span style={styles.taskLine}>{session.taskLabel}</span>
              )}
              <span style={styles.sessionTrail}>{session.trail}</span>
            </div>
            <div style={styles.metaBlock}>
              <span style={styles.sessionState}>{sessionStateLabel(session)}</span>
              <span style={styles.sessionDuration}>{formatDuration(session.startedAt, now)}</span>
            </div>
          </div>
        ))}
        {hiddenCount > 0 && (
          <div style={styles.overflowRow}>
            <span style={styles.overflowText}>
              +{hiddenCount} more session{hiddenCount !== 1 ? 's' : ''}
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
  projectRow: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    minWidth: 0,
  },
  projectName: {
    color: 'var(--text-primary)',
    fontSize: 13,
    lineHeight: 1.2,
    letterSpacing: 0.1,
    fontVariantNumeric: 'tabular-nums',
  },
  toolBadge: {
    color: 'var(--text-muted)',
    fontSize: 8,
    letterSpacing: 1,
    textTransform: 'uppercase' as const,
    opacity: 0.9,
    flexShrink: 0,
  },
  taskLine: {
    color: 'var(--text-secondary)',
    fontSize: 11,
    lineHeight: 1.35,
    letterSpacing: 0.2,
    whiteSpace: 'nowrap' as const,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    maxWidth: 220,
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
  sessionDuration: {
    color: 'var(--text-secondary)',
    fontSize: 11,
    fontVariantNumeric: 'tabular-nums',
    whiteSpace: 'nowrap' as const,
  },
  sessionState: {
    color: 'var(--text-secondary)',
    fontSize: 9,
    letterSpacing: '0.8px',
    textTransform: 'uppercase',
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
