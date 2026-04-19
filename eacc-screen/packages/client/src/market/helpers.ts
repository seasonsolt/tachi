import type { MarketListing, MarketServerMode } from '@eacc/shared';

export function marketModeLabel(mode: MarketServerMode | null | undefined): string {
  if (mode === 'hub') return 'PUBLIC HUB';
  if (mode === 'seller') return 'SELLER LOCAL';
  return 'STANDALONE';
}

export function selectListingId(
  listings: MarketListing[],
  current: string | null,
): string | null {
  if (!listings.length) return null;
  if (current && listings.some((listing) => listing.listingId === current)) {
    return current;
  }
  return listings[0].listingId;
}
