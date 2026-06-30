// === Data Types ===

export interface TokenData {
  /** Total tokens consumed across all sources */
  totalTokens: number;
  /** Total cost in USD */
  totalCostUSD: number;
  /** Tokens consumed today */
  todayTokens: number;
  /** Cost today in USD */
  todayCostUSD: number;
  /** Current tokens per second rate */
  tokensPerSecond: number;
  /** Monthly total tokens */
  monthTokens: number;
  /** Monthly cost in USD */
  monthCostUSD: number;
  /** Breakdown by source */
  sources: {
    claudeCode: SourceData;
    anthropicApi: SourceData;
    openaiApi: SourceData;
  };
  /** Timestamp of last update */
  lastUpdated: number;
}

export interface SourceData {
  connected: boolean;
  totalTokens: number;
  todayTokens: number;
  monthTokens: number;
  costUSD: number;
  todayCostUSD: number;
  monthCostUSD: number;
  inputTokens: number;
  outputTokens: number;
  lastUpdated: number;
}

// === Claude Code Stats ===

export interface ClaudeCodeStats {
  version: number;
  dailyActivity: Array<{
    date: string;
    messageCount: number;
    sessionCount: number;
    toolCallCount: number;
  }>;
  dailyModelTokens: Array<{
    date: string;
    tokensByModel: Record<string, number>;
  }>;
  modelUsage: Record<string, {
    inputTokens: number;
    outputTokens: number;
    cacheReadInputTokens: number;
    cacheCreationInputTokens: number;
    costUSD: number;
  }>;
  totalSessions: number;
  totalMessages: number;
  firstSessionDate: string;
}

// === Session Info ===

export type SessionTool = 'claude_code' | 'codex' | 'open_code' | 'pencil';

export interface SessionInfo {
  pid: number;
  sessionId: string;
  cwd: string;
  startedAt: number;
  alive: boolean;
  tool?: SessionTool;
  taskTitle?: string;
  taskSummary?: string;
}

// === WebSocket Messages ===

export type WSMessage =
  | { type: 'token_update'; data: TokenData }
  | { type: 'milestone'; milestone: Milestone }
  | { type: 'error'; source: string; message: string }
  | { type: 'connected'; sources: string[] }
  | { type: 'session_update'; sessions: SessionInfo[] }
  | { type: 'theme_change'; theme: ThemeName }
  | { type: 'market_state'; market: MarketState };

export type WSClientMessage =
  | { type: 'configure'; config: Partial<EACCConfig> }
  | { type: 'theme_change'; theme: ThemeName }
  | { type: 'ping' };

// === Config ===

export interface EACCConfig {
  anthropicAdminKey?: string;
  openaiKey?: string;
  pollIntervalMs: number;
  port: number;
  market?: MarketConfig;
}

export type MarketServerMode = 'standalone' | 'hub' | 'seller';

export type MarketListingStatus =
  | 'locked'
  | 'connecting'
  | 'online'
  | 'offline'
  | 'disabled'
  | 'error';

export interface MarketConfig {
  mode?: MarketServerMode;
  hubUrl?: string;
  seller?: MarketSellerLocalConfig;
}

export interface MarketSellerLocalConfig {
  sellerId: string;
  listingId: string;
  sellerAlias: string;
  endpoint: string;
  endpointHost: string;
  model: string;
  publicNote?: string;
  capabilityTokenPreview: string;
  enabled: boolean;
}

export interface MarketVaultRecord {
  version: 1;
  sellerId: string;
  listingId: string;
  sellerAlias: string;
  endpoint: string;
  model: string;
  publicNote?: string;
  endpointHost: string;
  salt: string;
  iv: string;
  authTag: string;
  ciphertext: string;
  createdAt: number;
  updatedAt: number;
}

export interface MarketSellerSecretBundle {
  apiKey: string;
  capabilityToken: string;
}

export interface MarketUsageLedger {
  requestCount: number;
  totalTokens: number;
  inputTokens: number;
  outputTokens: number;
  lastRequestAt: number | null;
  lastBuyerAlias: string | null;
}

export interface MarketListing {
  listingId: string;
  sellerId: string;
  sellerAlias: string;
  endpointHost: string;
  model: string;
  publicNote?: string;
  capabilityTokenPreview: string;
  status: MarketListingStatus;
  disabled: boolean;
  requestCount: number;
  totalTokens: number;
  lastSeenAt: number;
  lastRequestAt: number | null;
}

export interface MarketSellerSummary {
  sellerId: string;
  listingId: string;
  sellerAlias: string;
  endpoint?: string;
  endpointHost: string;
  model: string;
  publicNote?: string;
  hubUrl: string | null;
  status: MarketListingStatus;
  enabled: boolean;
  hasLocalVault: boolean;
  hasUnlockedSecret: boolean;
  capabilityTokenPreview: string;
  lastError?: string | null;
}

export interface MarketBuyerRequest {
  listingId: string;
  prompt: string;
  buyerAlias?: string;
  maxTokens?: number;
}

export interface MarketUsageResult {
  totalTokens: number;
  inputTokens: number;
  outputTokens: number;
}

export interface MarketBuyerResponse {
  requestId: string;
  listingId: string;
  sellerAlias: string;
  model: string;
  outputText: string;
  usage: MarketUsageResult;
  latencyMs: number;
  completedAt: number;
  error?: string;
}

export interface MarketState {
  serverMode: MarketServerMode;
  hubUrl: string | null;
  seller: MarketSellerSummary | null;
  listings: MarketListing[];
  blacklist: string[];
  operatorControlsAvailable: boolean;
}

// === Milestones ===

export interface Milestone {
  threshold: number;
  name: string;
  nameZh: string;
  scripture: string;
  effect: MilestoneEffect;
}

export type MilestoneEffect =
  | 'flash'
  | 'color_pulse'
  | 'particle_burst'
  | 'screen_glow'
  | 'theme_shift'
  | 'unlock_eternal';

// === Theme ===

export type ThemeName = 'cyber' | 'matrix' | 'amber' | 'void';

export interface Theme {
  name: ThemeName;
  label: string;
  labelZh: string;
  isLightTheme: boolean;
  bg: string;
  surfaceStrong: string;
  surfaceSoft: string;
  surfaceBorder: string;
  fireCore: string;
  fireEdge: string;
  particleColor: string;
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  accentGlow: string;
  scriptureFont: string;
  dataFont: string;
}
