import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { parseStats } from './claude-code.js';

// Minimal fixture modeled on real ~/.claude/stats-cache.json
function makeFixture(options?: { todayDate?: string }) {
  const today = options?.todayDate ?? '2026-03-14';
  return JSON.stringify({
    version: 2,
    dailyActivity: [],
    dailyModelTokens: [
      { date: '2026-03-10', tokensByModel: { 'claude-opus-4-6': 276965, 'claude-sonnet-4-6': 15 } },
      { date: '2026-03-13', tokensByModel: { 'claude-opus-4-6': 193829, 'claude-sonnet-4-6': 73140 } },
      { date: today, tokensByModel: { 'claude-opus-4-6': 56287, 'claude-sonnet-4-6': 47475 } },
    ],
    modelUsage: {
      'claude-opus-4-6': {
        inputTokens: 4_135_065,
        outputTokens: 1_699_546,
        cacheReadInputTokens: 1_366_296_865,
        cacheCreationInputTokens: 103_112_657,
        costUSD: 0, // Always 0 for subscription users
      },
      'claude-sonnet-4-6': {
        inputTokens: 12_231,
        outputTokens: 108_439,
        cacheReadInputTokens: 95_816_201,
        cacheCreationInputTokens: 2_486_440,
        costUSD: 0,
      },
    },
    totalSessions: 839,
    totalMessages: 102184,
    firstSessionDate: '2026-01-30T02:51:02.878Z',
  });
}

describe('parseStats', () => {
  beforeEach(() => {
    // Fix "now" to 2026-03-14T12:00:00Z so today/month calculations are deterministic
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-03-14T12:00:00Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('marks source as connected', () => {
    const result = parseStats(makeFixture());
    expect(result.connected).toBe(true);
  });

  it('aggregates totalTokens from modelUsage (input + output + cache)', () => {
    const result = parseStats(makeFixture());
    // opus: 4135065 + 1699546 + 1366296865 + 103112657 = 1475244133
    // sonnet: 12231 + 108439 + 95816201 + 2486440 = 98423311
    // totalInput = (4135065+1366296865+103112657) + (12231+95816201+2486440)
    //            = 1473544587 + 98314872 = 1571859459
    // totalOutput = 1699546 + 108439 = 1807985
    expect(result.inputTokens).toBe(1_473_544_587 + 98_314_872);
    expect(result.outputTokens).toBe(1_699_546 + 108_439);
    expect(result.totalTokens).toBe(result.inputTokens + result.outputTokens);
  });

  it('computes totalCostUSD from model pricing, not stats costUSD field', () => {
    const result = parseStats(makeFixture());
    // Should NOT be 0 even though stats.costUSD is 0 for all models
    expect(result.costUSD).toBeGreaterThan(0);

    // Manual calculation for opus-4-6:
    // input: 4135065 * 15/1e6 = 62.025975
    // output: 1699546 * 75/1e6 = 127.46595
    // cacheRead: 1366296865 * 1.5/1e6 = 2049.4452975
    // cacheCreate: 103112657 * 18.75/1e6 = 1933.3623187
    const opusCost = 4_135_065 * (15 / 1e6)
      + 1_699_546 * (75 / 1e6)
      + 1_366_296_865 * (1.5 / 1e6)
      + 103_112_657 * (18.75 / 1e6);

    // sonnet-4-6:
    // input: 12231 * 3/1e6 = 0.036693
    // output: 108439 * 15/1e6 = 1.626585
    // cacheRead: 95816201 * 0.3/1e6 = 28.7448603
    // cacheCreate: 2486440 * 3.75/1e6 = 9.32415
    const sonnetCost = 12_231 * (3 / 1e6)
      + 108_439 * (15 / 1e6)
      + 95_816_201 * (0.3 / 1e6)
      + 2_486_440 * (3.75 / 1e6);

    expect(result.costUSD).toBeCloseTo(opusCost + sonnetCost, 2);
  });

  it('computes todayTokens from dailyModelTokens matching today', () => {
    const result = parseStats(makeFixture());
    // Today = 2026-03-14: opus 56287 + sonnet 47475
    expect(result.todayTokens).toBe(56287 + 47475);
  });

  it('computes todayCostUSD > 0 using blended model pricing', () => {
    const result = parseStats(makeFixture());
    expect(result.todayCostUSD).toBeGreaterThan(0);

    // opus blended: (15 + 75) / 2 / 1e6 = 45/1e6
    // sonnet blended: (3 + 15) / 2 / 1e6 = 9/1e6
    const expectedCost = 56287 * (45 / 1e6) + 47475 * (9 / 1e6);
    expect(result.todayCostUSD).toBeCloseTo(expectedCost, 6);
  });

  it('computes monthTokens from all entries in current month', () => {
    const result = parseStats(makeFixture());
    // All 3 entries are in 2026-03:
    // 276965 + 15 + 193829 + 73140 + 56287 + 47475
    expect(result.monthTokens).toBe(276965 + 15 + 193829 + 73140 + 56287 + 47475);
  });

  it('computes monthCostUSD > 0', () => {
    const result = parseStats(makeFixture());
    expect(result.monthCostUSD).toBeGreaterThan(0);
  });

  it('returns 0 todayTokens when no entry matches today', () => {
    // Fixture has entries for 3/10, 3/13, 3/14 but we set now to 3/21
    vi.setSystemTime(new Date('2026-03-21T12:00:00Z'));
    const result = parseStats(makeFixture());
    expect(result.todayTokens).toBe(0);
    expect(result.todayCostUSD).toBe(0);
  });

  it('still counts month entries even when today has no data', () => {
    vi.setSystemTime(new Date('2026-03-21T12:00:00Z'));
    const result = parseStats(makeFixture());
    // All 3 fixture entries are in 2026-03, so monthTokens should still be > 0
    expect(result.monthTokens).toBe(276965 + 15 + 193829 + 73140 + 56287 + 47475);
    expect(result.monthCostUSD).toBeGreaterThan(0);
  });

  it('handles empty modelUsage gracefully', () => {
    const raw = JSON.stringify({
      version: 2,
      dailyActivity: [],
      dailyModelTokens: [],
      modelUsage: {},
      totalSessions: 0,
      totalMessages: 0,
      firstSessionDate: '2026-03-14',
    });
    const result = parseStats(raw);
    expect(result.connected).toBe(true);
    expect(result.totalTokens).toBe(0);
    expect(result.costUSD).toBe(0);
  });

  it('uses default pricing for unknown models', () => {
    const raw = JSON.stringify({
      version: 2,
      dailyActivity: [],
      dailyModelTokens: [
        { date: '2026-03-14', tokensByModel: { 'claude-future-99': 1000 } },
      ],
      modelUsage: {
        'claude-future-99': {
          inputTokens: 500,
          outputTokens: 500,
          cacheReadInputTokens: 0,
          cacheCreationInputTokens: 0,
          costUSD: 0,
        },
      },
      totalSessions: 1,
      totalMessages: 1,
      firstSessionDate: '2026-03-14',
    });
    const result = parseStats(raw);
    // Default pricing: input 3/1e6, output 15/1e6
    const expectedCost = 500 * (3 / 1e6) + 500 * (15 / 1e6);
    expect(result.costUSD).toBeCloseTo(expectedCost, 6);
    expect(result.costUSD).toBeGreaterThan(0);
  });
});
