import { describe, expect, it } from 'vitest';
import launchBatch from '../../../content/launch-batch.json';

describe('launch batch inventory', () => {
  it('keeps e-acc.ai as the only phase-1 public domain', () => {
    expect(launchBatch.phase1Domain).toBe('e-acc.ai');
    expect(launchBatch.deferredDomains).toContain('e-accs.com');
  });

  it('covers the required launch surface types', () => {
    const pageTypes = new Set(launchBatch.launchBatch.map((entry) => entry.pageType));

    expect(pageTypes).toEqual(new Set(['home', 'hub', 'workflow', 'comparison', 'lab']));
    expect(launchBatch.launchBatch.filter((entry) => entry.pageType === 'workflow')).toHaveLength(3);
    expect(launchBatch.launchBatch.filter((entry) => entry.pageType === 'comparison')).toHaveLength(1);
    expect(launchBatch.launchBatch.some((entry) => entry.path === '/ritual')).toBe(true);
  });

  it('keeps launch paths unique and route-safe', () => {
    const paths = launchBatch.launchBatch.map((entry) => entry.path);
    const uniquePaths = new Set(paths);

    expect(uniquePaths.size).toBe(paths.length);
    expect(paths.every((path) => path.startsWith('/'))).toBe(true);
    expect(paths.every((path) => path === '/' || path.slice(1).split('/').every(Boolean))).toBe(true);
  });
});
