import type { MarketListing, MarketUsageLedger } from '@eacc/shared';
import { MARKET_HUB_PATH, readJsonFile, writeJsonFile } from './storage.js';

export interface PersistedListingRecord {
  listing: MarketListing;
  capabilityTokenHash: string;
  usage: MarketUsageLedger;
}

export interface PersistedHubState {
  listings: Record<string, PersistedListingRecord>;
  blacklist: string[];
}

export function loadPersistedHubState(): PersistedHubState {
  return readJsonFile<PersistedHubState>(MARKET_HUB_PATH) ?? {
    listings: {},
    blacklist: [],
  };
}

export function savePersistedHubState(state: PersistedHubState): void {
  writeJsonFile(MARKET_HUB_PATH, state);
}

export function createUsageLedger(): MarketUsageLedger {
  return {
    requestCount: 0,
    totalTokens: 0,
    inputTokens: 0,
    outputTokens: 0,
    lastRequestAt: null,
    lastBuyerAlias: null,
  };
}
