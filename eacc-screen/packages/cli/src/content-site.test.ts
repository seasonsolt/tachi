import { describe, expect, it } from 'vitest';
import {
  buildOpsReport,
  createContentRouteMap,
  hashEmail,
  isLabPath,
  isRitualPath,
  normalizeRoutePath,
  resolveContentRoute,
  type RouteManifest,
} from './content-site.js';

const manifest: RouteManifest = {
  generatedAt: '2026-04-16T00:00:00.000Z',
  domain: 'e-acc.ai',
  deferredDomains: ['e-accs.com'],
  contentRoutes: [
    {
      kind: 'home',
      path: '/',
      title: 'Home',
      description: 'desc',
      artifact: 'index.html',
      updatedAt: '2026-04-16',
      cluster: 'root',
      monetizationMode: ['ads', 'affiliate', 'newsletter'],
      cta: null,
      related: ['/ritual'],
      sourceFile: 'generated:home',
    },
    {
      kind: 'workflow',
      path: '/workflow/test-route',
      title: 'Workflow',
      description: 'desc',
      artifact: 'workflow/test-route/index.html',
      updatedAt: '2026-04-16',
      cluster: 'agent-operations',
      monetizationMode: ['ads', 'affiliate', 'newsletter'],
      cta: { type: 'affiliate', href: 'https://example.com', label: 'Try it' },
      related: ['/hub/agent-operations'],
      sourceFile: 'content/workflows/test.md',
    },
  ],
};

describe('content-site helpers', () => {
  it('normalizes and resolves content routes', () => {
    const routeMap = createContentRouteMap(manifest);
    expect(normalizeRoutePath('/workflow/test-route/')).toBe('/workflow/test-route');
    expect(resolveContentRoute(routeMap, '/workflow/test-route/')).toEqual(manifest.contentRoutes[1]);
  });

  it('detects ritual and lab paths', () => {
    expect(isRitualPath('/ritual')).toBe(true);
    expect(isRitualPath('/ritual/immersive')).toBe(true);
    expect(isLabPath('/lab')).toBe(true);
    expect(isLabPath('/lab/archive')).toBe(true);
    expect(isRitualPath('/workflow/test-route')).toBe(false);
  });

  it('hashes emails and aggregates analytics report output', () => {
    const report = buildOpsReport(manifest, {
      owner: 'content-ops',
      phaseOneDomain: 'e-acc.ai',
      deferredDomains: ['e-accs.com'],
      weeks: [{ weekStart: '2026-04-14', ads: 4, affiliate: 10, sponsorship: 0, other: 2 }],
    }, [
      { type: 'pageview', timestamp: '2026-04-16T00:00:00.000Z', route: '/workflow/test-route', cluster: 'agent-operations', kind: 'workflow' },
      { type: 'outbound_cta', timestamp: '2026-04-16T00:05:00.000Z', route: '/workflow/test-route', cluster: 'agent-operations', kind: 'workflow', href: 'https://example.com', ctaType: 'affiliate' },
      { type: 'newsletter_capture', timestamp: '2026-04-16T00:10:00.000Z', route: '/workflow/test-route', cluster: 'agent-operations', kind: 'workflow', emailHash: hashEmail('builder@example.com') },
    ]);

    expect(hashEmail('Builder@example.com')).toBe(hashEmail('builder@example.com'));
    expect(report.publishedPages).toBe(2);
    expect(report.revenue.monthlyRunRateUsd).toBe(16);
    expect(report.routes.find((entry) => entry.route === '/workflow/test-route')).toMatchObject({
      pageviews: 1,
      outboundCtaClicks: 1,
      newsletterCaptures: 1,
    });
  });
});
