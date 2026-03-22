import { watch } from 'chokidar';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import type { ClaudeCodeStats, SourceData } from '@ritual-screen/shared';

const STATS_PATH = join(homedir(), '.claude', 'stats-cache.json');

// Per-token pricing (USD) for Claude models used in Claude Code
const PRICING: Record<string, { input: number; output: number; cacheRead: number; cacheCreate: number }> = {
  'claude-opus-4-6':            { input: 15 / 1e6, output: 75 / 1e6, cacheRead: 1.5 / 1e6, cacheCreate: 18.75 / 1e6 },
  'claude-opus-4-5':            { input: 15 / 1e6, output: 75 / 1e6, cacheRead: 1.5 / 1e6, cacheCreate: 18.75 / 1e6 },
  'claude-sonnet-4-6':          { input: 3 / 1e6,  output: 15 / 1e6, cacheRead: 0.3 / 1e6, cacheCreate: 3.75 / 1e6 },
  'claude-sonnet-4-5':          { input: 3 / 1e6,  output: 15 / 1e6, cacheRead: 0.3 / 1e6, cacheCreate: 3.75 / 1e6 },
  'claude-haiku-4-5':           { input: 0.8 / 1e6, output: 4 / 1e6, cacheRead: 0.08 / 1e6, cacheCreate: 1 / 1e6 },
  'claude-3-5-sonnet':          { input: 3 / 1e6,  output: 15 / 1e6, cacheRead: 0.3 / 1e6, cacheCreate: 3.75 / 1e6 },
  'claude-3-opus':              { input: 15 / 1e6, output: 75 / 1e6, cacheRead: 1.5 / 1e6, cacheCreate: 18.75 / 1e6 },
  'claude-3-haiku':             { input: 0.25 / 1e6, output: 1.25 / 1e6, cacheRead: 0.03 / 1e6, cacheCreate: 0.3 / 1e6 },
};

const DEFAULT_PRICE = { input: 3 / 1e6, output: 15 / 1e6, cacheRead: 0.3 / 1e6, cacheCreate: 3.75 / 1e6 };

function getPricing(model: string) {
  for (const [prefix, price] of Object.entries(PRICING)) {
    if (model.startsWith(prefix)) return price;
  }
  return DEFAULT_PRICE;
}

function emptySource(): SourceData {
  return {
    connected: false,
    totalTokens: 0,
    todayTokens: 0,
    monthTokens: 0,
    costUSD: 0,
    todayCostUSD: 0,
    monthCostUSD: 0,
    inputTokens: 0,
    outputTokens: 0,
    lastUpdated: 0,
  };
}

/** @internal exported for testing */
export function parseStats(raw: string): SourceData {
  const stats: ClaudeCodeStats = JSON.parse(raw);
  const now = new Date();
  const todayStr = now.toISOString().slice(0, 10);
  const yearMonth = todayStr.slice(0, 7);

  // Aggregate from modelUsage for totals + estimate cost per model
  let totalInput = 0;
  let totalOutput = 0;
  let totalCost = 0;
  for (const [model, usage] of Object.entries(stats.modelUsage)) {
    totalInput += usage.inputTokens + usage.cacheReadInputTokens + usage.cacheCreationInputTokens;
    totalOutput += usage.outputTokens;
    const price = getPricing(model);
    totalCost += usage.inputTokens * price.input
      + usage.outputTokens * price.output
      + usage.cacheReadInputTokens * price.cacheRead
      + usage.cacheCreationInputTokens * price.cacheCreate;
  }

  // Today tokens + cost from dailyModelTokens
  let todayTokens = 0;
  let todayCost = 0;
  for (const day of stats.dailyModelTokens) {
    if (day.date === todayStr) {
      for (const [model, count] of Object.entries(day.tokensByModel)) {
        todayTokens += count;
        // dailyModelTokens only has total count per model, estimate with blended rate
        const price = getPricing(model);
        const blendedRate = (price.input + price.output) / 2;
        todayCost += count * blendedRate;
      }
    }
  }

  // Month tokens + cost from dailyModelTokens
  let monthTokens = 0;
  let monthCost = 0;
  for (const day of stats.dailyModelTokens) {
    if (day.date.startsWith(yearMonth)) {
      for (const [model, count] of Object.entries(day.tokensByModel)) {
        monthTokens += count;
        const price = getPricing(model);
        const blendedRate = (price.input + price.output) / 2;
        monthCost += count * blendedRate;
      }
    }
  }

  const totalTokens = totalInput + totalOutput;

  return {
    connected: true,
    totalTokens,
    todayTokens,
    monthTokens,
    costUSD: totalCost,
    todayCostUSD: todayCost,
    monthCostUSD: monthCost,
    inputTokens: totalInput,
    outputTokens: totalOutput,
    lastUpdated: Date.now(),
  };
}

export function startClaudeCodeCollector(
  onUpdate: (data: SourceData) => void,
): () => void {
  // Read initial state if file exists
  if (existsSync(STATS_PATH)) {
    try {
      const raw = readFileSync(STATS_PATH, 'utf-8');
      onUpdate(parseStats(raw));
    } catch {
      // File might be invalid on first read
    }
  }

  const watcher = watch(STATS_PATH, {
    persistent: true,
    ignoreInitial: true,
    awaitWriteFinish: { stabilityThreshold: 300, pollInterval: 100 },
  });

  watcher.on('change', () => {
    try {
      const raw = readFileSync(STATS_PATH, 'utf-8');
      onUpdate(parseStats(raw));
    } catch {
      // Ignore transient read errors
    }
  });

  watcher.on('add', () => {
    try {
      const raw = readFileSync(STATS_PATH, 'utf-8');
      onUpdate(parseStats(raw));
    } catch {
      // Ignore transient read errors
    }
  });

  return () => {
    watcher.close();
  };
}
