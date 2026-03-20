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

// === WebSocket Messages ===

export type WSMessage =
  | { type: 'token_update'; data: TokenData }
  | { type: 'milestone'; milestone: Milestone }
  | { type: 'error'; source: string; message: string }
  | { type: 'connected'; sources: string[] };

export type WSClientMessage =
  | { type: 'configure'; config: Partial<RitualConfig> }
  | { type: 'ping' };

// === Config ===

export interface RitualConfig {
  anthropicAdminKey?: string;
  openaiKey?: string;
  pollIntervalMs: number;
  port: number;
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

export type ThemeName = 'ancient' | 'cyber' | 'cyberpunk' | 'synthwave' | 'matrix' | 'blood';

export interface Theme {
  name: ThemeName;
  label: string;
  bg: string;
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
