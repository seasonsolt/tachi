import { describe, expect, it } from 'vitest';
import { isSessionVisible, sessionStateLabel } from './session-state';

describe('sessionStateLabel', () => {
  it.each([
    ['working', 'working'],
    ['waiting_for_input', 'waiting'],
    ['idle', 'idle'],
    ['completed', 'done'],
  ] as const)('maps %s sessions to %s', (status, expected) => {
    expect(sessionStateLabel({ alive: status !== 'completed', status })).toBe(expected);
  });

  it('falls back to the legacy alive flag', () => {
    expect(sessionStateLabel({ alive: true })).toBe('watching');
    expect(sessionStateLabel({ alive: false })).toBe('done');
  });
});

describe('isSessionVisible', () => {
  const now = 1_000_000;

  it('keeps completed sessions for five minutes', () => {
    expect(isSessionVisible({
      alive: false,
      status: 'completed',
      signal: 'completed',
      startedAt: now - 300_000,
    }, now)).toBe(true);
  });

  it('removes completed sessions after five minutes', () => {
    expect(isSessionVisible({
      alive: false,
      status: 'completed',
      signal: 'completed',
      startedAt: now - 300_001,
    }, now)).toBe(false);
  });

  it('keeps old idle sessions visible', () => {
    expect(isSessionVisible({
      alive: true,
      status: 'idle',
      startedAt: 0,
    }, now)).toBe(true);
  });

  it('starts retention when an inferred session becomes completed', () => {
    expect(isSessionVisible({
      alive: false,
      status: 'completed',
      signal: 'quiet',
      startedAt: now - 599_999,
    }, now)).toBe(true);
    expect(isSessionVisible({
      alive: false,
      status: 'completed',
      signal: 'quiet',
      startedAt: now - 600_001,
    }, now)).toBe(false);
  });

  it('applies retention to legacy completed sessions', () => {
    expect(isSessionVisible({
      alive: false,
      lastActivityAt: now - 300_001,
      startedAt: now,
    }, now)).toBe(false);
  });

  it('uses the observed completion time when activity is stale', () => {
    const session = {
      alive: false,
      status: 'completed' as const,
      signal: 'completed' as const,
      startedAt: 0,
    };

    expect(isSessionVisible(session, now, now - 300_000)).toBe(true);
    expect(isSessionVisible(session, now, now - 300_001)).toBe(false);
  });
});
