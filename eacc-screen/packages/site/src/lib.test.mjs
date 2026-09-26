import test from 'node:test';
import assert from 'node:assert/strict';
import { parseFrontmatter, markdownToHtml, normalizePath } from './lib.mjs';

test('parseFrontmatter extracts required metadata and list fields', () => {
  const { meta, body } = parseFrontmatter(`---\nslug: sample\nmonetizationMode: ads, affiliate, newsletter\nrelated: workflow/a, compare/b\nupdatedAt: 2026-04-16\n---\n## Hello\n\nWorld`);

  assert.equal(meta.slug, 'sample');
  assert.deepEqual(meta.monetizationMode, ['ads', 'affiliate', 'newsletter']);
  assert.deepEqual(meta.related, ['workflow/a', 'compare/b']);
  assert.equal(body, '## Hello\n\nWorld');
});

test('parseFrontmatter extracts YAML-style bullet lists for featured/related slugs', () => {
  const { meta } = parseFrontmatter(`---\nslug: sample\nfeaturedWorkflowSlugs:\n  - ship-an-ai-code-review-loop\n  - build-a-context-passing-debug-stack\nrelatedComparisonSlugs:\n  - claude-code-vs-cursor-for-solo-repo-ships\n---\nBody`);

  assert.deepEqual(meta.featuredWorkflowSlugs, [
    'ship-an-ai-code-review-loop',
    'build-a-context-passing-debug-stack',
  ]);
  assert.deepEqual(meta.relatedComparisonSlugs, [
    'claude-code-vs-cursor-for-solo-repo-ships',
  ]);
});

test('markdownToHtml renders headings, lists, code fences, and links', () => {
  const html = markdownToHtml(`## Section\n\n- item one\n- item two\n\n1. first\n2. second\n\n> quoted\n\nVisit [site](/ritual).\n\n\`\`\`js\nconsole.log("ok")\n\`\`\``);

  assert.match(html, /<h3>Section<\/h3>/);
  assert.match(html, /<ul><li>item one<\/li><li>item two<\/li><\/ul>/);
  assert.match(html, /<ol><li>first<\/li><li>second<\/li><\/ol>/);
  assert.match(html, /<blockquote><p>quoted<\/p><\/blockquote>/);
  assert.match(html, /<a href="\/ritual">site<\/a>/);
  assert.match(html, /<pre><code class="language-js">console\.log\(&quot;ok&quot;\)<\/code><\/pre>/);
});

test('normalizePath removes trailing slash except root', () => {
  assert.equal(normalizePath('/workflow/test/'), '/workflow/test');
  assert.equal(normalizePath('hub/ai-coding-workflows'), '/hub/ai-coding-workflows');
  assert.equal(normalizePath('/'), '/');
});
