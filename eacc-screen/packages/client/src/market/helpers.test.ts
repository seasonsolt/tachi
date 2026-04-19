import { describe, expect, it } from 'vitest';
import { marketModeLabel, selectListingId } from './helpers';

describe('market helpers', () => {
  it('formats mode labels', () => {
    expect(marketModeLabel('hub')).toBe('PUBLIC HUB');
    expect(marketModeLabel('seller')).toBe('SELLER LOCAL');
    expect(marketModeLabel('standalone')).toBe('STANDALONE');
  });

  it('selects the first listing when there is no current selection', () => {
    const listingId = selectListingId([
      {
        listingId: 'listing-1',
        sellerId: 'seller-1',
        sellerAlias: 'thin',
        endpointHost: 'provider.example.com',
        model: 'gpt-4o-mini',
        capabilityTokenPreview: 'preview',
        status: 'online',
        disabled: false,
        requestCount: 0,
        totalTokens: 0,
        lastSeenAt: 1,
        lastRequestAt: null,
      },
    ], null);

    expect(listingId).toBe('listing-1');
  });
});
