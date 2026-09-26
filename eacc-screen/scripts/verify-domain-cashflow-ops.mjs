#!/usr/bin/env node

import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, resolve, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = process.argv[2] ? resolve(process.argv[2]) : resolve(scriptDir, '..');
const packagesRoot = join(repoRoot, 'packages');
const baselinePackages = new Set(['cli', 'client', 'shared', 'worker']);

function walk(dir, matcher, acc = []) {
  if (!existsSync(dir)) return acc;
  for (const entry of readdirSync(dir)) {
    if (entry === 'node_modules' || entry === '.git') continue;
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      walk(fullPath, matcher, acc);
    } else if (matcher(fullPath)) {
      acc.push(fullPath);
    }
  }
  return acc;
}

function listPackages() {
  if (!existsSync(packagesRoot)) return [];
  return readdirSync(packagesRoot).filter((entry) => existsSync(join(packagesRoot, entry, 'package.json')));
}

function readText(path) {
  return existsSync(path) ? readFileSync(path, 'utf-8') : '';
}

function summarize(paths, base = repoRoot) {
  return paths.map((path) => relative(base, path));
}

function printSection(title, lines) {
  console.log(`\n## ${title}`);
  if (lines.length === 0) {
    console.log('(none)');
    return;
  }
  for (const line of lines) {
    console.log(`- ${line}`);
  }
}

const packages = listPackages();
const contentPackages = packages.filter((name) => !baselinePackages.has(name));
const distHtmlFiles = walk(repoRoot, (path) => path.endsWith('.html') && path.includes(`${join('packages', '')}`) && path.includes(`${join('', 'dist', '')}`));
const publicHtmlFiles = distHtmlFiles.filter((path) => !path.endsWith(join('packages', 'client', 'dist', 'index.html')));
const manifestFiles = walk(repoRoot, (path) => {
  const file = basename(path).toLowerCase();
  return file.endsWith('.json') && (file.includes('manifest') || file.includes('routes'))
    || file.endsWith('.xml') && file.includes('sitemap');
});
const routeManifests = manifestFiles.filter((path) => !path.includes('node_modules'));
const analyticsFiles = walk(repoRoot, (path) => /\.(ts|tsx|js|jsx|json|md)$/.test(path)).filter((path) => {
  const text = readText(path);
  return /(page_view|cta_click|analytics|newsletter_signup|outbound_cta)/i.test(text);
});
const ledgerFiles = walk(repoRoot, (path) => /\.(ts|tsx|js|jsx|json|md|csv)$/.test(path)).filter((path) => {
  const rel = relative(repoRoot, path).toLowerCase();
  const text = readText(path);
  return /ledger|revenue/.test(rel) || /(weekly revenue|revenue mix|affiliate|ads)/i.test(text);
});
const ritualFiles = walk(repoRoot, (path) => /\.(ts|tsx|js|jsx|html|md)$/.test(path)).filter((path) => {
  const text = readText(path);
  return /\/ritual|\/lab/.test(text);
});
const contentHtmlSamples = publicHtmlFiles.slice(0, 3).map((path) => {
  const html = readText(path);
  const hasInlineArticle = /<(article|main|h1)\b/i.test(html) && !/<div id="root"><\/div>\s*<\/body>/i.test(html);
  return `${relative(repoRoot, path)} :: ${hasInlineArticle ? 'inline-content-detected' : 'html-needs-manual-check'}`;
});
const serverFile = join(repoRoot, 'packages', 'cli', 'src', 'server.ts');
const serverText = readText(serverFile);
const serverNotes = [];
if (serverText.includes('SPA fallback')) {
  serverNotes.push('packages/cli/src/server.ts still contains a global SPA fallback block');
}
if (/\/ritual|\/lab/.test(serverText)) {
  serverNotes.push('packages/cli/src/server.ts references ritual/lab routes');
}
if (/manifest|workflow|hub|compare/.test(serverText)) {
  serverNotes.push('packages/cli/src/server.ts references content-route concepts or manifests');
}

let failures = 0;
function check(condition, label, successDetail, failureDetail) {
  if (condition) {
    console.log(`PASS ${label}: ${successDetail}`);
  } else {
    console.log(`FAIL ${label}: ${failureDetail}`);
    failures += 1;
  }
}

console.log('# domain-cashflow-ops verification snapshot');
console.log(`repo: ${repoRoot}`);

check(contentPackages.length > 0, 'content package', `found ${contentPackages.join(', ')}`, 'no non-baseline content package found under packages/');
check(publicHtmlFiles.length > 0, 'pre-rendered html', `found ${publicHtmlFiles.length} content HTML artifact(s)`, 'only the ritual SPA index.html is present in dist outputs');
check(routeManifests.length > 0, 'route manifest', `found ${routeManifests.length} manifest/sitemap candidate(s)`, 'no manifest/sitemap candidate found');
check(analyticsFiles.length > 0, 'analytics hooks', `found ${analyticsFiles.length} analytics/CTA candidate file(s)`, 'no analytics/CTA/newsletter signals found');
check(ledgerFiles.length > 0, 'revenue ledger', `found ${ledgerFiles.length} ledger/revenue candidate file(s)`, 'no revenue ledger candidate found');
check(ritualFiles.length > 0, 'ritual preservation', `found ${ritualFiles.length} ritual/lab reference file(s)`, 'no /ritual or /lab reference found');

printSection('content packages', contentPackages);
printSection('public html artifacts', summarize(publicHtmlFiles));
printSection('manifest candidates', summarize(routeManifests));
printSection('analytics candidates', summarize(analyticsFiles.slice(0, 20)));
printSection('revenue ledger candidates', summarize(ledgerFiles.slice(0, 20)));
printSection('ritual/lab references', summarize(ritualFiles.slice(0, 20)));
printSection('content html samples', contentHtmlSamples);
printSection('server notes', serverNotes);

if (failures > 0) {
  console.log(`\nSummary: ${failures} required verification area(s) are still missing.`);
  process.exitCode = 1;
} else {
  console.log('\nSummary: all required verification areas have detectable artifacts.');
}
