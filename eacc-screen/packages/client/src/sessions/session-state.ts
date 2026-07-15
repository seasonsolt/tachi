import type { SessionInfo } from '@eacc/shared';

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
