import { createHash, randomUUID } from 'node:crypto';

export const PHASE_ONE_DOMAIN = 'e-acc.ai' as const;

export const CONTENT_EVENT_ENDPOINT = '/api/content/events' as const;
export const NEWSLETTER_CAPTURE_ENDPOINT = '/api/content/newsletter' as const;
export const REVENUE_LEDGER_ENDPOINT = '/api/content/revenue' as const;

export const CONTENT_EVENT_NAMES = [
  'page_view',
  'cta_click',
  'newsletter_signup',
  'ad_impression',
  'revenue_recorded',
] as const;

export const CONTENT_PAGE_TYPES = [
  'home',
  'hub',
  'workflow',
  'comparison',
  'lab',
] as const;

export const CTA_PLACEMENTS = [
  'hero',
  'inline',
  'sidebar',
  'footer',
  'comparison_table',
  'newsletter',
  'lab',
] as const;

export const CTA_MONETIZATION_TYPES = [
  'affiliate',
  'internal',
  'newsletter',
  'sponsorship',
  'ads',
  'other',
] as const;

export const REVENUE_SOURCES = [
  'ads',
  'affiliate',
  'sponsorship',
  'other',
] as const;

export type ContentEventName = typeof CONTENT_EVENT_NAMES[number];
export type ContentPageType = typeof CONTENT_PAGE_TYPES[number];
export type CtaPlacement = typeof CTA_PLACEMENTS[number];
export type CtaMonetizationType = typeof CTA_MONETIZATION_TYPES[number];
export type RevenueSource = typeof REVENUE_SOURCES[number];
export type ContentEventSource = 'browser' | 'server' | 'manual';
export type NewsletterLeadStatus = 'pending' | 'confirmed' | 'rejected';

export interface ContentAttribution {
  domain: typeof PHASE_ONE_DOMAIN;
  path: string;
  pageType: ContentPageType;
  slug?: string;
  cluster?: string;
  title?: string;
  canonicalUrl?: string;
}

export interface ContentEventBase {
  eventId: string;
  name: ContentEventName;
  occurredAt: string;
  source: ContentEventSource;
  attribution: ContentAttribution;
  referrerPath?: string;
  sessionId?: string;
  userAgent?: string;
}

export interface PageViewEvent extends ContentEventBase {
  name: 'page_view';
  engagementMs?: number;
  scrollDepthPercent?: number;
}

export interface CtaClickEvent extends ContentEventBase {
  name: 'cta_click';
  ctaId: string;
  ctaLabel: string;
  destination: string;
  placement: CtaPlacement;
  monetization: CtaMonetizationType;
  campaign?: string;
}

export interface NewsletterSignupEvent extends ContentEventBase {
  name: 'newsletter_signup';
  formId: string;
  emailHash: string;
  consent: boolean;
  provider?: string;
}

export interface AdImpressionEvent extends ContentEventBase {
  name: 'ad_impression';
  slotId: string;
  provider?: string;
}

export interface RevenueRecordedEvent extends ContentEventBase {
  name: 'revenue_recorded';
  sourceCategory: RevenueSource;
  amountUSD: number;
  weekStart: string;
  evidenceUrl?: string;
}

export type ContentEvent =
  | PageViewEvent
  | CtaClickEvent
  | NewsletterSignupEvent
  | AdImpressionEvent
  | RevenueRecordedEvent;

export interface NewsletterLeadCapture {
  leadId: string;
  submittedAt: string;
  emailHash: string;
  formId: string;
  sourcePath: string;
  cluster?: string;
  consent: boolean;
  provider?: string;
  status: NewsletterLeadStatus;
  tags?: string[];
}

export interface RevenueLedgerEntry {
  entryId: string;
  weekStart: string;
  recordedAt: string;
  source: RevenueSource;
  amountUSD: number;
  domain: typeof PHASE_ONE_DOMAIN;
  attributedPath?: string;
  pageType?: ContentPageType;
  cluster?: string;
  notes?: string;
  evidenceUrl?: string;
  recordedBy: string;
  ctaId?: string;
}

export type RevenueTotalsBySource = Record<RevenueSource, number>;

export interface WeeklyRevenueSnapshot {
  weekStart: string;
  totalsBySource: RevenueTotalsBySource;
  totalUSD: number;
  entryCount: number;
}

export interface RevenueLedgerFile {
  version: 1;
  domain: typeof PHASE_ONE_DOMAIN;
  updatedAt: string;
  entries: RevenueLedgerEntry[];
  weeklySnapshots: WeeklyRevenueSnapshot[];
}

export interface ContentAttributionInput {
  path: string;
  pageType: ContentPageType;
  slug?: string;
  cluster?: string;
  title?: string;
  canonicalUrl?: string;
}

export interface ContentEventContextInput {
  eventId?: string;
  occurredAt?: string | number | Date;
  source?: ContentEventSource;
  referrerPath?: string;
  sessionId?: string;
  userAgent?: string;
  attribution: ContentAttributionInput;
}

export interface PageViewEventInput extends ContentEventContextInput {
  engagementMs?: number;
  scrollDepthPercent?: number;
}

export interface CtaClickEventInput extends ContentEventContextInput {
  ctaId: string;
  ctaLabel: string;
  destination: string;
  placement: CtaPlacement;
  monetization: CtaMonetizationType;
  campaign?: string;
}

export interface NewsletterSignupEventInput extends ContentEventContextInput {
  formId: string;
  email: string;
  consent: boolean;
  provider?: string;
}

export interface RevenueRecordedEventInput extends ContentEventContextInput {
  sourceCategory: RevenueSource;
  amountUSD: number;
  weekStart?: string;
  evidenceUrl?: string;
}

export function isContentEventName(value: string): value is ContentEventName {
  return (CONTENT_EVENT_NAMES as readonly string[]).includes(value);
}

export function isContentPageType(value: string): value is ContentPageType {
  return (CONTENT_PAGE_TYPES as readonly string[]).includes(value);
}

export function isRevenueSource(value: string): value is RevenueSource {
  return (REVENUE_SOURCES as readonly string[]).includes(value);
}

export function createContentEventId(): string {
  return randomUUID();
}

export function toIsoTimestamp(value: string | number | Date = new Date()): string {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid date value: ${String(value)}`);
  }
  return date.toISOString();
}

export function normalizeContentPath(input: string): string {
  const trimmed = input.trim();
  if (!trimmed) return '/';

  let candidate = trimmed;
  if (/^https?:\/\//i.test(trimmed)) {
    const url = new URL(trimmed);
    candidate = url.pathname;
  }

  const withoutHash = candidate.split('#', 1)[0] ?? '/';
  const withoutQuery = withoutHash.split('?', 1)[0] ?? '/';
  const withSlash = withoutQuery.startsWith('/') ? withoutQuery : `/${withoutQuery}`;
  const normalized = withSlash.replace(/\/+/g, '/');
  return normalized === '' ? '/' : normalized;
}

export function hashNewsletterEmail(email: string): string {
  return createHash('sha256').update(email.trim().toLowerCase()).digest('hex');
}

export function getWeekStart(value: string | number | Date): string {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid date value: ${String(value)}`);
  }

  const utcDate = new Date(Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate(),
  ));
  const day = utcDate.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  utcDate.setUTCDate(utcDate.getUTCDate() + diff);
  return utcDate.toISOString().slice(0, 10);
}

export function createRevenueTotalsBySource(): RevenueTotalsBySource {
  return {
    ads: 0,
    affiliate: 0,
    sponsorship: 0,
    other: 0,
  };
}

function normalizeAttribution(input: ContentAttributionInput): ContentAttribution {
  return {
    domain: PHASE_ONE_DOMAIN,
    path: normalizeContentPath(input.path),
    pageType: input.pageType,
    slug: input.slug,
    cluster: input.cluster,
    title: input.title,
    canonicalUrl: input.canonicalUrl,
  };
}

type ContentEventBaseForName<TName extends ContentEventName> = Omit<ContentEventBase, 'name'> & {
  name: TName;
};

function createEventBase<TName extends ContentEventName>(
  name: TName,
  input: ContentEventContextInput,
): ContentEventBaseForName<TName> {
  return {
    eventId: input.eventId ?? createContentEventId(),
    name,
    occurredAt: toIsoTimestamp(input.occurredAt),
    source: input.source ?? 'browser',
    attribution: normalizeAttribution(input.attribution),
    referrerPath: input.referrerPath ? normalizeContentPath(input.referrerPath) : undefined,
    sessionId: input.sessionId,
    userAgent: input.userAgent,
  };
}

export function createPageViewEvent(input: PageViewEventInput): PageViewEvent {
  return {
    ...createEventBase('page_view', input),
    engagementMs: input.engagementMs,
    scrollDepthPercent: input.scrollDepthPercent,
  };
}

export function createCtaClickEvent(input: CtaClickEventInput): CtaClickEvent {
  return {
    ...createEventBase('cta_click', input),
    ctaId: input.ctaId,
    ctaLabel: input.ctaLabel,
    destination: input.destination,
    placement: input.placement,
    monetization: input.monetization,
    campaign: input.campaign,
  };
}

export function createNewsletterSignupEvent(input: NewsletterSignupEventInput): NewsletterSignupEvent {
  return {
    ...createEventBase('newsletter_signup', input),
    formId: input.formId,
    emailHash: hashNewsletterEmail(input.email),
    consent: input.consent,
    provider: input.provider,
  };
}

export function createRevenueRecordedEvent(input: RevenueRecordedEventInput): RevenueRecordedEvent {
  const occurredAt = toIsoTimestamp(input.occurredAt);
  return {
    ...createEventBase('revenue_recorded', {
      ...input,
      occurredAt,
      source: input.source ?? 'manual',
    }),
    sourceCategory: input.sourceCategory,
    amountUSD: roundCurrency(input.amountUSD),
    weekStart: input.weekStart ?? getWeekStart(occurredAt),
    evidenceUrl: input.evidenceUrl,
  };
}

export function roundCurrency(amountUSD: number): number {
  return Math.round(amountUSD * 100) / 100;
}
