import { EventEmitter } from 'node:events';
import { describe, expect, it, beforeEach, vi } from 'vitest';
import { WebSocket } from 'ws';
import type { MarketBuyerRequest } from '@eacc/shared';

const mockState = vi.hoisted(() => ({
  persisted: {
    listings: {} as Record<string, unknown>,
    blacklist: [] as string[],
  },
}));

vi.mock('./hub-store.js', () => ({
  createUsageLedger: () => ({
    requestCount: 0,
    totalTokens: 0,
    inputTokens: 0,
    outputTokens: 0,
    lastRequestAt: null,
    lastBuyerAlias: null,
  }),
  loadPersistedHubState: () => structuredClone(mockState.persisted),
  savePersistedHubState: (next: unknown) => {
    mockState.persisted = structuredClone(next as typeof mockState.persisted);
  },
}));

import { MarketHub } from './hub.js';

class FakeAgentSocket extends EventEmitter {
  readyState: number = WebSocket.OPEN;
  sent: string[] = [];

  send(payload: string): void {
    this.sent.push(payload);
    const parsed = JSON.parse(payload) as { type: string; requestId?: string; request?: MarketBuyerRequest };
    if (parsed.type === 'invoke' && parsed.requestId && parsed.request) {
      const request = parsed.request;
      queueMicrotask(() => {
        this.emit('message', JSON.stringify({
          type: 'invoke_result',
          requestId: parsed.requestId,
          response: {
            requestId: parsed.requestId,
            listingId: request.listingId,
            sellerAlias: 'thin',
            model: 'gpt-4o-mini',
            outputText: 'market rite accepted',
            usage: {
              totalTokens: 33,
              inputTokens: 21,
              outputTokens: 12,
            },
            latencyMs: 42,
            completedAt: Date.now(),
          },
        }));
      });
    }
  }

  close(): void {
    this.readyState = WebSocket.CLOSED;
    this.emit('close');
  }
}

describe('market hub', () => {
  beforeEach(() => {
    mockState.persisted = {
      listings: {},
      blacklist: [],
    };
  });

  it('registers a seller listing without persisting plaintext capability tokens', () => {
    const hub = new MarketHub();
    const socket = new FakeAgentSocket();
    hub.handleAgentConnection(socket as unknown as WebSocket);

    socket.emit('message', JSON.stringify({
      type: 'hello',
      listingId: 'listing-1',
      sellerId: 'seller-1',
      sellerAlias: 'thin',
      endpointHost: 'provider.example.com',
      model: 'gpt-4o-mini',
      publicNote: 'night capacity',
      capabilityToken: 'super-secret-capability',
      capabilityTokenPreview: 'super-se',
    }));

    const state = hub.getState();
    expect(state.listings).toHaveLength(1);
    expect(state.listings[0].sellerAlias).toBe('thin');
    expect(JSON.stringify(state)).not.toContain('super-secret-capability');
    expect(JSON.stringify(mockState.persisted)).not.toContain('super-secret-capability');
  });

  it('routes a buyer invocation through the connected seller agent', async () => {
    const hub = new MarketHub();
    const socket = new FakeAgentSocket();
    hub.handleAgentConnection(socket as unknown as WebSocket);

    socket.emit('message', JSON.stringify({
      type: 'hello',
      listingId: 'listing-1',
      sellerId: 'seller-1',
      sellerAlias: 'thin',
      endpointHost: 'provider.example.com',
      model: 'gpt-4o-mini',
      capabilityToken: 'super-secret-capability',
      capabilityTokenPreview: 'super-se',
    }));

    const response = await hub.requestBuyerInvocation({
      listingId: 'listing-1',
      prompt: 'hello vault market',
      buyerAlias: 'buyer-1',
    });

    expect(response.outputText).toBe('market rite accepted');
    expect(response.usage.totalTokens).toBe(33);
    expect(hub.getState().listings[0].requestCount).toBe(1);
  });

  it('rejects disabled listings', async () => {
    const hub = new MarketHub({ operatorControlsAvailable: true });
    const socket = new FakeAgentSocket();
    hub.handleAgentConnection(socket as unknown as WebSocket);

    socket.emit('message', JSON.stringify({
      type: 'hello',
      listingId: 'listing-1',
      sellerId: 'seller-1',
      sellerAlias: 'thin',
      endpointHost: 'provider.example.com',
      model: 'gpt-4o-mini',
      capabilityToken: 'super-secret-capability',
      capabilityTokenPreview: 'super-se',
    }));

    expect(hub.setListingDisabled('listing-1', true)).toBe(true);
    const response = await hub.requestBuyerInvocation({
      listingId: 'listing-1',
      prompt: 'hello vault market',
    });

    expect(response.error).toBe('Listing disabled');
  });
});
