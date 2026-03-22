import type { SourceData } from '@eacc/shared';

interface OpenAIBucket {
  start_time: number;
  end_time: number;
  results: Array<{
    input_tokens: number;
    output_tokens: number;
    model: string;
  }>;
}

interface OpenAIUsageResponse {
  data: OpenAIBucket[];
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
  'gpt-4o': { input: 2.5 / 1_000_000, output: 10 / 1_000_000 },
  'gpt-4-turbo': { input: 10 / 1_000_000, output: 30 / 1_000_000 },
  'gpt-4': { input: 30 / 1_000_000, output: 60 / 1_000_000 },
  'gpt-3.5': { input: 0.5 / 1_000_000, output: 1.5 / 1_000_000 },
  'o1': { input: 15 / 1_000_000, output: 60 / 1_000_000 },
  'o3': { input: 10 / 1_000_000, output: 40 / 1_000_000 },
};

function estimateCost(model: string, inputTokens: number, outputTokens: number): number {
  for (const [prefix, price] of Object.entries(PRICING)) {
    if (model.startsWith(prefix)) {
      return inputTokens * price.input + outputTokens * price.output;
    }
  }
  // Default to gpt-4o pricing
  return inputTokens * (2.5 / 1_000_000) + outputTokens * (10 / 1_000_000);
}

async function fetchUsage(
  apiKey: string,
  startTime: number,
  endTime: number,
): Promise<{ inputTokens: number; outputTokens: number; costUSD: number }> {
  const url = new URL('https://api.openai.com/v1/organization/usage/completions');
  url.searchParams.set('start_time', String(startTime));
  url.searchParams.set('end_time', String(endTime));
  url.searchParams.set('bucket_width', '1d');
  url.searchParams.set('group_by', 'model');

  const res = await fetch(url.toString(), {
    headers: { Authorization: `Bearer ${apiKey}` },
  });

  if (!res.ok) {
    if (res.status === 401) throw new Error('Invalid OpenAI API key');
    if (res.status === 429) throw new Error('OpenAI rate limit exceeded');
    throw new Error(`OpenAI API ${res.status}: ${res.statusText}`);
  }

  const body = (await res.json()) as OpenAIUsageResponse;

  let inputTokens = 0;
  let outputTokens = 0;
  let costUSD = 0;

  for (const bucket of body.data) {
    for (const result of bucket.results) {
      inputTokens += result.input_tokens;
      outputTokens += result.output_tokens;
      costUSD += estimateCost(result.model, result.input_tokens, result.output_tokens);
    }
  }

  return { inputTokens, outputTokens, costUSD };
}

function startOfDayUnix(): number {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return Math.floor(d.getTime() / 1000);
}

function startOfMonthUnix(): number {
  const d = new Date();
  d.setDate(1);
  d.setHours(0, 0, 0, 0);
  return Math.floor(d.getTime() / 1000);
}

function startOfYearUnix(): number {
  const d = new Date();
  d.setMonth(0, 1);
  d.setHours(0, 0, 0, 0);
  return Math.floor(d.getTime() / 1000);
}

function nowUnix(): number {
  return Math.floor(Date.now() / 1000);
}

export function startOpenAICollector(
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
      const end = nowUnix();
      const [today, month, total] = await Promise.all([
        fetchUsage(apiKey, startOfDayUnix(), end),
        fetchUsage(apiKey, startOfMonthUnix(), end),
        fetchUsage(apiKey, startOfYearUnix(), end),
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
