import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { Hono } from 'hono';
import { readContentEventLog, readNewsletterLeads } from './event-store.js';
import { readRevenueLedger } from './revenue-ledger.js';
import { registerContentOpsRoutes } from './routes.js';

const tempDirs: string[] = [];

function makeTempDir(): string {
  const dir = mkdtempSync(join(tmpdir(), 'eacc-content-routes-'));
  tempDirs.push(dir);
  return dir;
}

afterEach(() => {
  while (tempDirs.length > 0) {
    const dir = tempDirs.pop();
    if (dir) rmSync(dir, { recursive: true, force: true });
  }
});

function makeApp(dir: string): Hono {
  const app = new Hono();
  registerContentOpsRoutes(app, {
    eventLogFile: join(dir, 'content-events.ndjson'),
    newsletterLeadsFile: join(dir, 'newsletter-leads.json'),
    revenueLedgerFile: join(dir, 'weekly-revenue-ledger.json'),
    defaultRevenueRecorder: 'worker-4',
  });
  return app;
}

function makeProtectedApp(dir: string): Hono {
  const app = new Hono();
  registerContentOpsRoutes(app, {
    eventLogFile: join(dir, 'content-events.ndjson'),
    newsletterLeadsFile: join(dir, 'newsletter-leads.json'),
    revenueLedgerFile: join(dir, 'weekly-revenue-ledger.json'),
    defaultRevenueRecorder: 'worker-4',
    writeToken: 'secret-token',
  });
  return app;
}

describe('content-ops/routes', () => {
  it('accepts validated content events and appends them to the ndjson log', async () => {
    const dir = makeTempDir();
    const app = makeApp(dir);

    const response = await app.request('/api/content/events', {
      method: 'POST',
      headers: { 'content-type': 'application/json', host: 'localhost' },
      body: JSON.stringify({
        name: 'cta_click',
        attribution: {
          domain: 'e-acc.ai',
          path: '/workflow/claude-code',
          pageType: 'workflow',
          slug: 'claude-code',
        },
        ctaId: 'cta-claude-code',
        ctaLabel: 'Try Claude Code',
        destination: 'https://affiliate.example/claude-code',
        placement: 'inline',
        monetization: 'affiliate',
      }),
    });

    expect(response.status).toBe(201);
    const body = await response.json();
    expect(body.ok).toBe(true);

    const rows = readContentEventLog(join(dir, 'content-events.ndjson'));
    expect(rows).toHaveLength(1);
    expect(rows[0].event.name).toBe('cta_click');
    expect(rows[0].event.attribution.path).toBe('/workflow/claude-code');
  });

  it('captures newsletter leads and emits hashed signup events', async () => {
    const dir = makeTempDir();
    const app = makeApp(dir);

    const response = await app.request('/api/content/newsletter', {
      method: 'POST',
      headers: { 'content-type': 'application/json', host: 'localhost' },
      body: JSON.stringify({
        email: 'builder@example.com',
        formId: 'newsletter-main',
        sourcePath: '/hub/ai-coding-workflows',
        pageType: 'hub',
        cluster: 'ai-coding-workflows',
        consent: true,
        provider: 'buttondown',
      }),
    });

    expect(response.status).toBe(201);
    const body = await response.json();
    expect(body.ok).toBe(true);

    const leads = readNewsletterLeads(join(dir, 'newsletter-leads.json'));
    expect(leads).toHaveLength(1);
    expect(leads[0].emailHash).toMatch(/^[a-f0-9]{64}$/);

    const eventsRaw = readFileSync(join(dir, 'content-events.ndjson'), 'utf-8');
    expect(eventsRaw).not.toContain('builder@example.com');
    expect(eventsRaw).toContain('newsletter_signup');
  });

  it('records revenue entries and returns weekly snapshots', async () => {
    const dir = makeTempDir();
    const app = makeApp(dir);

    const response = await app.request('/api/content/revenue', {
      method: 'POST',
      headers: { 'content-type': 'application/json', host: 'localhost' },
      body: JSON.stringify({
        source: 'affiliate',
        amountUSD: 19.99,
        attributedPath: '/workflow/claude-code',
        pageType: 'workflow',
        cluster: 'ai-coding-workflows',
        ctaId: 'cta-claude-code',
      }),
    });

    expect(response.status).toBe(201);
    const body = await response.json();
    expect(body.ok).toBe(true);
    expect(body.weeklySnapshots).toHaveLength(1);

    const ledger = readRevenueLedger(join(dir, 'weekly-revenue-ledger.json'));
    expect(ledger.entries).toHaveLength(1);
    expect(ledger.entries[0].recordedBy).toBe('worker-4');
    expect(ledger.entries[0].amountUSD).toBe(19.99);
    expect(ledger.weeklySnapshots[0].totalsBySource.affiliate).toBe(19.99);
  });

  it('rejects non-local writes without the configured token', async () => {
    const dir = makeTempDir();
    const app = makeProtectedApp(dir);

    const response = await app.request('/api/content/events', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        host: 'e-acc.ai',
      },
      body: JSON.stringify({
        name: 'page_view',
        attribution: {
          path: '/workflow/claude-code',
          pageType: 'workflow',
        },
      }),
    });

    expect(response.status).toBe(403);
    const body = await response.json();
    expect(body.ok).toBe(false);
  });

  it('accepts token-authenticated non-local writes', async () => {
    const dir = makeTempDir();
    const app = makeProtectedApp(dir);

    const response = await app.request('/api/content/events', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        host: 'e-acc.ai',
        'x-content-ops-token': 'secret-token',
      },
      body: JSON.stringify({
        name: 'page_view',
        attribution: {
          path: '/workflow/claude-code',
          pageType: 'workflow',
        },
      }),
    });

    expect(response.status).toBe(201);
    const rows = readContentEventLog(join(dir, 'content-events.ndjson'));
    expect(rows).toHaveLength(1);
    expect(rows[0].event.name).toBe('page_view');
  });
});
