import type { SessionInfo } from '@eacc/shared';

const COMPLETED_SESSION_RETENTION_MS = 5 * 60_000;

export function sessionStateLabel(session: Pick<SessionInfo, 'alive' | 'status'>): string {
  switch (session.status) {
    case 'working':
      return 'working';
    case 'waiting_for_input':
      return 'waiting';
    case 'idle':
      return 'idle';
    case 'completed':
      return 'done';
    default:
      return session.alive ? 'watching' : 'done';
  }
}

export function isSessionVisible(
  session: Pick<SessionInfo, 'alive' | 'lastActivityAt' | 'signal' | 'startedAt' | 'status'>,
  now: number,
  observedCompletedAt?: number,
): boolean {
  if (!isSessionCompleted(session)) return true;

  const lastActivityAt = session.lastActivityAt ?? session.startedAt;
  const inferredCompletionDelay = session.status === 'completed' && session.signal !== 'completed'
    ? COMPLETED_SESSION_RETENTION_MS
    : 0;
  const completedAt = observedCompletedAt ?? lastActivityAt + inferredCompletionDelay;
  return now - completedAt <= COMPLETED_SESSION_RETENTION_MS;
}

export function isSessionCompleted(session: Pick<SessionInfo, 'alive' | 'status'>): boolean {
  return session.status === 'completed' || (!session.status && !session.alive);
}
