/// <reference types="node" />
import { describe, expect, it } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const repoRoot = join(__dirname, '..', '..', '..');
const contentRoot = join(repoRoot, 'content');
const requiredFrontmatterFields = ['slug', 'title', 'cluster', 'intent', 'ctaType', 'updatedAt', 'monetizationMode'];

function listMarkdownFiles(dir: string): string[] {
  const entries = readdirSync(dir, { withFileTypes: true });
  return entries.flatMap((entry) => {
    const entryPath = join(dir, entry.name);
    if (entry.isDirectory()) return listMarkdownFiles(entryPath);
    return entry.name.endsWith('.md') ? [entryPath] : [];
  });
}

function parseFrontmatter(markdown: string): Record<string, string> {
  const match = markdown.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) {
    throw new Error('missing frontmatter block');
  }

  const fields: Record<string, string> = {};
  for (const line of match[1].split('\n')) {
    if (!line.trim() || line.startsWith('  - ')) continue;
    const separator = line.indexOf(':');
    if (separator === -1) continue;
    const key = line.slice(0, separator).trim();
    const value = line.slice(separator + 1).trim();
    fields[key] = value;
  }
  return fields;
}

describe('content evidence artifacts', () => {
  it('keeps the markdown source inventory on the required frontmatter contract', () => {
    const markdownFiles = listMarkdownFiles(contentRoot);
    expect(markdownFiles.length).toBeGreaterThanOrEqual(8);

    for (const file of markdownFiles) {
      const frontmatter = parseFrontmatter(readFileSync(file, 'utf8'));
      for (const field of requiredFrontmatterFields) {
        expect(frontmatter[field], `${file} is missing ${field}`).toBeTruthy();
      }
    }
  });

  it('tracks the weekly ledger with the expected reporting columns', () => {
    const csv = readFileSync(join(repoRoot, 'ops', 'weekly-revenue-ledger.csv'), 'utf8').trim().split('\n');
    const header = csv[0].split(',');
    const requiredColumns = ['week_start', 'published_workflows', 'published_comparisons', 'cta_clicks_affiliate', 'cta_clicks_newsletter', 'newsletter_signups', 'total_revenue_usd', 'top_cluster'];

    expect(csv).toHaveLength(13);
    for (const column of requiredColumns) {
      expect(header).toContain(column);
    }
  });

  it('keeps the 90-day cadence aligned with the stated publishing targets', () => {
    const cadence = readFileSync(join(repoRoot, 'ops', '90-day-cadence.md'), 'utf8');

    expect(cadence).toContain('5–10 hours/week');
    expect(cadence).toContain('8 workflow/tutorial pages');
    expect(cadence).toContain('4 comparison pages');
    expect(cadence).toContain('>= $50/month');
  });
});
