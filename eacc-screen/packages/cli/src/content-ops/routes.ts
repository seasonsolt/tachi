import { Hono } from 'hono';
import { getConnInfo } from '@hono/node-server/conninfo';
import type { ContentEvent, ContentEventSource, ContentPageType, RevenueSource } from './contracts.js';
import {
  CONTENT_EVENT_ENDPOINT,
  CONTENT_EVENT_NAMES,
  CONTENT_PAGE_TYPES,
  CTA_MONETIZATION_TYPES,
  CTA_PLACEMENTS,
  NEWSLETTER_CAPTURE_ENDPOINT,
  PHASE_ONE_DOMAIN,
  REVENUE_LEDGER_ENDPOINT,
  REVENUE_SOURCES,
  createContentEventId,
  createNewsletterSignupEvent,
  createRevenueRecordedEvent,
  getWeekStart,
  normalizeContentPath,
  roundCurrency,
  toIsoTimestamp,
} from './contracts.js';
import {
  appendContentEvent,
  appendNewsletterLead,
  createNewsletterLeadCapture,
} from './event-store.js';
import { appendRevenueLedgerEntry, createRevenueLedgerEntry } from './revenue-ledger.js';

const CONTENT_EVENT_SOURCES = ['browser', 'server', 'manual'] as const;

type JsonRecord = Record<string, unknown>;

export interface ContentOpsRouteOptions {
  eventLogFile?: string;
  newsletterLeadsFile?: string;
  revenueLedgerFile?: string;
  defaultRevenueRecorder?: string;
  writeToken?: string;
}

export interface NewsletterCaptureRequest {
  email: string;
  formId: string;
  sourcePath: string;
  pageType: ContentPageType;
  cluster?: string;
  slug?: string;
  title?: string;
  canonicalUrl?: string;
  consent: boolean;
  provider?: string;
  occurredAt?: string | number | Date;
  referrerPath?: string;
  sessionId?: string;
  userAgent?: string;
  source?: ContentEventSource;
  tags?: string[];
}

export interface RevenueLedgerRequest {
  source: RevenueSource;
  amountUSD: number;
  recordedBy: string;
  occurredAt?: string | number | Date;
  weekStart?: string;
  attributedPath: string;
  pageType: ContentPageType;
  cluster?: string;
  slug?: string;
  title?: string;
  canonicalUrl?: string;
  notes?: string;
  evidenceUrl?: string;
  ctaId?: string;
  sourceEvent: ContentEventSource;
  referrerPath?: string;
  sessionId?: string;
  userAgent?: string;
}

export function registerContentOpsRoutes(
  app: Hono,
  options: ContentOpsRouteOptions = {},
): void {
  const defaultRevenueRecorder = options.defaultRevenueRecorder ?? 'content-ops-api';
  const writeToken = options.writeToken ?? process.env.CONTENT_OPS_WRITE_TOKEN;

  app.post(CONTENT_EVENT_ENDPOINT, async (c) => {
    const authError = requireWriteAccess(
      c,
      c.req.header('host'),
      c.req.header('authorization'),
      c.req.header('x-content-ops-token'),
      writeToken,
    );
    if (authError) return c.json({ ok: false, error: authError }, 403);
    try {
      const payload = await c.req.json();
      const event = parseContentEventPayload(payload, c.req.header('user-agent') ?? undefined);
      appendContentEvent(event, options.eventLogFile);
      return c.json({ ok: true, eventId: event.eventId }, 201);
    } catch (error) {
      return c.json({ ok: false, error: formatRouteError(error) }, 400);
    }
  });

  app.post(NEWSLETTER_CAPTURE_ENDPOINT, async (c) => {
    const authError = requireWriteAccess(
      c,
      c.req.header('host'),
      c.req.header('authorization'),
      c.req.header('x-content-ops-token'),
      writeToken,
    );
    if (authError) return c.json({ ok: false, error: authError }, 403);
    try {
      const payload = parseNewsletterCapturePayload(await c.req.json(), c.req.header('user-agent') ?? undefined);
      const lead = createNewsletterLeadCapture({
        email: payload.email,
        formId: payload.formId,
        sourcePath: payload.sourcePath,
        cluster: payload.cluster,
        consent: payload.consent,
        provider: payload.provider,
        submittedAt: payload.occurredAt,
        tags: payload.tags,
      });
      const event = createNewsletterSignupEvent({
        attribution: {
          path: payload.sourcePath,
          pageType: payload.pageType,
          slug: payload.slug,
          cluster: payload.cluster,
          title: payload.title,
          canonicalUrl: payload.canonicalUrl,
        },
        formId: payload.formId,
        email: payload.email,
        consent: payload.consent,
        provider: payload.provider,
        occurredAt: payload.occurredAt,
        referrerPath: payload.referrerPath,
        sessionId: payload.sessionId,
        source: payload.source,
        userAgent: payload.userAgent,
      });

      appendNewsletterLead(lead, options.newsletterLeadsFile);
      appendContentEvent(event, options.eventLogFile);

      return c.json({
        ok: true,
        leadId: lead.leadId,
        eventId: event.eventId,
      }, 201);
    } catch (error) {
      return c.json({ ok: false, error: formatRouteError(error) }, 400);
    }
  });

  app.post(REVENUE_LEDGER_ENDPOINT, async (c) => {
    const authError = requireWriteAccess(
      c,
      c.req.header('host'),
      c.req.header('authorization'),
      c.req.header('x-content-ops-token'),
      writeToken,
    );
    if (authError) return c.json({ ok: false, error: authError }, 403);
    try {
      const payload = parseRevenueLedgerPayload(
        await c.req.json(),
        defaultRevenueRecorder,
        c.req.header('user-agent') ?? undefined,
      );
      const entry = createRevenueLedgerEntry({
        source: payload.source,
        amountUSD: payload.amountUSD,
        recordedBy: payload.recordedBy,
        recordedAt: payload.occurredAt,
        weekStart: payload.weekStart,
        attributedPath: payload.attributedPath,
        pageType: payload.pageType,
        cluster: payload.cluster,
        notes: payload.notes,
        evidenceUrl: payload.evidenceUrl,
        ctaId: payload.ctaId,
      });
      const ledger = appendRevenueLedgerEntry(entry, options.revenueLedgerFile);
      const event = createRevenueRecordedEvent({
        attribution: {
          path: payload.attributedPath,
          pageType: payload.pageType,
          slug: payload.slug,
          cluster: payload.cluster,
          title: payload.title,
          canonicalUrl: payload.canonicalUrl,
        },
        amountUSD: payload.amountUSD,
        sourceCategory: payload.source,
        occurredAt: payload.occurredAt,
        weekStart: payload.weekStart,
        evidenceUrl: payload.evidenceUrl,
        referrerPath: payload.referrerPath,
        sessionId: payload.sessionId,
        source: payload.sourceEvent,
        userAgent: payload.userAgent,
      });

      appendContentEvent(event, options.eventLogFile);

      return c.json({
        ok: true,
        entryId: entry.entryId,
        eventId: event.eventId,
        weeklySnapshots: ledger.weeklySnapshots,
      }, 201);
    } catch (error) {
      return c.json({ ok: false, error: formatRouteError(error) }, 400);
    }
  });
}

function requireWriteAccess(
  context: Parameters<typeof getConnInfo>[0],
  hostHeader: string | undefined,
  authorizationHeader: string | undefined,
  tokenHeader: string | undefined,
  writeToken: string | undefined,
): string | null {
  if (isLoopbackRequest(context) || isLocalHost(hostHeader)) return null;
  if (!writeToken) {
    return 'content-ops write endpoints require local access or CONTENT_OPS_WRITE_TOKEN';
  }

  const bearerToken = authorizationHeader?.startsWith('Bearer ')
    ? authorizationHeader.slice('Bearer '.length).trim()
    : undefined;
  if (tokenHeader === writeToken || bearerToken === writeToken) return null;

  return 'invalid content-ops write token';
}

function isLoopbackRequest(context: Parameters<typeof getConnInfo>[0]): boolean {
  try {
    const address = getConnInfo(context).remote.address;
    return address === '127.0.0.1' || address === '::1' || address === '::ffff:127.0.0.1';
  } catch {
    return false;
  }
}

function isLocalHost(hostHeader: string | undefined): boolean {
  if (!hostHeader) return false;
  const host = hostHeader.toLowerCase().split(':')[0];
  return host === 'localhost' || host === '127.0.0.1' || host === '::1' || host === '[::1]';
}

function formatRouteError(error: unknown): string {
  return error instanceof Error ? error.message : 'Invalid request payload';
}

function parseContentEventPayload(payload: unknown, fallbackUserAgent?: string): ContentEvent {
  const record = asRecord(payload, 'content event');
  const name = asEnum(readRequiredString(record, 'name'), CONTENT_EVENT_NAMES, 'name');
  const attribution = parseAttribution(readRecord(record, 'attribution'), 'attribution');
  const base = {
    eventId: readOptionalString(record, 'eventId') ?? createContentEventId(),
    name,
    occurredAt: readOptionalDate(record, 'occurredAt') ?? toIsoTimestamp(),
    source: parseContentEventSource(readOptionalString(record, 'source')) ?? 'browser',
    attribution,
    referrerPath: normalizeOptionalPath(readOptionalString(record, 'referrerPath')),
    sessionId: readOptionalString(record, 'sessionId'),
    userAgent: readOptionalString(record, 'userAgent') ?? fallbackUserAgent,
  } as const;

  switch (name) {
    case 'page_view':
      return {
        ...base,
        name,
        engagementMs: readOptionalNumber(record, 'engagementMs'),
        scrollDepthPercent: readOptionalNumber(record, 'scrollDepthPercent'),
      };
    case 'cta_click':
      return {
        ...base,
        name,
        ctaId: readRequiredString(record, 'ctaId'),
        ctaLabel: readRequiredString(record, 'ctaLabel'),
        destination: readRequiredString(record, 'destination'),
        placement: asEnum(readRequiredString(record, 'placement'), CTA_PLACEMENTS, 'placement'),
        monetization: asEnum(readRequiredString(record, 'monetization'), CTA_MONETIZATION_TYPES, 'monetization'),
        campaign: readOptionalString(record, 'campaign'),
      };
    case 'newsletter_signup':
      return {
        ...base,
        name,
        formId: readRequiredString(record, 'formId'),
        emailHash: readRequiredString(record, 'emailHash'),
        consent: readBoolean(record, 'consent'),
        provider: readOptionalString(record, 'provider'),
      };
    case 'ad_impression':
      return {
        ...base,
        name,
        slotId: readRequiredString(record, 'slotId'),
        provider: readOptionalString(record, 'provider'),
      };
    case 'revenue_recorded':
      return {
        ...base,
        name,
        sourceCategory: asEnum(readRequiredString(record, 'sourceCategory'), REVENUE_SOURCES, 'sourceCategory'),
        amountUSD: roundCurrency(readRequiredNumber(record, 'amountUSD')),
        weekStart: readOptionalString(record, 'weekStart') ?? getWeekStart(base.occurredAt),
        evidenceUrl: readOptionalString(record, 'evidenceUrl'),
      };
  }
}

function parseNewsletterCapturePayload(
  payload: unknown,
  fallbackUserAgent?: string,
): NewsletterCaptureRequest {
  const record = asRecord(payload, 'newsletter capture');
  return {
    email: readRequiredString(record, 'email'),
    formId: readRequiredString(record, 'formId'),
    sourcePath: normalizeContentPath(readRequiredString(record, 'sourcePath')),
    pageType: asEnum(readRequiredString(record, 'pageType'), CONTENT_PAGE_TYPES, 'pageType'),
    cluster: readOptionalString(record, 'cluster'),
    slug: readOptionalString(record, 'slug'),
    title: readOptionalString(record, 'title'),
    canonicalUrl: readOptionalString(record, 'canonicalUrl'),
    consent: readBoolean(record, 'consent'),
    provider: readOptionalString(record, 'provider'),
    occurredAt: readOptionalDate(record, 'occurredAt'),
    referrerPath: normalizeOptionalPath(readOptionalString(record, 'referrerPath')),
    sessionId: readOptionalString(record, 'sessionId'),
    userAgent: readOptionalString(record, 'userAgent') ?? fallbackUserAgent,
    source: parseContentEventSource(readOptionalString(record, 'source')) ?? 'browser',
    tags: readOptionalStringArray(record, 'tags'),
  };
}

function parseRevenueLedgerPayload(
  payload: unknown,
  defaultRevenueRecorder: string,
  fallbackUserAgent?: string,
): RevenueLedgerRequest {
  const record = asRecord(payload, 'revenue ledger entry');
  return {
    source: asEnum(readRequiredString(record, 'source'), REVENUE_SOURCES, 'source'),
    amountUSD: roundCurrency(readRequiredNumber(record, 'amountUSD')),
    recordedBy: readOptionalString(record, 'recordedBy') ?? defaultRevenueRecorder,
    occurredAt: readOptionalDate(record, 'occurredAt'),
    weekStart: readOptionalString(record, 'weekStart'),
    attributedPath: normalizeOptionalPath(readOptionalString(record, 'attributedPath')) ?? '/',
    pageType: parseOptionalPageType(readOptionalString(record, 'pageType')) ?? 'home',
    cluster: readOptionalString(record, 'cluster'),
    slug: readOptionalString(record, 'slug'),
    title: readOptionalString(record, 'title'),
    canonicalUrl: readOptionalString(record, 'canonicalUrl'),
    notes: readOptionalString(record, 'notes'),
    evidenceUrl: readOptionalString(record, 'evidenceUrl'),
    ctaId: readOptionalString(record, 'ctaId'),
    sourceEvent: parseContentEventSource(readOptionalString(record, 'sourceEvent')) ?? 'manual',
    referrerPath: normalizeOptionalPath(readOptionalString(record, 'referrerPath')),
    sessionId: readOptionalString(record, 'sessionId'),
    userAgent: readOptionalString(record, 'userAgent') ?? fallbackUserAgent,
  };
}

function parseAttribution(record: JsonRecord, label: string) {
  const domain = readOptionalString(record, 'domain');
  if (domain && domain !== PHASE_ONE_DOMAIN) {
    throw new Error(`${label}.domain must be ${PHASE_ONE_DOMAIN}`);
  }

  return {
    domain: PHASE_ONE_DOMAIN,
    path: normalizeContentPath(readRequiredString(record, 'path')),
    pageType: asEnum(readRequiredString(record, 'pageType'), CONTENT_PAGE_TYPES, 'pageType'),
    slug: readOptionalString(record, 'slug'),
    cluster: readOptionalString(record, 'cluster'),
    title: readOptionalString(record, 'title'),
    canonicalUrl: readOptionalString(record, 'canonicalUrl'),
  };
}

function parseContentEventSource(value: string | undefined): ContentEventSource | undefined {
  return value ? asEnum(value, CONTENT_EVENT_SOURCES, 'source') : undefined;
}

function parseOptionalPageType(value: string | undefined): ContentPageType | undefined {
  return value ? asEnum(value, CONTENT_PAGE_TYPES, 'pageType') : undefined;
}

function normalizeOptionalPath(value: string | undefined): string | undefined {
  return value ? normalizeContentPath(value) : undefined;
}

function asRecord(value: unknown, label: string): JsonRecord {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  return value as JsonRecord;
}

function readRecord(record: JsonRecord, field: string): JsonRecord {
  return asRecord(record[field], field);
}

function readRequiredString(record: JsonRecord, field: string): string {
  const value = record[field];
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${field} must be a non-empty string`);
  }
  return value.trim();
}

function readOptionalString(record: JsonRecord, field: string): string | undefined {
  const value = record[field];
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value !== 'string') {
    throw new Error(`${field} must be a string`);
  }
  return value.trim();
}

function readRequiredNumber(record: JsonRecord, field: string): number {
  const value = record[field];
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new Error(`${field} must be a finite number`);
  }
  return value;
}

function readOptionalNumber(record: JsonRecord, field: string): number | undefined {
  const value = record[field];
  if (value === undefined || value === null) return undefined;
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new Error(`${field} must be a finite number`);
  }
  return value;
}

function readBoolean(record: JsonRecord, field: string): boolean {
  const value = record[field];
  if (typeof value !== 'boolean') {
    throw new Error(`${field} must be a boolean`);
  }
  return value;
}

function readOptionalStringArray(record: JsonRecord, field: string): string[] | undefined {
  const value = record[field];
  if (value === undefined || value === null) return undefined;
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) {
    throw new Error(`${field} must be an array of strings`);
  }
  return value.map((item) => item.trim()).filter(Boolean);
}

function readOptionalDate(record: JsonRecord, field: string): string | undefined {
  const value = record[field];
  if (value === undefined || value === null) return undefined;
  return toIsoTimestamp(value as string | number | Date);
}

function asEnum<const T extends readonly string[]>(
  value: string,
  allowed: T,
  field: string,
): T[number] {
  if (!(allowed as readonly string[]).includes(value)) {
    throw new Error(`${field} must be one of: ${allowed.join(', ')}`);
  }
  return value as T[number];
}
