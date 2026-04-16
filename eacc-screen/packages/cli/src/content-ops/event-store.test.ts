import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { createPageViewEvent } from './contracts.js';
import {
  appendContentEvent,
  appendNewsletterLead,
  createNewsletterLeadCapture,
  readContentEventLog,
  readNewsletterLeads,
} from './event-store.js';

const tempDirs: string[] = [];

function makeTempDir(): string {
  const dir = mkdtempSync(join(tmpdir(), 'eacc-content-ops-'));
  tempDirs.push(dir);
  return dir;
}

afterEach(() => {
  while (tempDirs.length > 0) {
    const dir = tempDirs.pop();
    if (dir) rmSync(dir, { recursive: true, force: true });
  }
});

describe('content-ops/event-store', () => {
  it('appends ndjson event records for content analytics', () => {
    const dir = makeTempDir();
    const filePath = join(dir, 'content-events.ndjson');
    const event = createPageViewEvent({
      attribution: {
        path: '/workflow/claude-code',
        pageType: 'workflow',
        slug: 'claude-code',
      },
      engagementMs: 4200,
      scrollDepthPercent: 85,
    });

    appendContentEvent(event, filePath);
    const rows = readContentEventLog(filePath);

    expect(rows).toHaveLength(1);
    expect(rows[0].event.name).toBe('page_view');
    expect(rows[0].event.attribution.slug).toBe('claude-code');
  });

  it('stores hashed newsletter leads without raw email addresses', () => {
    const dir = makeTempDir();
    const filePath = join(dir, 'newsletter-leads.json');
    const lead = createNewsletterLeadCapture({
      email: 'builder@example.com',
      formId: 'newsletter-main',
      sourcePath: '/hub/ai-coding-workflows',
      cluster: 'ai-coding-workflows',
      consent: true,
      provider: 'buttondown',
    });

    appendNewsletterLead(lead, filePath);
    const leads = readNewsletterLeads(filePath);

    expect(leads).toHaveLength(1);
    expect(leads[0].sourcePath).toBe('/hub/ai-coding-workflows');
    expect(leads[0].emailHash).toMatch(/^[a-f0-9]{64}$/);
  });
});
