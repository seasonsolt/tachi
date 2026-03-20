import { watch } from 'chokidar';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import type { ClaudeCodeStats, SourceData } from '@ritual-screen/shared';

const STATS_PATH = join(homedir(), '.claude', 'stats-cache.json');

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

function parseStats(raw: string): SourceData {
  const stats: ClaudeCodeStats = JSON.parse(raw);
  const now = new Date();
  const todayStr = now.toISOString().slice(0, 10);
  const yearMonth = todayStr.slice(0, 7);

  // Aggregate from modelUsage for totals
  let totalInput = 0;
  let totalOutput = 0;
  let totalCost = 0;
  for (const usage of Object.values(stats.modelUsage)) {
    totalInput += usage.inputTokens + usage.cacheReadInputTokens + usage.cacheCreationInputTokens;
    totalOutput += usage.outputTokens;
    totalCost += usage.costUSD;
  }

  // Today tokens from dailyModelTokens
  let todayTokens = 0;
  for (const day of stats.dailyModelTokens) {
    if (day.date === todayStr) {
      for (const count of Object.values(day.tokensByModel)) {
        todayTokens += count;
      }
    }
  }

  // Month tokens from dailyModelTokens
  let monthTokens = 0;
  for (const day of stats.dailyModelTokens) {
    if (day.date.startsWith(yearMonth)) {
      for (const count of Object.values(day.tokensByModel)) {
        monthTokens += count;
      }
    }
  }

  const totalTokens = totalInput + totalOutput;

  // Estimate cost proportions
  const costPerToken = totalTokens > 0 ? totalCost / totalTokens : 0;
  const todayCost = todayTokens * costPerToken;
  const monthCost = monthTokens * costPerToken;

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
