import { randomUUID } from 'node:crypto';
import { WebSocket } from 'ws';
import type {
  MarketBuyerRequest,
  MarketBuyerResponse,
  MarketListing,
  MarketState,
} from '@eacc/shared';
import type {
  AgentHelloMessage,
  AgentToHubMessage,
  AgentInvokeErrorMessage,
  AgentInvokeResultMessage,
  HubToAgentMessage,
} from './protocol.js';
import { MARKET_REQUEST_TIMEOUT_MS } from './protocol.js';
import {
  createUsageLedger,
  loadPersistedHubState,
  savePersistedHubState,
  type PersistedHubState,
} from './hub-store.js';
import { createHash } from 'node:crypto';

interface PendingRequest {
  listingId: string;
  buyerAlias: string | null;
  resolve: (response: MarketBuyerResponse) => void;
  reject: (error: Error) => void;
  timeout: ReturnType<typeof setTimeout>;
}

interface MarketHubOptions {
  onStateChange?: () => void;
  operatorControlsAvailable?: boolean;
}

function tokenHash(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function asErrorResponse(
  requestId: string,
  listingId: string,
  error: string,
  listing?: Pick<MarketListing, 'sellerAlias' | 'model'>,
): MarketBuyerResponse {
  return {
    requestId,
    listingId,
    sellerAlias: listing?.sellerAlias || 'unknown',
    model: listing?.model || 'unknown',
    outputText: '',
    usage: {
      totalTokens: 0,
      inputTokens: 0,
      outputTokens: 0,
    },
    latencyMs: 0,
    completedAt: Date.now(),
    error,
  };
}

export class MarketHub {
  private persisted: PersistedHubState = loadPersistedHubState();
  private agentSockets = new Map<string, WebSocket>();
  private pending = new Map<string, PendingRequest>();

  constructor(private readonly options: MarketHubOptions = {}) {}

  getState(): MarketState {
    const listings = Object.values(this.persisted.listings)
      .map((record) => record.listing)
      .sort((a, b) => b.lastSeenAt - a.lastSeenAt);
    return {
      serverMode: 'hub',
      hubUrl: null,
      seller: null,
      listings,
      blacklist: [...this.persisted.blacklist],
      operatorControlsAvailable: !!this.options.operatorControlsAvailable,
    };
  }

  handleAgentConnection(ws: WebSocket): void {
    let listingIdForSocket: string | null = null;

    const closeHandler = () => {
      if (!listingIdForSocket) return;
      this.agentSockets.delete(listingIdForSocket);
      const record = this.persisted.listings[listingIdForSocket];
      if (record) {
        record.listing.status = record.listing.disabled ? 'disabled' : 'offline';
        record.listing.lastSeenAt = Date.now();
        this.persist();
      }
      for (const [requestId, pending] of this.pending.entries()) {
        if (pending.listingId === listingIdForSocket) {
          clearTimeout(pending.timeout);
          pending.reject(new Error('Seller agent disconnected'));
          this.pending.delete(requestId);
        }
      }
    };

    ws.on('message', (raw) => {
      try {
        const message = JSON.parse(String(raw)) as AgentToHubMessage;
        switch (message.type) {
          case 'hello': {
            listingIdForSocket = this.handleHello(ws, message);
            break;
          }
          case 'heartbeat': {
            this.touchListing(message.listingId);
            break;
          }
          case 'invoke_result': {
            this.handleInvokeResult(message);
            break;
          }
          case 'invoke_error': {
            this.handleInvokeError(message);
            break;
          }
        }
      } catch {
        ws.close();
      }
    });

    ws.on('close', closeHandler);
    ws.on('error', closeHandler);
  }

  async requestBuyerInvocation(request: MarketBuyerRequest): Promise<MarketBuyerResponse> {
    const record = this.persisted.listings[request.listingId];
    const requestId = randomUUID();
    if (!record) {
      return asErrorResponse(requestId, request.listingId, 'Listing not found');
    }
    if (record.listing.disabled) {
      return asErrorResponse(requestId, request.listingId, 'Listing disabled', record.listing);
    }
    const agent = this.agentSockets.get(request.listingId);
    if (!agent || agent.readyState !== WebSocket.OPEN) {
      return asErrorResponse(requestId, request.listingId, 'Seller agent offline', record.listing);
    }

    return new Promise<MarketBuyerResponse>((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pending.delete(requestId);
        reject(new Error('Timed out waiting for seller agent'));
      }, MARKET_REQUEST_TIMEOUT_MS);

      this.pending.set(requestId, {
        listingId: request.listingId,
        buyerAlias: request.buyerAlias || null,
        resolve,
        reject,
        timeout,
      });

      const message: HubToAgentMessage = {
        type: 'invoke',
        requestId,
        request,
      };
      agent.send(JSON.stringify(message));
    }).catch((error: Error) => {
      return asErrorResponse(requestId, request.listingId, error.message, record.listing);
    });
  }

  setListingDisabled(listingId: string, disabled: boolean): boolean {
    const record = this.persisted.listings[listingId];
    if (!record) return false;
    record.listing.disabled = disabled;
    if (disabled) {
      record.listing.status = 'disabled';
      if (!this.persisted.blacklist.includes(listingId)) {
        this.persisted.blacklist.push(listingId);
      }
      const agent = this.agentSockets.get(listingId);
      if (agent?.readyState === WebSocket.OPEN) {
        const message: HubToAgentMessage = {
          type: 'disable',
          listingId,
        };
        agent.send(JSON.stringify(message));
      }
    } else {
      this.persisted.blacklist = this.persisted.blacklist.filter((value) => value !== listingId);
      record.listing.status = this.agentSockets.get(listingId)?.readyState === WebSocket.OPEN ? 'online' : 'offline';
    }
    this.persist();
    return true;
  }

  private handleHello(ws: WebSocket, message: AgentHelloMessage): string {
    const existing = this.persisted.listings[message.listingId];
    const hash = tokenHash(message.capabilityToken);
    if (existing && existing.capabilityTokenHash !== hash) {
      ws.close();
      throw new Error('Capability token mismatch');
    }

    const usage = existing?.usage ?? createUsageLedger();
    const listing: MarketListing = {
      listingId: message.listingId,
      sellerId: message.sellerId,
      sellerAlias: message.sellerAlias,
      endpointHost: message.endpointHost,
      model: message.model,
      publicNote: message.publicNote,
      capabilityTokenPreview: message.capabilityTokenPreview,
      status: existing?.listing.disabled ? 'disabled' : 'online',
      disabled: existing?.listing.disabled ?? false,
      requestCount: usage.requestCount,
      totalTokens: usage.totalTokens,
      lastSeenAt: Date.now(),
      lastRequestAt: usage.lastRequestAt,
    };

    this.persisted.listings[message.listingId] = {
      listing,
      capabilityTokenHash: hash,
      usage,
    };
    this.agentSockets.set(message.listingId, ws);
    this.persist();
    if (listing.disabled && ws.readyState === WebSocket.OPEN) {
      const disableMessage: HubToAgentMessage = {
        type: 'disable',
        listingId: message.listingId,
      };
      ws.send(JSON.stringify(disableMessage));
    }
    return message.listingId;
  }

  private touchListing(listingId: string): void {
    const record = this.persisted.listings[listingId];
    if (!record) return;
    if (!record.listing.disabled) {
      record.listing.status = 'online';
    }
    record.listing.lastSeenAt = Date.now();
    this.persist();
  }

  private handleInvokeResult(message: AgentInvokeResultMessage): void {
    const pending = this.pending.get(message.requestId);
    if (!pending) return;
    clearTimeout(pending.timeout);
    this.pending.delete(message.requestId);

    const record = this.persisted.listings[message.response.listingId];
    if (record) {
      record.usage.requestCount += 1;
      record.usage.totalTokens += message.response.usage.totalTokens;
      record.usage.inputTokens += message.response.usage.inputTokens;
      record.usage.outputTokens += message.response.usage.outputTokens;
      record.usage.lastRequestAt = message.response.completedAt;
      record.usage.lastBuyerAlias = pending.buyerAlias;
      record.listing.requestCount = record.usage.requestCount;
      record.listing.totalTokens = record.usage.totalTokens;
      record.listing.lastRequestAt = record.usage.lastRequestAt;
      record.listing.lastSeenAt = Date.now();
      if (!record.listing.disabled) {
        record.listing.status = 'online';
      }
      this.persist();
    }

    pending.resolve(message.response);
  }

  private handleInvokeError(message: AgentInvokeErrorMessage): void {
    const pending = this.pending.get(message.requestId);
    if (!pending) return;
    clearTimeout(pending.timeout);
    this.pending.delete(message.requestId);
    const record = this.persisted.listings[message.listingId];
    pending.resolve(asErrorResponse(message.requestId, message.listingId, message.error, record?.listing));
  }

  private persist(): void {
    savePersistedHubState(this.persisted);
    this.options.onStateChange?.();
  }
}
