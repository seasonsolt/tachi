import { watch } from 'chokidar';
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { execFileSync } from 'node:child_process';
import type { SessionInfo, SessionTool } from '@eacc/shared';

const CLAUDE_SESSIONS_DIR = join(homedir(), '.claude', 'sessions');
const CLAUDE_PROJECTS_DIR = join(homedir(), '.claude', 'projects');
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

interface ClaudeProjectEntry {
  timestamp?: unknown;
  type?: unknown;
  cwd?: unknown;
  slug?: unknown;
  entrypoint?: unknown;
  message?: unknown;
  content?: unknown;
  toolUseResult?: unknown;
  isMeta?: unknown;
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
  const claudeSessions = readClaudeSessions();
  const aliveSessionIds = new Set(claudeSessions.map((s) => s.sessionId));
  return dedupeSessions([
    ...claudeSessions,
    ...readClaudeProjectSessions(
      CLAUDE_PROJECTS_DIR,
      Date.now(),
      readRegisteredClaudeSessionIds(),
      aliveSessionIds,
    ),
    ...readOpenCodeSessions(),
  ]);
}

// Session ids registered by a local Claude Code process (any entrypoint,
// including the desktop app). Desktop-launched transcripts without such a
// registration are the only ones attributed to Claude Design.
export function readRegisteredClaudeSessionIds(sessionsDir = CLAUDE_SESSIONS_DIR): Set<string> {
  const ids = new Set<string>();
  if (!existsSync(sessionsDir)) return ids;
  try {
    for (const file of readdirSync(sessionsDir).filter((f) => f.endsWith('.json'))) {
      try {
        const data = JSON.parse(readFileSync(join(sessionsDir, file), 'utf-8'));
        if (typeof data.sessionId === 'string') ids.add(data.sessionId);
      } catch {
        // skip malformed files
      }
    }
  } catch {
    // directory read failed
  }
  return ids;
}

function dedupeSessions(sessions: SessionInfo[]): SessionInfo[] {
  const result = new Map<string, SessionInfo>();
  for (const session of sessions) {
    const key = `${session.tool ?? 'session'}:${session.sessionId}`;
    const existing = result.get(key);
    if (!existing || isBetterSession(session, existing)) {
      result.set(key, session);
    }
  }
  return Array.from(result.values());
}

function isBetterSession(candidate: SessionInfo, existing: SessionInfo): boolean {
  const candidateHasTask = Boolean(candidate.taskTitle || candidate.taskSummary);
  const existingHasTask = Boolean(existing.taskTitle || existing.taskSummary);
  if (candidateHasTask !== existingHasTask) return candidateHasTask;
  if (candidate.alive !== existing.alive) return candidate.alive;
  return candidate.startedAt >= existing.startedAt;
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

export function readClaudeProjectSessions(
  projectsDir = CLAUDE_PROJECTS_DIR,
  nowMs = Date.now(),
  registeredSessionIds: ReadonlySet<string> = new Set(),
  aliveSessionIds: ReadonlySet<string> = new Set(),
): SessionInfo[] {
  if (!existsSync(projectsDir)) return [];

  const cutoffMs = nowMs - 60 * 60 * 1000;
  const sessions: SessionInfo[] = [];

  try {
    const projectDirs = readdirSync(projectsDir);
    for (const dir of projectDirs) {
      const projectDir = join(projectsDir, dir);
      let files: string[];
      try {
        files = readdirSync(projectDir).filter((file) => file.endsWith('.jsonl'));
      } catch {
        continue;
      }

      for (const file of files) {
        const filePath = join(projectDir, file);
        let modifiedMs: number;
        try {
          modifiedMs = statSync(filePath).mtimeMs;
        } catch {
          continue;
        }
        if (modifiedMs <= cutoffMs) continue;

        // 40 entries: during a long agent turn the tail is mostly
        // assistant/tool_result lines; the real prompt sits further back.
        const recentEntries = readRecentClaudeProjectEntries(filePath, 40, 262_144);
        const lastEntry = recentEntries[0];
        const sessionId = file.slice(0, -'.jsonl'.length);
        const cwd = typeof lastEntry?.cwd === 'string' ? lastEntry.cwd : decodeClaudeProjectDir(dir);
        const slug = typeof lastEntry?.slug === 'string' ? lastEntry.slug : '';
        const startedAt = parseTimestampMs(lastEntry?.timestamp) ?? modifiedMs;
        const isDesktop = recentEntries.some((entry) => entry.entrypoint === 'claude-desktop');
        const isDesign = isDesktop && !registeredSessionIds.has(sessionId);
        const tool: SessionTool = isDesign ? 'claude_design' : 'claude_code';
        const projectName = sanitizeTaskText(cwd.split('/').filter(Boolean).at(-1));

        sessions.push({
          pid: 0,
          sessionId,
          cwd,
          startedAt,
          // Claude Code registers a live pid in ~/.claude/sessions; a missing
          // registration means the conversation is over. Design sessions have
          // no local process to check.
          alive: tool === 'claude_design' || aliveSessionIds.has(sessionId),
          tool,
          taskTitle: sanitizeTaskText(slug) ?? projectName,
          taskSummary: claudeProjectTaskSummary(recentEntries, sanitizeTaskText(slug) ?? projectName),
        });
      }
    }
  } catch {
    return [];
  }

  const best = new Map<string, SessionInfo>();
  for (const session of sessions) {
    const key = `${session.tool ?? 'session'}:${session.cwd}`;
    const existing = best.get(key);
    if (!existing || session.startedAt > existing.startedAt) {
      best.set(key, session);
    }
  }
  return Array.from(best.values());
}

function readOpenCodeSessions(): SessionInfo[] {
  if (!existsSync(OPENCODE_DB)) return [];

  const processes = readOpenCodeProcesses();
  if (processes.length === 0) return [];

  const cwds = Array.from(new Set(processes.map((p) => p.cwd)));
  const recordsByCwd = readLatestOpenCodeSessionsForDirectories(cwds);
  if (recordsByCwd.size === 0) return [];

  const sessionIds = Array.from(new Set(Array.from(recordsByCwd.values()).map((r) => r.sessionId)));
  const messagesBySession = readOpenCodeMessagesBySession(sessionIds);

  const sessionsById = new Map<string, SessionInfo>();
  for (const process of processes) {
    const record = recordsByCwd.get(process.cwd);
    if (!record) continue;

    const messages = messagesBySession.get(record.sessionId) ?? [];
    const session: SessionInfo = {
      pid: process.pid,
      sessionId: record.sessionId,
      cwd: record.cwd,
      startedAt: record.startedAt,
      alive: true,
      tool: 'open_code',
      taskTitle: record.taskTitle,
      taskSummary: openCodeTaskSummary(messages, record.taskTitle),
    };

    const existing = sessionsById.get(record.sessionId);
    if (!existing || session.startedAt >= existing.startedAt) {
      sessionsById.set(record.sessionId, session);
    }
  }

  return Array.from(sessionsById.values());
}

function readRecentClaudeProjectEntries(path: string, limit: number, maxBytes = 131_072): ClaudeProjectEntry[] {
  try {
    const raw = readFileSync(path);
    const tail = raw.subarray(Math.max(0, raw.length - maxBytes)).toString('utf-8');
    const entries: ClaudeProjectEntry[] = [];
    for (const line of tail.split(/\r?\n/).reverse()) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      try {
        entries.push(JSON.parse(trimmed) as ClaudeProjectEntry);
        if (entries.length === limit) break;
      } catch {
        // skip malformed lines
      }
    }
    return entries;
  } catch {
    return [];
  }
}

function decodeClaudeProjectDir(encoded: string): string {
  const path = encoded.startsWith('-') ? encoded.slice(1) : encoded;
  return `/${path.replaceAll('-', '/')}`;
}

function parseTimestampMs(raw: unknown): number | undefined {
  if (typeof raw !== 'string') return undefined;
  const parsed = Date.parse(raw);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function claudeProjectTaskSummary(
  recentEntries: ClaudeProjectEntry[],
  fallback?: string,
): string | undefined {
  for (const entry of recentEntries) {
    if (entry.type !== 'user' || !isGenuineUserPrompt(entry)) continue;
    const summary = extractText(entry.message ?? entry.content);
    if (summary && !summary.startsWith('<')) return summary;
  }
  return sanitizeTaskText(fallback);
}

// Transcript tool results and meta lines also carry type "user"; only a
// typed prompt should become the task summary.
function isGenuineUserPrompt(entry: ClaudeProjectEntry): boolean {
  if (entry.toolUseResult !== undefined) return false;
  if (entry.isMeta === true) return false;
  const message = entry.message;
  if (message && typeof message === 'object') {
    const content = (message as Record<string, unknown>).content;
    if (
      Array.isArray(content) &&
      content.some((block) => (block as Record<string, unknown>)?.type === 'tool_result')
    ) {
      return false;
    }
  }
  return true;
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

function readLatestOpenCodeSessionsForDirectories(cwds: string[]): Map<string, OpenCodeSessionRecord> {
  if (cwds.length === 0) return new Map();
  const quoted = cwds.map(quoteSQLite).join(',');
  const sql = [
    'select id, slug, directory, title, time_created',
    'from (',
    '  select id, slug, directory, title, time_created,',
    '         row_number() over (partition by directory order by time_updated desc) as rn',
    '  from session',
    `  where directory in (${quoted}) and time_archived is null`,
    ')',
    'where rn = 1;',
  ].join(' ');
  try {
    const output = execFileSync('sqlite3', ['-separator', '\t', OPENCODE_DB, sql], {
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    if (!output) return new Map();

    const recordsByCwd = new Map<string, OpenCodeSessionRecord>();
    for (const line of output.split(/\r?\n/)) {
      const [sessionId, slug, directory, title, createdAt] = line.split('\t');
      const startedAt = Number.parseInt(createdAt, 10);
      if (!sessionId || !directory || !Number.isFinite(startedAt)) continue;
      recordsByCwd.set(directory, {
        sessionId,
        cwd: directory,
        startedAt,
        taskTitle: openCodeTaskTitle(title, slug),
        taskSummary: undefined,
      });
    }
    return recordsByCwd;
  } catch {
    return new Map();
  }
}

function readOpenCodeMessagesBySession(sessionIds: string[], limit = 8): Map<string, OpenCodeMessage[]> {
  const unique = Array.from(new Set(sessionIds)).filter((id) => id.length > 0);
  if (unique.length === 0) return new Map();
  const quoted = unique.map(quoteSQLite).join(',');
  const sql = [
    'select session_id, data',
    'from (',
    '  select session_id, data,',
    '         row_number() over (partition by session_id order by time_updated desc) as rn',
    '  from message',
    `  where session_id in (${quoted})`,
    ')',
    `where rn <= ${limit}`,
    'order by session_id, rn;',
  ].join(' ');
  try {
    const output = execFileSync('sqlite3', ['-separator', '\t', OPENCODE_DB, sql], {
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    if (!output) return new Map();

    const result = new Map<string, OpenCodeMessage[]>();
    for (const line of output.split(/\r?\n/)) {
      const tabIdx = line.indexOf('\t');
      if (tabIdx < 0) continue;
      const sessionId = line.slice(0, tabIdx);
      const data = line.slice(tabIdx + 1);
      try {
        const message = JSON.parse(data) as OpenCodeMessage;
        const arr = result.get(sessionId);
        if (arr) arr.push(message);
        else result.set(sessionId, [message]);
      } catch {
        // skip malformed message
      }
    }
    return result;
  } catch {
    return new Map();
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

  const watcher = watch([CLAUDE_SESSIONS_DIR, CLAUDE_PROJECTS_DIR, OPENCODE_DIR], {
    persistent: true,
    ignoreInitial: true,
    depth: 2,
  });

  watcher.on('add', debouncedUpdate);
  watcher.on('change', debouncedUpdate);
  watcher.on('unlink', debouncedUpdate);

  return () => {
    clearTimeout(debounceTimer);
    watcher.close();
  };
}
