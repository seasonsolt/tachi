import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import {
  appendRevenueLedgerEntry,
  createRevenueLedgerEntry,
  readRevenueLedger,
} from './revenue-ledger.js';

const tempDirs: string[] = [];

function makeTempDir(): string {
  const dir = mkdtempSync(join(tmpdir(), 'eacc-revenue-ledger-'));
  tempDirs.push(dir);
  return dir;
}

afterEach(() => {
  while (tempDirs.length > 0) {
    const dir = tempDirs.pop();
    if (dir) rmSync(dir, { recursive: true, force: true });
  }
});

describe('content-ops/revenue-ledger', () => {
  it('creates ledger entries pinned to e-acc.ai phase-one metadata', () => {
    const entry = createRevenueLedgerEntry({
      source: 'affiliate',
      amountUSD: 12.349,
      recordedBy: 'worker-4',
      recordedAt: '2026-04-16T08:00:00Z',
      attributedPath: 'workflow/claude-code',
      pageType: 'workflow',
      cluster: 'ai-coding-workflows',
      ctaId: 'cta-compare',
    });

    expect(entry.domain).toBe('e-acc.ai');
    expect(entry.amountUSD).toBe(12.35);
    expect(entry.weekStart).toBe('2026-04-13');
    expect(entry.attributedPath).toBe('/workflow/claude-code');
  });

  it('writes weekly snapshots grouped by source', () => {
    const dir = makeTempDir();
    const filePath = join(dir, 'weekly-revenue-ledger.json');

    appendRevenueLedgerEntry(createRevenueLedgerEntry({
      source: 'affiliate',
      amountUSD: 10,
      recordedBy: 'worker-4',
      recordedAt: '2026-04-14T08:00:00Z',
      attributedPath: '/workflow/claude-code',
    }), filePath);
    appendRevenueLedgerEntry(createRevenueLedgerEntry({
      source: 'ads',
      amountUSD: 4.25,
      recordedBy: 'worker-4',
      recordedAt: '2026-04-16T08:00:00Z',
      attributedPath: '/hub/ai-coding-workflows',
    }), filePath);

    const ledger = readRevenueLedger(filePath);

    expect(ledger.entries).toHaveLength(2);
    expect(ledger.weeklySnapshots).toHaveLength(1);
    expect(ledger.weeklySnapshots[0].weekStart).toBe('2026-04-14'.replace('14', '13'));
    expect(ledger.weeklySnapshots[0].totalsBySource.affiliate).toBe(10);
    expect(ledger.weeklySnapshots[0].totalsBySource.ads).toBe(4.25);
    expect(ledger.weeklySnapshots[0].totalUSD).toBe(14.25);
  });
});
