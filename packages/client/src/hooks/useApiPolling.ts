import { useEffect, useRef } from 'react';
import { useStore } from '../stores/store';
import { getMilestone } from '@ritual-screen/shared';
import type { TokenData, SourceData } from '@ritual-screen/shared';

const POLL_INTERVAL = 60_000;

export const LS_ANTHROPIC_KEY = 'ritual-anthropic-key';
export const LS_OPENAI_KEY = 'ritual-openai-key';

// --- Anthropic pricing ---

const ANTHROPIC_PRICING: Record<string, { input: number; output: number }> = {
  'claude-opus-4': { input: 15 / 1e6, output: 75 / 1e6 },
  'claude-sonnet-4': { input: 3 / 1e6, output: 15 / 1e6 },
  'claude-haiku-4': { input: 0.8 / 1e6, output: 4 / 1e6 },
  'claude-3-5-sonnet': { input: 3 / 1e6, output: 15 / 1e6 },
  'claude-3-opus': { input: 15 / 1e6, output: 75 / 1e6 },
  'claude-3-haiku': { input: 0.25 / 1e6, output: 1.25 / 1e6 },
};

// --- OpenAI pricing ---

const OPENAI_PRICING: Record<string, { input: number; output: number }> = {
  'gpt-4o': { input: 2.5 / 1e6, output: 10 / 1e6 },
  'gpt-4-turbo': { input: 10 / 1e6, output: 30 / 1e6 },
  'gpt-4': { input: 30 / 1e6, output: 60 / 1e6 },
  'gpt-3.5': { input: 0.5 / 1e6, output: 1.5 / 1e6 },
  'o1': { input: 15 / 1e6, output: 60 / 1e6 },
  'o3': { input: 10 / 1e6, output: 40 / 1e6 },
};

function estimateCost(
  pricing: Record<string, { input: number; output: number }>,
  defaultInput: number,
  defaultOutput: number,
  model: string,
  inputTokens: number,
  outputTokens: number,
): number {
  for (const [prefix, price] of Object.entries(pricing)) {
    if (model.startsWith(prefix)) {
      return inputTokens * price.input + outputTokens * price.output;
    }
  }
  return inputTokens * defaultInput + outputTokens * defaultOutput;
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

// --- Date helpers ---

function todayStr() { return new Date().toISOString().slice(0, 10); }

function monthStartStr() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
}

function tomorrowStr() {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return d.toISOString().slice(0, 10);
}

function yearStartStr() { return `${new Date().getFullYear()}-01-01`; }

function startOfDayUnix() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return Math.floor(d.getTime() / 1000);
}

function startOfMonthUnix() {
  const d = new Date();
  d.setDate(1);
  d.setHours(0, 0, 0, 0);
  return Math.floor(d.getTime() / 1000);
}

function startOfYearUnix() {
  const d = new Date();
  d.setMonth(0, 1);
  d.setHours(0, 0, 0, 0);
  return Math.floor(d.getTime() / 1000);
}

function nowUnix() { return Math.floor(Date.now() / 1000); }

// --- API fetch helpers ---

interface AnthropicRow { model: string; input_tokens: number; output_tokens: number }

async function fetchAnthropicPeriod(
  apiKey: string,
  startDate: string,
  endDate: string,
): Promise<{ inputTokens: number; outputTokens: number; costUSD: number }> {
  const params = new URLSearchParams({ group_by: 'model', start_date: startDate, end_date: endDate });
  const res = await fetch(`/api/anthropic/usage?${params}`, {
    headers: { 'x-api-key': apiKey },
  });
  if (!res.ok) throw new Error(`Anthropic ${res.status}`);
  const body = await res.json() as { data: AnthropicRow[] };

  let inputTokens = 0, outputTokens = 0, costUSD = 0;
  for (const row of body.data) {
    inputTokens += row.input_tokens;
    outputTokens += row.output_tokens;
    costUSD += estimateCost(ANTHROPIC_PRICING, 3 / 1e6, 15 / 1e6, row.model, row.input_tokens, row.output_tokens);
  }
  return { inputTokens, outputTokens, costUSD };
}

async function fetchAnthropicSource(apiKey: string): Promise<SourceData> {
  const end = tomorrowStr();
  const [today, month, total] = await Promise.all([
    fetchAnthropicPeriod(apiKey, todayStr(), end),
    fetchAnthropicPeriod(apiKey, monthStartStr(), end),
    fetchAnthropicPeriod(apiKey, yearStartStr(), end),
  ]);
  return {
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
  };
}

interface OpenAIResult { input_tokens: number; output_tokens: number; model: string }
interface OpenAIBucket { results: OpenAIResult[] }

async function fetchOpenAIPeriod(
  apiKey: string,
  startTime: number,
  endTime: number,
): Promise<{ inputTokens: number; outputTokens: number; costUSD: number }> {
  const params = new URLSearchParams({
    start_time: String(startTime),
    end_time: String(endTime),
    bucket_width: '1d',
    group_by: 'model',
  });
  const res = await fetch(`/api/openai/usage?${params}`, {
    headers: { Authorization: `Bearer ${apiKey}` },
  });
  if (!res.ok) throw new Error(`OpenAI ${res.status}`);
  const body = await res.json() as { data: OpenAIBucket[] };

  let inputTokens = 0, outputTokens = 0, costUSD = 0;
  for (const bucket of body.data) {
    for (const result of bucket.results) {
      inputTokens += result.input_tokens;
      outputTokens += result.output_tokens;
      costUSD += estimateCost(OPENAI_PRICING, 2.5 / 1e6, 10 / 1e6, result.model, result.input_tokens, result.output_tokens);
    }
  }
  return { inputTokens, outputTokens, costUSD };
}

async function fetchOpenAISource(apiKey: string): Promise<SourceData> {
  const end = nowUnix();
  const [today, month, total] = await Promise.all([
    fetchOpenAIPeriod(apiKey, startOfDayUnix(), end),
    fetchOpenAIPeriod(apiKey, startOfMonthUnix(), end),
    fetchOpenAIPeriod(apiKey, startOfYearUnix(), end),
  ]);
  return {
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
  };
}

// --- Combine sources into TokenData ---

function combineSourceData(anthropic: SourceData, openai: SourceData): TokenData {
  const claudeCode = emptySource();
  return {
    totalTokens: anthropic.totalTokens + openai.totalTokens,
    totalCostUSD: anthropic.costUSD + openai.costUSD,
    todayTokens: anthropic.todayTokens + openai.todayTokens,
    todayCostUSD: anthropic.todayCostUSD + openai.todayCostUSD,
    tokensPerSecond: 0,
    monthTokens: anthropic.monthTokens + openai.monthTokens,
    monthCostUSD: anthropic.monthCostUSD + openai.monthCostUSD,
    sources: {
      claudeCode,
      anthropicApi: anthropic,
      openaiApi: openai,
    },
    lastUpdated: Date.now(),
  };
}

// --- Hook ---

export function useApiPolling() {
  const mode = useStore((s) => s.mode);
  const { setTokenData, setMilestone } = useStore();
  const prevMilestoneRef = useRef<string | null>(null);
  const pollRef = useRef<() => void>(() => {});

  useEffect(() => {
    if (mode !== 'web') return;

    let cancelled = false;

    async function poll() {
      const anthropicKey = localStorage.getItem(LS_ANTHROPIC_KEY);
      const openaiKey = localStorage.getItem(LS_OPENAI_KEY);
      if (!anthropicKey && !openaiKey) return;

      try {
        const [anthropic, openai] = await Promise.all([
          anthropicKey ? fetchAnthropicSource(anthropicKey) : Promise.resolve(emptySource()),
          openaiKey ? fetchOpenAISource(openaiKey) : Promise.resolve(emptySource()),
        ]);

        if (cancelled) return;

        const data = combineSourceData(anthropic, openai);
        setTokenData(data);

        const m = getMilestone(data.totalTokens);
        if (m && m.name !== prevMilestoneRef.current) {
          prevMilestoneRef.current = m.name;
          setMilestone(m);
          setTimeout(() => setMilestone(null), 8000);
        }
      } catch {
        // silently retry on next interval
      }
    }

    pollRef.current = poll;

    // Re-poll immediately when keys are updated from Setup
    const onKeysUpdated = () => poll();
    window.addEventListener('ritual-keys-updated', onKeysUpdated);

    poll();
    const timer = setInterval(poll, POLL_INTERVAL);
    return () => {
      cancelled = true;
      clearInterval(timer);
      window.removeEventListener('ritual-keys-updated', onKeysUpdated);
    };
  }, [mode, setTokenData, setMilestone]);
}
