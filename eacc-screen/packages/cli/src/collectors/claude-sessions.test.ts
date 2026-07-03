import { mkdtempSync, mkdirSync, rmSync, utimesSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { readClaudeProjectSessions } from './claude-sessions.js';

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

    const sessions = readClaudeProjectSessions(projectsDir, 220_000);

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
