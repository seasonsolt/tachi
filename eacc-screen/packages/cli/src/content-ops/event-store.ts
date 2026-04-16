import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import type { ContentEvent, NewsletterLeadCapture, NewsletterLeadStatus } from './contracts.js';
import {
  createContentEventId,
  hashNewsletterEmail,
  normalizeContentPath,
  toIsoTimestamp,
} from './contracts.js';

export const DEFAULT_CONTENT_OPS_DIR = join(homedir(), '.eacc', 'content-ops');
export const DEFAULT_CONTENT_EVENT_LOG_FILE = join(DEFAULT_CONTENT_OPS_DIR, 'content-events.ndjson');
export const DEFAULT_NEWSLETTER_LEADS_FILE = join(DEFAULT_CONTENT_OPS_DIR, 'newsletter-leads.json');

export interface ContentEventEnvelope {
  receivedAt: string;
  event: ContentEvent;
}

export interface NewsletterLeadCaptureInput {
  email: string;
  formId: string;
  sourcePath: string;
  cluster?: string;
  consent: boolean;
  provider?: string;
  submittedAt?: string | number | Date;
  leadId?: string;
  status?: NewsletterLeadStatus;
  tags?: string[];
}

interface NewsletterLeadsFile {
  version: 1;
  updatedAt: string;
  leads: NewsletterLeadCapture[];
}

export function ensureParentDir(filePath: string): void {
  mkdirSync(dirname(filePath), { recursive: true });
}

export function serializeContentEventRecord(
  event: ContentEvent,
  receivedAt: string = toIsoTimestamp(),
): string {
  return JSON.stringify({ receivedAt, event } satisfies ContentEventEnvelope) + '\n';
}

export function appendContentEvent(
  event: ContentEvent,
  filePath: string = DEFAULT_CONTENT_EVENT_LOG_FILE,
): void {
  ensureParentDir(filePath);
  appendFileSync(filePath, serializeContentEventRecord(event), 'utf-8');
}

export function readContentEventLog(
  filePath: string = DEFAULT_CONTENT_EVENT_LOG_FILE,
): ContentEventEnvelope[] {
  if (!existsSync(filePath)) return [];

  const raw = readFileSync(filePath, 'utf-8');
  return raw
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => JSON.parse(line) as ContentEventEnvelope);
}

export function createNewsletterLeadCapture(
  input: NewsletterLeadCaptureInput,
): NewsletterLeadCapture {
  return {
    leadId: input.leadId ?? createContentEventId(),
    submittedAt: toIsoTimestamp(input.submittedAt),
    emailHash: hashNewsletterEmail(input.email),
    formId: input.formId,
    sourcePath: normalizeContentPath(input.sourcePath),
    cluster: input.cluster,
    consent: input.consent,
    provider: input.provider,
    status: input.status ?? 'pending',
    tags: input.tags,
  };
}

function createNewsletterLeadsFile(leads: NewsletterLeadCapture[]): NewsletterLeadsFile {
  return {
    version: 1,
    updatedAt: toIsoTimestamp(),
    leads,
  };
}

export function readNewsletterLeads(
  filePath: string = DEFAULT_NEWSLETTER_LEADS_FILE,
): NewsletterLeadCapture[] {
  if (!existsSync(filePath)) return [];

  const raw = JSON.parse(readFileSync(filePath, 'utf-8')) as Partial<NewsletterLeadsFile>;
  return Array.isArray(raw.leads) ? raw.leads : [];
}

export function writeNewsletterLeads(
  leads: NewsletterLeadCapture[],
  filePath: string = DEFAULT_NEWSLETTER_LEADS_FILE,
): void {
  ensureParentDir(filePath);
  writeFileSync(filePath, JSON.stringify(createNewsletterLeadsFile(leads), null, 2) + '\n', 'utf-8');
}

export function appendNewsletterLead(
  lead: NewsletterLeadCapture,
  filePath: string = DEFAULT_NEWSLETTER_LEADS_FILE,
): NewsletterLeadCapture[] {
  const leads = readNewsletterLeads(filePath);
  leads.push(lead);
  writeNewsletterLeads(leads, filePath);
  return leads;
}
