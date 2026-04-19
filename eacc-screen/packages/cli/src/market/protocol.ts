import type { MarketBuyerRequest, MarketBuyerResponse } from '@eacc/shared';

export const MARKET_AGENT_PATH = '/market-agent';
export const MARKET_REQUEST_TIMEOUT_MS = 20_000;
export const MARKET_HEARTBEAT_MS = 10_000;

export interface AgentHelloMessage {
  type: 'hello';
  listingId: string;
  sellerId: string;
  sellerAlias: string;
  endpointHost: string;
  model: string;
  publicNote?: string;
  capabilityToken: string;
  capabilityTokenPreview: string;
}

export interface AgentHeartbeatMessage {
  type: 'heartbeat';
  listingId: string;
}

export interface AgentInvokeResultMessage {
  type: 'invoke_result';
  requestId: string;
  response: MarketBuyerResponse;
}

export interface AgentInvokeErrorMessage {
  type: 'invoke_error';
  requestId: string;
  listingId: string;
  error: string;
}

export type AgentToHubMessage =
  | AgentHelloMessage
  | AgentHeartbeatMessage
  | AgentInvokeResultMessage
  | AgentInvokeErrorMessage;

export interface HubInvokeMessage {
  type: 'invoke';
  requestId: string;
  request: MarketBuyerRequest;
}

export interface HubDisableMessage {
  type: 'disable';
  listingId: string;
}

export type HubToAgentMessage = HubInvokeMessage | HubDisableMessage;
