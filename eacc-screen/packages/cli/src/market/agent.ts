import { WebSocket } from 'ws';
import type {
  EACCConfig,
  MarketBuyerResponse,
  MarketListingStatus,
  MarketSellerLocalConfig,
  MarketSellerSecretBundle,
  MarketSellerSummary,
} from '@eacc/shared';
import type {
  HubDisableMessage,
  HubInvokeMessage,
  HubToAgentMessage,
} from './protocol.js';
import {
  AgentToHubMessage,
  MARKET_AGENT_PATH,
  MARKET_HEARTBEAT_MS,
} from './protocol.js';

interface SellerAgentBridgeOptions {
  getConfig: () => EACCConfig;
  onStateChange?: () => void;
}

function toWebSocketUrl(hubUrl: string): string {
  const trimmed = hubUrl.trim();
  if (!trimmed) throw new Error('Missing hub URL');
  if (trimmed.startsWith('ws://') || trimmed.startsWith('wss://')) {
    return `${trimmed.replace(/\/$/, '')}${MARKET_AGENT_PATH}`;
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    const url = new URL(trimmed);
    url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
    url.pathname = MARKET_AGENT_PATH;
    url.search = '';
    url.hash = '';
    return url.toString();
  }
  return `ws://${trimmed.replace(/\/$/, '')}${MARKET_AGENT_PATH}`;
}

function extractOutputText(body: Record<string, unknown>): string {
  const choices = Array.isArray(body.choices) ? body.choices : [];
  const firstChoice = choices[0] as Record<string, unknown> | undefined;
  const message = firstChoice?.message as Record<string, unknown> | undefined;
  const content = message?.content;
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === 'string') return part;
        if (part && typeof part === 'object' && typeof (part as { text?: unknown }).text === 'string') {
          return String((part as { text: string }).text);
        }
        return '';
      })
      .join('')
      .trim();
  }
  return '';
}

function buildResponse(
  requestId: string,
  listing: MarketSellerLocalConfig,
  outputText: string,
  usage: { totalTokens: number; inputTokens: number; outputTokens: number },
  latencyMs: number,
  error?: string,
): MarketBuyerResponse {
  return {
    requestId,
    listingId: listing.listingId,
    sellerAlias: listing.sellerAlias,
    model: listing.model,
    outputText,
    usage,
    latencyMs,
    completedAt: Date.now(),
    error,
  };
}

export class SellerAgentBridge {
  private ws: WebSocket | null = null;
  private heartbeatTimer: ReturnType<typeof setInterval> | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private unlockedSecrets: MarketSellerSecretBundle | null = null;
  private disabledByOperator = false;
  private status: MarketListingStatus = 'locked';
  private lastError: string | null = null;

  constructor(private readonly options: SellerAgentBridgeOptions) {}

  getSummary(): MarketSellerSummary | null {
    const config = this.options.getConfig().market?.seller;
    if (!config) return null;
    return {
      sellerId: config.sellerId,
      listingId: config.listingId,
      sellerAlias: config.sellerAlias,
      endpoint: config.endpoint,
      endpointHost: config.endpointHost,
      model: config.model,
      publicNote: config.publicNote,
      hubUrl: this.options.getConfig().market?.hubUrl ?? null,
      status: !config.enabled || this.disabledByOperator ? 'disabled' : this.status,
      enabled: config.enabled,
      hasLocalVault: true,
      hasUnlockedSecret: !!this.unlockedSecrets,
      capabilityTokenPreview: config.capabilityTokenPreview,
      lastError: this.lastError,
    };
  }

  setUnlockedSecrets(secrets: MarketSellerSecretBundle | null): void {
    this.unlockedSecrets = secrets;
    if (secrets) {
      this.disabledByOperator = false;
    } else {
      this.status = 'locked';
    }
    this.refresh();
  }

  refresh(): void {
    if (!this.shouldConnect()) {
      this.disconnect();
      this.options.onStateChange?.();
      return;
    }

    if (this.ws?.readyState === WebSocket.OPEN || this.ws?.readyState === WebSocket.CONNECTING) {
      return;
    }

    this.connect();
  }

  close(): void {
    this.disconnect();
  }

  private shouldConnect(): boolean {
    const config = this.options.getConfig();
    return config.market?.mode === 'seller'
      && !!config.market.hubUrl
      && !!config.market.seller?.enabled
      && !this.disabledByOperator
      && !!this.unlockedSecrets;
  }

  private connect(): void {
    const config = this.options.getConfig();
    const listing = config.market?.seller;
    const hubUrl = config.market?.hubUrl;
    if (!listing || !hubUrl || !this.unlockedSecrets) return;

    this.status = 'connecting';
    this.lastError = null;
    this.options.onStateChange?.();

    const ws = new WebSocket(toWebSocketUrl(hubUrl));
    this.ws = ws;

    ws.on('open', () => {
      this.status = listing.enabled ? 'online' : 'disabled';
      this.sendHello(listing);
      this.startHeartbeat(listing.listingId);
      this.options.onStateChange?.();
    });

    ws.on('message', async (raw) => {
      try {
        const message = JSON.parse(String(raw)) as HubToAgentMessage;
        if (message.type === 'invoke') {
          await this.handleInvoke(message, listing);
        } else if (message.type === 'disable') {
          this.handleDisable(message);
        }
      } catch {
        // Ignore malformed market-agent messages.
      }
    });

    ws.on('close', () => {
      this.stopHeartbeat();
      this.ws = null;
      if (listing.enabled && this.unlockedSecrets) {
        this.status = 'offline';
        this.scheduleReconnect();
      }
      this.options.onStateChange?.();
    });

    ws.on('error', () => {
      this.lastError = 'Failed to reach market hub';
      ws.close();
      this.options.onStateChange?.();
    });
  }

  private sendHello(listing: MarketSellerLocalConfig): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN || !this.unlockedSecrets) return;
    const message: AgentToHubMessage = {
      type: 'hello',
      listingId: listing.listingId,
      sellerId: listing.sellerId,
      sellerAlias: listing.sellerAlias,
      endpointHost: listing.endpointHost,
      model: listing.model,
      publicNote: listing.publicNote,
      capabilityToken: this.unlockedSecrets.capabilityToken,
      capabilityTokenPreview: listing.capabilityTokenPreview,
    };
    this.ws.send(JSON.stringify(message));
  }

  private startHeartbeat(listingId: string): void {
    this.stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;
      const heartbeat: AgentToHubMessage = {
        type: 'heartbeat',
        listingId,
      };
      this.ws.send(JSON.stringify(heartbeat));
    }, MARKET_HEARTBEAT_MS);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer) return;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      if (this.shouldConnect()) {
        this.connect();
      }
    }, 2_000);
  }

  private disconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    this.stopHeartbeat();
    if (this.ws) {
      const socket = this.ws;
      this.ws = null;
      socket.close();
    }
  }

  private async handleInvoke(message: HubInvokeMessage, listing: MarketSellerLocalConfig): Promise<void> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN || !this.unlockedSecrets) return;
    const startedAt = Date.now();
    try {
      const response = await fetch(listing.endpoint, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.unlockedSecrets.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: listing.model,
          messages: [{ role: 'user', content: message.request.prompt }],
          max_tokens: message.request.maxTokens ?? 256,
        }),
      });

      const json = await response.json() as Record<string, unknown>;
      if (!response.ok) {
        const errorMessage = typeof json.error === 'string'
          ? json.error
          : `Upstream ${response.status}`;
        const payload: AgentToHubMessage = {
          type: 'invoke_error',
          requestId: message.requestId,
          listingId: listing.listingId,
          error: errorMessage,
        };
        this.ws.send(JSON.stringify(payload));
        return;
      }

      const usage = json.usage as Record<string, unknown> | undefined;
      const payload: AgentToHubMessage = {
        type: 'invoke_result',
        requestId: message.requestId,
        response: buildResponse(
          message.requestId,
          listing,
          extractOutputText(json),
          {
            totalTokens: Number(usage?.total_tokens ?? 0),
            inputTokens: Number(usage?.prompt_tokens ?? 0),
            outputTokens: Number(usage?.completion_tokens ?? 0),
          },
          Date.now() - startedAt,
        ),
      };
      this.ws.send(JSON.stringify(payload));
    } catch (error) {
      const payload: AgentToHubMessage = {
        type: 'invoke_error',
        requestId: message.requestId,
        listingId: listing.listingId,
        error: error instanceof Error ? error.message : 'Unknown invoke error',
      };
      this.ws.send(JSON.stringify(payload));
    }
  }

  private handleDisable(message: HubDisableMessage): void {
    const listing = this.options.getConfig().market?.seller;
    if (!listing || listing.listingId !== message.listingId) return;
    this.disabledByOperator = true;
    this.status = 'disabled';
    this.lastError = 'Listing disabled by operator';
    this.disconnect();
    this.options.onStateChange?.();
  }
}
