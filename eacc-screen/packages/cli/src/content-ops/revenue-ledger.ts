import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import type {
  ContentPageType,
  RevenueLedgerEntry,
  RevenueLedgerFile,
  RevenueSource,
  WeeklyRevenueSnapshot,
} from './contracts.js';
import {
  PHASE_ONE_DOMAIN,
  createContentEventId,
  createRevenueTotalsBySource,
  getWeekStart,
  normalizeContentPath,
  roundCurrency,
  toIsoTimestamp,
} from './contracts.js';

export const DEFAULT_REVENUE_LEDGER_FILE = join(homedir(), '.eacc', 'content-ops', 'weekly-revenue-ledger.json');

export interface RevenueLedgerEntryInput {
  source: RevenueSource;
  amountUSD: number;
  recordedBy: string;
  recordedAt?: string | number | Date;
  weekStart?: string;
  attributedPath?: string;
  pageType?: ContentPageType;
  cluster?: string;
  notes?: string;
  evidenceUrl?: string;
  ctaId?: string;
  entryId?: string;
}

export function createEmptyRevenueLedger(): RevenueLedgerFile {
  return {
    version: 1,
    domain: PHASE_ONE_DOMAIN,
    updatedAt: toIsoTimestamp(),
    entries: [],
    weeklySnapshots: [],
  };
}

export function createRevenueLedgerEntry(input: RevenueLedgerEntryInput): RevenueLedgerEntry {
  const recordedAt = toIsoTimestamp(input.recordedAt);
  return {
    entryId: input.entryId ?? createContentEventId(),
    weekStart: input.weekStart ?? getWeekStart(recordedAt),
    recordedAt,
    source: input.source,
    amountUSD: roundCurrency(input.amountUSD),
    domain: PHASE_ONE_DOMAIN,
    attributedPath: input.attributedPath ? normalizeContentPath(input.attributedPath) : undefined,
    pageType: input.pageType,
    cluster: input.cluster,
    notes: input.notes,
    evidenceUrl: input.evidenceUrl,
    recordedBy: input.recordedBy,
    ctaId: input.ctaId,
  };
}

export function buildWeeklyRevenueSnapshots(entries: RevenueLedgerEntry[]): WeeklyRevenueSnapshot[] {
  const grouped = new Map<string, RevenueLedgerEntry[]>();

  for (const entry of entries) {
    const bucket = grouped.get(entry.weekStart);
    if (bucket) {
      bucket.push(entry);
    } else {
      grouped.set(entry.weekStart, [entry]);
    }
  }

  return Array.from(grouped.entries())
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([weekStart, bucket]) => {
      const totalsBySource = createRevenueTotalsBySource();
      for (const entry of bucket) {
        totalsBySource[entry.source] = roundCurrency(totalsBySource[entry.source] + entry.amountUSD);
      }
      const totalUSD = roundCurrency(bucket.reduce((sum, entry) => sum + entry.amountUSD, 0));
      return {
        weekStart,
        totalsBySource,
        totalUSD,
        entryCount: bucket.length,
      };
    });
}

export function hydrateRevenueLedger(entries: RevenueLedgerEntry[]): RevenueLedgerFile {
  return {
    version: 1,
    domain: PHASE_ONE_DOMAIN,
    updatedAt: toIsoTimestamp(),
    entries: [...entries].sort((left, right) => left.recordedAt.localeCompare(right.recordedAt)),
    weeklySnapshots: buildWeeklyRevenueSnapshots(entries),
  };
}

export function readRevenueLedger(filePath: string = DEFAULT_REVENUE_LEDGER_FILE): RevenueLedgerFile {
  if (!existsSync(filePath)) return createEmptyRevenueLedger();

  const raw = JSON.parse(readFileSync(filePath, 'utf-8')) as Partial<RevenueLedgerFile>;
  if (!Array.isArray(raw.entries)) return createEmptyRevenueLedger();
  return hydrateRevenueLedger(raw.entries);
}

export function writeRevenueLedger(
  ledger: RevenueLedgerFile,
  filePath: string = DEFAULT_REVENUE_LEDGER_FILE,
): void {
  mkdirSync(dirname(filePath), { recursive: true });
  const normalized = hydrateRevenueLedger(ledger.entries);
  writeFileSync(filePath, JSON.stringify(normalized, null, 2) + '\n', 'utf-8');
}

export function appendRevenueLedgerEntry(
  entry: RevenueLedgerEntry,
  filePath: string = DEFAULT_REVENUE_LEDGER_FILE,
): RevenueLedgerFile {
  const current = readRevenueLedger(filePath);
  const next = hydrateRevenueLedger([...current.entries, entry]);
  writeRevenueLedger(next, filePath);
  return next;
}
