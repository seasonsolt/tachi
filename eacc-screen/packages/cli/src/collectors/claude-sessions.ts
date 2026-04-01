import { watch } from 'chokidar';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { execFileSync } from 'node:child_process';
import type { SessionInfo, SessionTool } from '@eacc/shared';

const CLAUDE_SESSIONS_DIR = join(homedir(), '.claude', 'sessions');
const OPENCODE_DIR = join(homedir(), '.local', 'share', 'opencode');
const OPENCODE_DB = join(OPENCODE_DIR, 'opencode.db');

interface OpenCodeProcess {
  pid: number;
  cwd: string;
}

interface OpenCodeMessage {
  role?: string;
  summary?: unknown;
  content?: unknown;
  message?: unknown;
}

interface OpenCodeSessionRecord {
  sessionId: string;
  cwd: string;
  startedAt: number;
  taskTitle?: string;
  taskSummary?: string;
}

function isAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function readSessions(): SessionInfo[] {
  return [...readClaudeSessions(), ...readOpenCodeSessions()];
}

function readClaudeSessions(): SessionInfo[] {
  if (!existsSync(CLAUDE_SESSIONS_DIR)) return [];

  const sessions: SessionInfo[] = [];
  try {
    const files = readdirSync(CLAUDE_SESSIONS_DIR).filter((f) => f.endsWith('.json'));
    for (const file of files) {
      try {
        const raw = readFileSync(join(CLAUDE_SESSIONS_DIR, file), 'utf-8');
        const data = JSON.parse(raw);
        if (data.pid && data.sessionId && data.cwd && data.startedAt) {
          sessions.push({
            pid: data.pid,
            sessionId: data.sessionId,
            cwd: data.cwd,
            startedAt: data.startedAt,
            alive: isAlive(data.pid),
            tool: 'claude_code',
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

function readOpenCodeSessions(): SessionInfo[] {
  if (!existsSync(OPENCODE_DB)) return [];

  const processes = readOpenCodeProcesses();
  if (processes.length === 0) return [];

  const sessionsById = new Map<string, SessionInfo>();
  for (const process of processes) {
    const record = readLatestOpenCodeSessionForDirectory(process.cwd);
    if (!record) continue;

    const session: SessionInfo = {
      pid: process.pid,
      sessionId: record.sessionId,
      cwd: record.cwd,
      startedAt: record.startedAt,
      alive: true,
      tool: 'open_code',
      taskTitle: record.taskTitle,
      taskSummary: record.taskSummary,
    };

    const existing = sessionsById.get(record.sessionId);
    if (!existing || session.startedAt >= existing.startedAt) {
      sessionsById.set(record.sessionId, session);
    }
  }

  return Array.from(sessionsById.values());
}

function readOpenCodeProcesses(): OpenCodeProcess[] {
  try {
    const output = execFileSync('lsof', ['-a', '-c', 'opencode', '-d', 'cwd', '-Fn'], {
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });

    const processes: OpenCodeProcess[] = [];
    let pid: number | null = null;
    for (const line of output.split(/\r?\n/)) {
      if (!line) continue;
      if (line.startsWith('p')) {
        const nextPid = Number.parseInt(line.slice(1), 10);
        pid = Number.isFinite(nextPid) ? nextPid : null;
        continue;
      }
      if (line.startsWith('n') && pid !== null) {
        const cwd = line.slice(1).trim();
        if (cwd) {
          processes.push({ pid, cwd });
        }
        pid = null;
      }
    }

    return processes.filter((process) => isAlive(process.pid));
  } catch {
    return [];
  }
}

function quoteSQLite(value: string): string {
  return `'${value.replaceAll("'", "''")}'`;
}

function readLatestOpenCodeSessionForDirectory(cwd: string): OpenCodeSessionRecord | null {
  try {
    const sql = [
      'select id, slug, directory, title, time_created',
      'from session',
      `where directory = ${quoteSQLite(cwd)} and time_archived is null`,
      'order by time_updated desc',
      'limit 1;',
    ].join(' ');
    const output = execFileSync('sqlite3', ['-separator', '\t', OPENCODE_DB, sql], {
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    if (!output) return null;

    const [sessionId, slug, directory, title, createdAt] = output.split('\t');
    const startedAt = Number.parseInt(createdAt, 10);
    if (!sessionId || !directory || !Number.isFinite(startedAt)) return null;

    const messages = readOpenCodeMessages(sessionId);
    const taskTitle = openCodeTaskTitle(title, slug);

    return {
      sessionId,
      cwd: directory,
      startedAt,
      taskTitle,
      taskSummary: openCodeTaskSummary(messages, taskTitle),
    };
  } catch {
    return null;
  }
}

function readOpenCodeMessages(sessionId: string): OpenCodeMessage[] {
  try {
    const sql = [
      'select data',
      'from message',
      `where session_id = ${quoteSQLite(sessionId)}`,
      'order by time_updated desc',
      'limit 8;',
    ].join(' ');
    const output = execFileSync('sqlite3', [OPENCODE_DB, sql], {
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    if (!output) return [];

    return output
      .split(/\r?\n/)
      .map((line) => {
        try {
          return JSON.parse(line) as OpenCodeMessage;
        } catch {
          return null;
        }
      })
      .filter((message): message is OpenCodeMessage => message !== null);
  } catch {
    return [];
  }
}

function openCodeTaskTitle(title: string, slug: string): string | undefined {
  const safeTitle = sanitizeTaskText(title);
  if (safeTitle && !safeTitle.startsWith('New session - ')) {
    return safeTitle;
  }
  return sanitizeTaskText(slug);
}

function openCodeTaskSummary(messages: OpenCodeMessage[], fallback?: string): string | undefined {
  const latestUserMessage = messages.find((message) => message.role === 'user');
  if (latestUserMessage) {
    const summary = extractText(latestUserMessage.summary)
      ?? extractText(latestUserMessage.content ?? latestUserMessage.message);
    if (summary) return summary;
  }

  const latestMessage = messages[0];
  const latestSummary = extractText(latestMessage?.summary);
  if (latestSummary) return latestSummary;

  return sanitizeTaskText(fallback);
}

function extractText(raw: unknown): string | undefined {
  if (typeof raw === 'string') {
    return sanitizeTaskText(raw);
  }

  if (Array.isArray(raw)) {
    const text = raw
      .map((item) => extractText(item))
      .filter((item): item is string => Boolean(item))
      .join(' ');
    return sanitizeTaskText(text);
  }

  if (raw && typeof raw === 'object') {
    const record = raw as Record<string, unknown>;
    return extractText(record.text)
      ?? extractText(record.content)
      ?? extractText(record.message);
  }

  return undefined;
}

function sanitizeTaskText(raw: string | undefined): string | undefined {
  if (!raw) return undefined;

  const squashed = raw
    .replaceAll('\n', ' ')
    .replaceAll('\r', ' ')
    .split(/\s+/)
    .join(' ')
    .trim();

  if (!squashed) return undefined;
  return squashed.length <= 120 ? squashed : `${squashed.slice(0, 117)}...`;
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

  const watcher = watch([CLAUDE_SESSIONS_DIR, OPENCODE_DIR], {
    persistent: true,
    ignoreInitial: true,
    depth: 1,
  });

  watcher.on('add', debouncedUpdate);
  watcher.on('change', debouncedUpdate);
  watcher.on('unlink', debouncedUpdate);

  return () => {
    clearTimeout(debounceTimer);
    watcher.close();
  };
}
