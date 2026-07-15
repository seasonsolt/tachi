import { describe, expect, it } from 'vitest';
import { sessionStateLabel } from './session-state';

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
