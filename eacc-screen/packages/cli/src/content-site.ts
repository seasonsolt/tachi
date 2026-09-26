import { appendFileSync, existsSync, mkdirSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, join } from 'node:path';

export interface ContentRouteRecord {
  kind: string;
  path: string;
  title: string;
  description: string;
  artifact: string;
  updatedAt: string;
  cluster: string;
  monetizationMode: string[];
  status?: string;
  cta?: {
    type: string;
    href: string;
    label: string;
  } | null;
  related: string[];
  sourceFile: string;
}

export interface RouteManifest {
  generatedAt: string;
  domain: string;
  deferredDomains: string[];
  contentRoutes: ContentRouteRecord[];
  ritualRoutes?: Array<{
    path: string;
    strategy: string;
    target?: string;
  }>;
  analytics?: Record<string, string>;
}

export interface RevenueLedgerWeek {
  weekStart: string;
  ads: number;
  affiliate: number;
  sponsorship: number;
  other: number;
  notes?: string;
}

export interface RevenueLedger {
  owner: string;
  phaseOneDomain: string;
  deferredDomains: string[];
  weeks: RevenueLedgerWeek[];
}

export type AnalyticsEvent =
  | {
      type: 'page_view' | 'pageview';
      timestamp: string;
      route: string;
      cluster: string;
      kind: string;
      userAgent?: string;
    }
  | {
      type: 'cta_click' | 'outbound_cta';
      timestamp: string;
      route: string;
      cluster: string;
      kind: string;
      href: string;
      ctaType: string;
      userAgent?: string;
    }
  | {
      type: 'newsletter_signup' | 'newsletter_capture';
      timestamp: string;
      route: string;
      cluster: string;
      kind: string;
      emailHash: string;
      userAgent?: string;
    };

export function normalizeRoutePath(input: string): string {
  const raw = String(input || '').trim();
  if (!raw || raw === '/') return '/';
  const withLeadingSlash = raw.startsWith('/') ? raw : `/${raw}`;
  if (withLeadingSlash.length > 1 && withLeadingSlash.endsWith('/')) {
    return withLeadingSlash.slice(0, -1);
  }
  return withLeadingSlash;
}

export function isRitualPath(input: string): boolean {
  const normalized = normalizeRoutePath(input);
  return normalized === '/ritual' || normalized.startsWith('/ritual/');
}

export function isLabPath(input: string): boolean {
  const normalized = normalizeRoutePath(input);
  return normalized === '/lab' || normalized.startsWith('/lab/');
}

export function loadRouteManifest(siteRoot: string): RouteManifest | null {
  const manifestPath = join(siteRoot, 'route-manifest.json');
  if (!existsSync(manifestPath)) return null;
  return JSON.parse(readFileSync(manifestPath, 'utf8')) as RouteManifest;
}

export function createContentRouteMap(manifest: RouteManifest | null): Map<string, ContentRouteRecord> {
  return new Map((manifest?.contentRoutes ?? []).map((route) => [normalizeRoutePath(route.path), route]));
}

export function resolveContentRoute(routeMap: Map<string, ContentRouteRecord>, input: string): ContentRouteRecord | null {
  const normalized = normalizeRoutePath(input);
  return routeMap.get(normalized) ?? null;
}

export function loadRevenueLedger(siteRoot: string): RevenueLedger | null {
  const ledgerPath = join(siteRoot, 'ops', 'weekly-revenue-ledger.json');
  if (!existsSync(ledgerPath)) return null;
  return JSON.parse(readFileSync(ledgerPath, 'utf8')) as RevenueLedger;
}

export function writeAnalyticsEvent(logPath: string, event: AnalyticsEvent): void {
  mkdirSync(dirname(logPath), { recursive: true });
  appendFileSync(logPath, JSON.stringify(event) + '\n', 'utf8');
}

export function readAnalyticsEvents(logPath: string): AnalyticsEvent[] {
  if (!existsSync(logPath)) return [];
  return readFileSync(logPath, 'utf8')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .flatMap((line) => {
      try {
        return [JSON.parse(line) as AnalyticsEvent];
      } catch {
        return [];
      }
    });
}

export function hashEmail(email: string): string {
  return createHash('sha256').update(email.trim().toLowerCase()).digest('hex');
}

function sumLedgerWeeks(ledger: RevenueLedger | null, key: keyof RevenueLedgerWeek): number {
  return (ledger?.weeks ?? []).reduce((total, week) => total + Number(week[key] || 0), 0);
}

export function buildOpsReport(routeManifest: RouteManifest | null, ledger: RevenueLedger | null, events: AnalyticsEvent[]) {
  const routeSummaries = new Map<string, {
    pageviews: number;
    outboundCtaClicks: number;
    newsletterCaptures: number;
  }>();

  for (const route of routeManifest?.contentRoutes ?? []) {
    routeSummaries.set(route.path, { pageviews: 0, outboundCtaClicks: 0, newsletterCaptures: 0 });
  }

  const preservedRouteSummaries = new Map<string, { pageviews: number }>();
  for (const route of routeManifest?.ritualRoutes ?? []) {
    if (!route.path.includes('*')) {
      preservedRouteSummaries.set(route.path, { pageviews: 0 });
    }
  }

  for (const event of events) {
    const summary = routeSummaries.get(event.route);
    if (summary) {
      if (event.type === 'pageview' || event.type === 'page_view') summary.pageviews += 1;
      if (event.type === 'outbound_cta' || event.type === 'cta_click') summary.outboundCtaClicks += 1;
      if (event.type === 'newsletter_capture' || event.type === 'newsletter_signup') summary.newsletterCaptures += 1;
      routeSummaries.set(event.route, summary);
    }

    const preserved = preservedRouteSummaries.get(event.route);
    if (preserved && (event.type === 'pageview' || event.type === 'page_view')) {
      preserved.pageviews += 1;
    }
  }

  const clusterCounts = new Map<string, { published: number; pageviews: number; outboundCtaClicks: number; newsletterCaptures: number }>();
  for (const route of routeManifest?.contentRoutes ?? []) {
    const existing = clusterCounts.get(route.cluster) ?? { published: 0, pageviews: 0, outboundCtaClicks: 0, newsletterCaptures: 0 };
    existing.published += 1;
    const summary = routeSummaries.get(route.path);
    if (summary) {
      existing.pageviews += summary.pageviews;
      existing.outboundCtaClicks += summary.outboundCtaClicks;
      existing.newsletterCaptures += summary.newsletterCaptures;
    }
    clusterCounts.set(route.cluster, existing);
  }

  return {
    generatedAt: new Date().toISOString(),
    domain: routeManifest?.domain ?? null,
    deferredDomains: routeManifest?.deferredDomains ?? [],
    publishedPages: routeManifest?.contentRoutes.length ?? 0,
    routes: Array.from(routeSummaries.entries()).map(([route, summary]) => ({ route, ...summary })),
    preservedRoutes: Array.from(preservedRouteSummaries.entries()).map(([route, summary]) => ({ route, ...summary })),
    clusters: Array.from(clusterCounts.entries()).map(([cluster, summary]) => ({ cluster, ...summary })),
    revenue: {
      monthlyRunRateUsd: ['ads', 'affiliate', 'sponsorship', 'other'].reduce((total, key) => total + sumLedgerWeeks(ledger, key as keyof RevenueLedgerWeek), 0),
      mix: {
        ads: sumLedgerWeeks(ledger, 'ads'),
        affiliate: sumLedgerWeeks(ledger, 'affiliate'),
        sponsorship: sumLedgerWeeks(ledger, 'sponsorship'),
        other: sumLedgerWeeks(ledger, 'other'),
      },
    },
  };
}
