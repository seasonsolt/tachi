import { mkdtempSync, mkdirSync, rmSync, utimesSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { readClaudeProjectSessions, readRegisteredClaudeSessionIds } from './claude-sessions.js';

const tempDirs: string[] = [];

function makeTempDir(): string {
  const dir = mkdtempSync(join(tmpdir(), 'eacc-claude-sessions-'));
  tempDirs.push(dir);
  return dir;
}

afterEach(() => {
  for (const dir of tempDirs.splice(0)) {
    rmSync(dir, { recursive: true, force: true });
  }
});

describe('readClaudeProjectSessions', () => {
  it('classifies Claude Desktop launched traces as Claude Design', () => {
    const projectsDir = makeTempDir();
    const projectDir = join(projectsDir, '-tmp-tachi-design');
    mkdirSync(projectDir, { recursive: true });

    const sessionPath = join(projectDir, 'design-1.jsonl');
    writeFileSync(
      sessionPath,
      '{"timestamp":"1970-01-01T00:03:20Z","type":"user","entrypoint":"claude-desktop","cwd":"/tmp/tachi-design","slug":"design-taskbar-popup","message":{"role":"user","content":"Design the taskbar popup"}}\n',
    );
    utimesSync(sessionPath, new Date(200_000), new Date(200_000));

    const sessions = readClaudeProjectSessions(projectsDir, 220_000, new Set());

    expect(sessions).toHaveLength(1);
    expect(sessions[0]).toMatchObject({
      pid: 0,
      sessionId: 'design-1',
      cwd: '/tmp/tachi-design',
      startedAt: 200_000,
      alive: true,
      tool: 'claude_design',
      taskTitle: 'design-taskbar-popup',
      taskSummary: 'Design the taskbar popup',
    });
  });

  it('keeps desktop-launched traces with a local session registration as Claude Code', () => {
    const projectsDir = makeTempDir();
    const projectDir = join(projectsDir, '-tmp-tachi');
    mkdirSync(projectDir, { recursive: true });

    const sessionPath = join(projectDir, 'desktop-code-1.jsonl');
    writeFileSync(
      sessionPath,
      '{"timestamp":"1970-01-01T00:03:20Z","type":"user","entrypoint":"claude-desktop","cwd":"/tmp/tachi","slug":"fix-monitor","message":"Fix the monitor"}\n',
    );
    utimesSync(sessionPath, new Date(200_000), new Date(200_000));

    const sessions = readClaudeProjectSessions(projectsDir, 220_000, new Set(['desktop-code-1']));

    expect(sessions).toHaveLength(1);
    expect(sessions[0]?.tool).toBe('claude_code');
  });

  it('reads registered session ids from the Claude sessions directory', () => {
    const sessionsDir = makeTempDir();
    writeFileSync(
      join(sessionsDir, '12345.json'),
      '{"pid":12345,"sessionId":"desktop-code-1","cwd":"/tmp/tachi","startedAt":1,"entrypoint":"claude-desktop"}',
    );
    writeFileSync(join(sessionsDir, 'broken.json'), '{not json');

    const ids = readRegisteredClaudeSessionIds(sessionsDir);

    expect(ids).toEqual(new Set(['desktop-code-1']));
  });

  it('marks Claude Code project traces without a live process as not alive', () => {
    const projectsDir = makeTempDir();
    const projectDir = join(projectsDir, '-tmp-tachi');
    mkdirSync(projectDir, { recursive: true });

    for (const name of ['closed-1', 'open-1']) {
      const sessionPath = join(projectDir, `${name}.jsonl`);
      writeFileSync(
        sessionPath,
        `{"timestamp":"1970-01-01T00:03:20Z","type":"user","cwd":"/tmp/tachi-${name}","slug":"${name}","message":"Work on ${name}"}\n`,
      );
      utimesSync(sessionPath, new Date(200_000), new Date(200_000));
    }

    const sessions = readClaudeProjectSessions(projectsDir, 220_000, new Set(), new Set(['open-1']));

    const byId = new Map(sessions.map((s) => [s.sessionId, s]));
    expect(byId.get('open-1')?.alive).toBe(true);
    expect(byId.get('closed-1')?.alive).toBe(false);
  });

  it('skips tool results and meta lines when picking the task summary', () => {
    const projectsDir = makeTempDir();
    const projectDir = join(projectsDir, '-tmp-tachi');
    mkdirSync(projectDir, { recursive: true });

    const sessionPath = join(projectDir, 'claude-2.jsonl');
    const lines = [
      '{"timestamp":"1970-01-01T00:03:00Z","type":"user","cwd":"/tmp/tachi","slug":"fix-popup","message":"Fix the glass popup"}',
      '{"timestamp":"1970-01-01T00:03:10Z","type":"assistant","cwd":"/tmp/tachi","slug":"fix-popup","message":{"role":"assistant","content":[{"type":"text","text":"On it"}]}}',
      '{"timestamp":"1970-01-01T00:03:20Z","type":"user","cwd":"/tmp/tachi","slug":"fix-popup","toolUseResult":{"stdout":"No xauth data"},"message":{"role":"user","content":[{"type":"tool_result","content":"No xauth data; using fake authentication data"}]}}',
    ];
    writeFileSync(sessionPath, `${lines.join('\n')}\n`);
    utimesSync(sessionPath, new Date(200_000), new Date(200_000));

    const sessions = readClaudeProjectSessions(projectsDir, 220_000, new Set());

    expect(sessions).toHaveLength(1);
    expect(sessions[0]?.taskSummary).toBe('Fix the glass popup');
  });

  it('keeps terminal Claude project traces as Claude Code', () => {
    const projectsDir = makeTempDir();
    const projectDir = join(projectsDir, '-tmp-tachi');
    mkdirSync(projectDir, { recursive: true });

    const sessionPath = join(projectDir, 'claude-1.jsonl');
    writeFileSync(
      sessionPath,
      '{"timestamp":"1970-01-01T00:03:20Z","type":"user","cwd":"/tmp/tachi","slug":"build-monitor","message":"Build the monitor"}\n',
    );
    utimesSync(sessionPath, new Date(200_000), new Date(200_000));

    const sessions = readClaudeProjectSessions(projectsDir, 220_000);

    expect(sessions).toHaveLength(1);
    expect(sessions[0]?.tool).toBe('claude_code');
  });
});
