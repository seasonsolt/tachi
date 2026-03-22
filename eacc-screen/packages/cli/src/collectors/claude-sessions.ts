import { watch } from 'chokidar';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import type { SessionInfo } from '@eacc/shared';

const SESSIONS_DIR = join(homedir(), '.claude', 'sessions');

function isAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function readSessions(): SessionInfo[] {
  if (!existsSync(SESSIONS_DIR)) return [];

  const sessions: SessionInfo[] = [];
  try {
    const files = readdirSync(SESSIONS_DIR).filter((f) => f.endsWith('.json'));
    for (const file of files) {
      try {
        const raw = readFileSync(join(SESSIONS_DIR, file), 'utf-8');
        const data = JSON.parse(raw);
        if (data.pid && data.sessionId && data.cwd && data.startedAt) {
          sessions.push({
            pid: data.pid,
            sessionId: data.sessionId,
            cwd: data.cwd,
            startedAt: data.startedAt,
            alive: isAlive(data.pid),
          });
        }
      } catch {
        // skip malformed files
      }
    }
  } catch {
    // directory read failed
  }

  return sessions.filter((s) => s.alive);
}

export function startSessionCollector(
  onUpdate: (sessions: SessionInfo[]) => void,
): () => void {
  // Initial read
  onUpdate(readSessions());

  let debounceTimer: ReturnType<typeof setTimeout> | undefined;

  function debouncedUpdate() {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      onUpdate(readSessions());
    }, 2000);
  }

  const watcher = watch(SESSIONS_DIR, {
    persistent: true,
    ignoreInitial: true,
    depth: 0,
  });

  watcher.on('add', debouncedUpdate);
  watcher.on('change', debouncedUpdate);
  watcher.on('unlink', debouncedUpdate);

  return () => {
    clearTimeout(debounceTimer);
    watcher.close();
  };
}
