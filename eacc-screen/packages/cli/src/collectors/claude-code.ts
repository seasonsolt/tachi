import { watch } from 'chokidar';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import type { ClaudeCodeStats, SourceData } from '@eacc/shared';

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

  // Today + month tokens/cost from dailyModelTokens (single pass)
  let todayTokens = 0;
  let todayCost = 0;
  let monthTokens = 0;
  let monthCost = 0;
  for (const day of stats.dailyModelTokens) {
    const isToday = day.date === todayStr;
    const isMonth = day.date.startsWith(yearMonth);
    if (!isToday && !isMonth) continue;
    for (const [model, count] of Object.entries(day.tokensByModel)) {
      // dailyModelTokens only has total count per model, estimate with blended rate
      const price = getPricing(model);
      const blendedRate = (price.input + price.output) / 2;
      if (isToday) {
        todayTokens += count;
        todayCost += count * blendedRate;
      }
      if (isMonth) {
        monthTokens += count;
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
  let lastMtime = 0;
  let lastSize = 0;

  function readAndNotify() {
    try {
      const stat = statSync(STATS_PATH);
      if (stat.mtimeMs === lastMtime && stat.size === lastSize) return;
      const raw = readFileSync(STATS_PATH, 'utf-8');
      const data = parseStats(raw);
      lastMtime = stat.mtimeMs;
      lastSize = stat.size;
      onUpdate(data);
    } catch {
      // Ignore transient read errors or invalid file
    }
  }

  // Read initial state if file exists
  if (existsSync(STATS_PATH)) {
    readAndNotify();
  }

  const watcher = watch(STATS_PATH, {
    persistent: true,
    ignoreInitial: true,
    awaitWriteFinish: { stabilityThreshold: 300, pollInterval: 100 },
  });

  watcher.on('change', readAndNotify);
  watcher.on('add', readAndNotify);

  return () => {
    watcher.close();
  };
}
