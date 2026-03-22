import type { SourceData } from '@ritual-screen/shared';

interface AnthropicUsageRow {
  model: string;
  input_tokens: number;
  output_tokens: number;
}

interface AnthropicUsageResponse {
  data: AnthropicUsageRow[];
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

// Rough per-token pricing (USD) by model prefix
const PRICING: Record<string, { input: number; output: number }> = {
  'claude-opus-4': { input: 15 / 1_000_000, output: 75 / 1_000_000 },
  'claude-sonnet-4': { input: 3 / 1_000_000, output: 15 / 1_000_000 },
  'claude-haiku-4': { input: 0.8 / 1_000_000, output: 4 / 1_000_000 },
  'claude-3-5-sonnet': { input: 3 / 1_000_000, output: 15 / 1_000_000 },
  'claude-3-opus': { input: 15 / 1_000_000, output: 75 / 1_000_000 },
  'claude-3-haiku': { input: 0.25 / 1_000_000, output: 1.25 / 1_000_000 },
};

function estimateCost(model: string, inputTokens: number, outputTokens: number): number {
  for (const [prefix, price] of Object.entries(PRICING)) {
    if (model.startsWith(prefix)) {
      return inputTokens * price.input + outputTokens * price.output;
    }
  }
  // Default to sonnet pricing
  return inputTokens * (3 / 1_000_000) + outputTokens * (15 / 1_000_000);
}

async function fetchUsage(
  apiKey: string,
  startDate: string,
  endDate: string,
): Promise<{ inputTokens: number; outputTokens: number; costUSD: number }> {
  const url = new URL('https://api.anthropic.com/v1/organizations/usage_report/messages');
  url.searchParams.set('group_by', 'model');
  url.searchParams.set('start_date', startDate);
  url.searchParams.set('end_date', endDate);

  const res = await fetch(url.toString(), {
    headers: { 'x-api-key': apiKey },
  });

  if (!res.ok) {
    if (res.status === 401) throw new Error('Invalid Anthropic admin key');
    if (res.status === 429) throw new Error('Anthropic rate limit exceeded');
    throw new Error(`Anthropic API ${res.status}: ${res.statusText}`);
  }

  const body = (await res.json()) as AnthropicUsageResponse;

  let inputTokens = 0;
  let outputTokens = 0;
  let costUSD = 0;

  for (const row of body.data) {
    inputTokens += row.input_tokens;
    outputTokens += row.output_tokens;
    costUSD += estimateCost(row.model, row.input_tokens, row.output_tokens);
  }

  return { inputTokens, outputTokens, costUSD };
}

function todayStr(): string {
  return new Date().toISOString().slice(0, 10);
}

function monthStartStr(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
}

function tomorrowStr(): string {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return d.toISOString().slice(0, 10);
}

// Anthropic tracks from Jan 1 of the current year for "total" — approximation
function yearStartStr(): string {
  return `${new Date().getFullYear()}-01-01`;
}

export function startAnthropicCollector(
  getApiKey: () => string | undefined,
  intervalMs: number,
  onUpdate: (data: SourceData) => void,
  onError: (message: string) => void,
): () => void {
  let stopped = false;

  async function poll() {
    const apiKey = getApiKey();
    if (!apiKey) {
      onUpdate(emptySource());
      return;
    }

    try {
      const end = tomorrowStr();
      const [today, month, total] = await Promise.all([
        fetchUsage(apiKey, todayStr(), end),
        fetchUsage(apiKey, monthStartStr(), end),
        fetchUsage(apiKey, yearStartStr(), end),
      ]);

      onUpdate({
        connected: true,
        totalTokens: total.inputTokens + total.outputTokens,
        todayTokens: today.inputTokens + today.outputTokens,
        monthTokens: month.inputTokens + month.outputTokens,
        costUSD: total.costUSD,
        todayCostUSD: today.costUSD,
        monthCostUSD: month.costUSD,
        inputTokens: total.inputTokens,
        outputTokens: total.outputTokens,
        lastUpdated: Date.now(),
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      onError(msg);
    }
  }

  // Initial poll
  poll();

  const timer = setInterval(() => {
    if (!stopped) poll();
  }, intervalMs);

  return () => {
    stopped = true;
    clearInterval(timer);
  };
}
