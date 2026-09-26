import {
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  escapeAttribute,
  escapeHtml,
  formatDateLabel,
  isExternalUrl,
  markdownToHtml,
  normalizePath,
  parseFrontmatter,
} from './lib.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, '../../..');
const contentRoot = join(projectRoot, 'content');
const distRoot = join(projectRoot, 'packages', 'site', 'dist');
const cssSource = join(__dirname, 'site.css');
const generatedAt = new Date().toISOString();
const phaseOneDomain = 'e-acc.ai';
const deferredDomain = 'e-accs.com';
const siteTitle = 'e/acc AI builder playbooks';
const siteDescription = 'Workflow-first, crawlable operating guides for AI builders shipping on a 5–10 hour weekly cadence.';
const siteUrl = `https://${phaseOneDomain}`;
const requiredMeta = ['slug', 'title', 'cluster', 'intent', 'ctaType', 'updatedAt', 'monetizationMode', 'description'];

const collectionConfig = [
  { dir: 'hubs', kind: 'hub', routePrefix: '/hub' },
  { dir: 'workflows', kind: 'workflow', routePrefix: '/workflow' },
  { dir: 'comparisons', kind: 'comparison', routePrefix: '/compare' },
];
const launchBatchConfig = JSON.parse(readFileSync(join(contentRoot, 'launch-batch.json'), 'utf8'));

function ensureDir(targetPath) {
  mkdirSync(dirname(targetPath), { recursive: true });
}

function writeFile(relativePath, content) {
  const targetPath = join(distRoot, relativePath);
  ensureDir(targetPath);
  writeFileSync(targetPath, content);
}

function invariant(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function loadCollection(config) {
  const dir = join(contentRoot, config.dir);
  const files = readdirSync(dir).filter((file) => file.endsWith('.md')).sort();

  return files.map((fileName) => {
    const filePath = join(dir, fileName);
    const raw = readFileSync(filePath, 'utf8');
    const { meta, body } = parseFrontmatter(raw);

    for (const key of requiredMeta) {
      invariant(meta[key], `${relative(projectRoot, filePath)} is missing frontmatter field "${key}"`);
    }

    invariant(Array.isArray(meta.monetizationMode) && meta.monetizationMode.length > 0, `${relative(projectRoot, filePath)} must define at least one monetizationMode`);
    invariant(typeof meta.slug === 'string', `${relative(projectRoot, filePath)} must define a string slug`);
    invariant(typeof meta.title === 'string', `${relative(projectRoot, filePath)} must define a string title`);
    invariant(typeof meta.description === 'string', `${relative(projectRoot, filePath)} must define a string description`);
    invariant(typeof meta.updatedAt === 'string', `${relative(projectRoot, filePath)} must define updatedAt`);

    const route = normalizePath(`${config.routePrefix}/${meta.slug}`);
    const artifact = route === '/' ? 'index.html' : `${route.slice(1)}/index.html`;
    const html = markdownToHtml(body);
    const derivedRelated = [
      ...(Array.isArray(meta.relatedHubSlugs) ? meta.relatedHubSlugs.map((slug) => normalizePath(`/hub/${slug}`)) : []),
      ...(Array.isArray(meta.relatedWorkflowSlugs) ? meta.relatedWorkflowSlugs.map((slug) => normalizePath(`/workflow/${slug}`)) : []),
      ...(Array.isArray(meta.relatedComparisonSlugs) ? meta.relatedComparisonSlugs.map((slug) => normalizePath(`/compare/${slug}`)) : []),
    ];

    return {
      kind: config.kind,
      route,
      artifact,
      body,
      html,
      sourceFile: relative(projectRoot, filePath),
      slug: meta.slug,
      title: meta.title,
      description: meta.description,
      cluster: meta.cluster,
      intent: meta.intent,
      ctaType: meta.ctaType,
      ctaLabel: meta.ctaLabel || 'Open recommended tool',
      ctaHref: meta.ctaHref || null,
      ctaNote: meta.ctaNote || '',
      updatedAt: meta.updatedAt,
      monetizationMode: meta.monetizationMode,
      keywords: Array.isArray(meta.keywords) ? meta.keywords : [],
      related: Array.isArray(meta.related) ? meta.related : derivedRelated,
      hero: meta.hero || meta.description,
      status: meta.status || 'launch-batch',
    };
  });
}

function loadPageSource(fileName, kind, route, artifact) {
  const filePath = join(contentRoot, 'pages', fileName);
  const raw = readFileSync(filePath, 'utf8');
  const { meta, body } = parseFrontmatter(raw);

  for (const key of requiredMeta) {
    invariant(meta[key], `${relative(projectRoot, filePath)} is missing frontmatter field "${key}"`);
  }

  invariant(Array.isArray(meta.monetizationMode) && meta.monetizationMode.length > 0, `${relative(projectRoot, filePath)} must define at least one monetizationMode`);

  return {
    kind,
    route,
    artifact,
    body,
    html: markdownToHtml(body),
    sourceFile: relative(projectRoot, filePath),
    slug: meta.slug,
    title: meta.title,
    description: meta.description,
    cluster: meta.cluster,
    intent: meta.intent,
    ctaType: meta.ctaType,
    ctaLabel: meta.ctaLabel || 'Open recommended tool',
    ctaHref: meta.ctaHref || null,
    ctaNote: meta.ctaNote || '',
    updatedAt: meta.updatedAt,
    monetizationMode: meta.monetizationMode,
    keywords: Array.isArray(meta.keywords) ? meta.keywords : [],
    related: Array.isArray(meta.related) ? meta.related : [],
    hero: meta.hero || meta.description,
    status: meta.status || 'launch-batch',
  };
}

function sumRevenue(entries) {
  return entries.reduce((total, entry) => total + Number(entry.ads || 0) + Number(entry.affiliate || 0) + Number(entry.sponsorship || 0) + Number(entry.other || 0), 0);
}

function sumByKey(entries, key) {
  return entries.reduce((total, entry) => total + Number(entry[key] || 0), 0);
}

function formatCurrency(value) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(value);
}

function renderNav(currentRoute) {
  const items = [
    { href: '/', label: 'Home', active: currentRoute === '/' },
    { href: '/hub/ai-coding-workflows', label: 'Coding hub', active: currentRoute.startsWith('/hub/ai-coding-workflows') },
    { href: '/hub/agent-operations', label: 'Agent ops hub', active: currentRoute.startsWith('/hub/agent-operations') },
    { href: '/compare/claude-code-vs-cursor-for-shipping', label: 'Compare', active: currentRoute.startsWith('/compare/') },
    { href: '/ritual', label: 'Ritual', active: currentRoute.startsWith('/ritual') || currentRoute.startsWith('/lab') },
  ];

  return items.map((item) => `<a href="${item.href}"${item.active ? ' class="is-active"' : ''}>${item.label}</a>`).join('');
}

function renderDocument({ title, description, currentRoute, content, bodyClass = '' }) {
  const pageTitle = title === siteTitle ? title : `${title} · ${siteTitle}`;
  return `<!DOCTYPE html>
<html lang="en" style="color-scheme: dark">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="${escapeAttribute(description)}" />
    <meta property="og:title" content="${escapeAttribute(pageTitle)}" />
    <meta property="og:description" content="${escapeAttribute(description)}" />
    <meta property="og:type" content="website" />
    <meta property="og:url" content="${escapeAttribute(siteUrl + currentRoute)}" />
    <link rel="canonical" href="${escapeAttribute(siteUrl + currentRoute)}" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&family=Space+Grotesk:wght@400;500;600;700&display=swap" rel="stylesheet" />
    <link rel="stylesheet" href="/assets/site.css" />
    <title>${escapeHtml(pageTitle)}</title>
  </head>
  <body${bodyClass ? ` class="${bodyClass}"` : ''}>
    <header class="site-header">
      <div class="shell">
        <div class="brand">
          <span class="brand-mark">phase 1 · ${phaseOneDomain}</span>
          <a class="brand-title" href="/">${siteTitle}</a>
          <span class="brand-subtitle">Single-domain operating system for workflow-led monetization.</span>
        </div>
        <nav class="top-nav" aria-label="Primary">
          ${renderNav(currentRoute)}
        </nav>
      </div>
    </header>
    <main>
      <div class="shell">
        ${content}
      </div>
    </main>
    <footer class="site-footer">
      <div class="shell">
        <div>
          <strong>${siteTitle}</strong><br />
          Built for ${phaseOneDomain}. ${deferredDomain} stays dormant until the main domain earns the right to expand.
        </div>
        <div class="footer-links">
          <a href="/route-manifest.json">Route manifest</a>
          <a href="/sitemap.xml">Sitemap</a>
          <a href="/ops/dashboard.json">Ops dashboard</a>
          <a href="/ritual">Ritual screen</a>
        </div>
      </div>
    </footer>
  </body>
</html>`;
}

function renderCard(entry) {
  return `<article class="card">
    <div class="card-kicker">${entry.kind}</div>
    <h3><a href="${entry.route}">${escapeHtml(entry.title)}</a></h3>
    <p>${escapeHtml(entry.description)}</p>
    <ul class="inline-list">
      <li>${escapeHtml(entry.cluster.replace(/-/g, ' '))}</li>
      <li>Updated ${escapeHtml(formatDateLabel(entry.updatedAt))}</li>
      <li>${escapeHtml(entry.ctaType)}</li>
    </ul>
    <a class="route-path" href="${entry.route}">${entry.route}</a>
  </article>`;
}

function renderRouteCard(route) {
  return `<article class="route-card">
    <div class="card-kicker">${route.kind}</div>
    <h3>${escapeHtml(route.title)}</h3>
    <p>${escapeHtml(route.description)}</p>
    <span class="route-path">${route.path}</span>
  </article>`;
}

function renderMetaList(entry, hubTitle) {
  const monetization = entry.monetizationMode.map((mode) => `<span class="meta-pill">${escapeHtml(mode)}</span>`).join('');
  return `<ul class="meta-list">
    <li><span class="meta-label">Cluster</span><span class="meta-value"><a href="/hub/${entry.cluster}">${escapeHtml(hubTitle)}</a></span></li>
    <li><span class="meta-label">Intent</span><span class="meta-value">${escapeHtml(entry.intent)}</span></li>
    <li><span class="meta-label">Updated</span><span class="meta-value">${escapeHtml(formatDateLabel(entry.updatedAt))}</span></li>
    <li><span class="meta-label">Monetization</span><span class="meta-value">${monetization}</span></li>
    <li><span class="meta-label">Phase-1 domain</span><span class="meta-value">${phaseOneDomain}</span></li>
  </ul>`;
}

function renderRelatedLinks(entry, pageMap) {
  if (!entry.related.length) return '<p class="note">No related routes declared yet.</p>';
  const items = entry.related.map((route) => {
    const target = pageMap.get(route);
    const label = target ? target.title : route;
    return `<li><a href="${route}">${escapeHtml(label)}</a></li>`;
  }).join('');
  return `<ul>${items}</ul>`;
}

function renderPrimaryCta(entry) {
  if (entry.ctaType === 'newsletter') {
    return `<section class="newsletter-card">
      <div class="card-kicker">newsletter capture</div>
      <h2>Get the weekly operating memo</h2>
      <p>Join the low-frequency dispatch for new playbooks, revenue notes, and what actually shipped on ${phaseOneDomain}.</p>
      <form class="newsletter-form" method="post" action="/newsletter">
        <input type="hidden" name="route" value="${escapeAttribute(entry.route)}" />
        <input type="hidden" name="collection" value="${escapeAttribute(entry.kind)}" />
        <input type="hidden" name="ctaType" value="${escapeAttribute(entry.ctaType)}" />
        <label>
          <span class="meta-label">Email</span>
          <input type="email" name="email" required placeholder="builder@company.com" />
        </label>
        <input type="submit" value="Join the memo" />
      </form>
      <p class="note">Stored as a hashed analytics event for verification. No third-party embed required.</p>
    </section>`;
  }

  const href = entry.ctaHref ? `/out?route=${encodeURIComponent(entry.route)}` : '/ritual';
  const note = entry.ctaNote ? `<p class="note">${escapeHtml(entry.ctaNote)}</p>` : '';
  return `<section class="monetization-card">
    <div class="card-kicker">${escapeHtml(entry.ctaType)} CTA</div>
    <h2>${escapeHtml(entry.ctaLabel)}</h2>
    <p>Use the first-party redirect so outbound clicks are attributable to the content route that earned them.</p>
    <a class="button is-primary" href="${href}">${escapeHtml(entry.ctaLabel)}</a>
    ${note}
  </section>`;
}

function renderAdSlot(entry) {
  return `<section class="monetization-card ad-slot">
    <strong>Ads are supplemental, not the business.</strong>
    <p>This reserved block is where a future Google Ads placement can run without displacing the primary affiliate or newsletter CTA.</p>
    <ul class="inline-list">
      <li>route ${escapeHtml(entry.route)}</li>
      <li>slot inline-1</li>
      <li>mode ${escapeHtml(entry.monetizationMode.join(' / '))}</li>
    </ul>
  </section>`;
}

function renderPage(entry, pageMap, clusters) {
  const hub = clusters.get(entry.cluster);
  const hero = `<section class="page-hero">
    <div class="eyebrow">${escapeHtml(entry.kind)} · ${escapeHtml(entry.intent)}</div>
    <h1>${escapeHtml(entry.title)}</h1>
    <p>${escapeHtml(entry.hero)}</p>
    <ul class="inline-list">
      <li>${phaseOneDomain}</li>
      <li>${escapeHtml(hub ? hub.title : entry.cluster)}</li>
      <li>${escapeHtml(entry.ctaType)}</li>
    </ul>
  </section>`;

  const body = `<div class="breadcrumbs"><a href="/">Home</a> / <a href="/hub/${entry.cluster}">${escapeHtml(hub ? hub.title : entry.cluster)}</a> / ${escapeHtml(entry.title)}</div>
${hero}
<div class="page-layout">
  <div class="content-column">
    <section>
      ${entry.html}
    </section>
    <section>
      <h2>Related routes</h2>
      ${renderRelatedLinks(entry, pageMap)}
    </section>
  </div>
  <aside class="side-column">
    <section>
      <div class="card-kicker">Content metadata</div>
      ${renderMetaList(entry, hub ? hub.title : entry.cluster)}
    </section>
    ${renderPrimaryCta(entry)}
    ${renderAdSlot(entry)}
    <section class="ritual-card">
      <div class="card-kicker">Brownfield preserved</div>
      <h2>Keep the ritual on a side route</h2>
      <p>The original immersive screen remains available at <a href="/ritual">/ritual</a> so the homepage can stay crawlable without deleting the brand mythos.</p>
      <a class="button" href="/ritual">Open ritual screen</a>
    </section>
  </aside>
</div>`;

  return renderDocument({
    title: entry.title,
    description: entry.description,
    currentRoute: entry.route,
    content: body,
  });
}

function renderHubPage(entry, workflows, comparisons) {
  const clusterWorkflows = workflows.filter((item) => item.cluster === entry.slug);
  const clusterComparisons = comparisons.filter((item) => item.cluster === entry.slug);

  const body = `<div class="breadcrumbs"><a href="/">Home</a> / ${escapeHtml(entry.title)}</div>
<section class="page-hero">
  <div class="eyebrow">hub · ${escapeHtml(entry.intent)}</div>
  <h1>${escapeHtml(entry.title)}</h1>
  <p>${escapeHtml(entry.hero)}</p>
  <div class="hero-actions">
    <a class="button is-primary" href="${clusterWorkflows[0]?.route || '/'}">Start with a workflow</a>
    <a class="button" href="/ritual">Visit the ritual screen</a>
  </div>
</section>
<div class="page-layout">
  <div class="content-column">
    <section>
      ${entry.html}
    </section>
    <section>
      <div class="section-heading">
        <h2>Workflow playbooks</h2>
        <p>${clusterWorkflows.length} published</p>
      </div>
      <div class="cluster-grid">
        ${clusterWorkflows.map(renderCard).join('')}
      </div>
    </section>
    <section>
      <div class="section-heading">
        <h2>Support comparisons</h2>
        <p>${clusterComparisons.length} published</p>
      </div>
      <div class="cluster-grid">
        ${clusterComparisons.length ? clusterComparisons.map(renderCard).join('') : '<p class="note">Comparison pages are intentionally secondary to workflow content.</p>'}
      </div>
    </section>
  </div>
  <aside class="side-column">
    <section>
      <div class="card-kicker">Hub metadata</div>
      ${renderMetaList(entry, entry.title)}
    </section>
    <section class="monetization-card">
      <div class="card-kicker">Monetization posture</div>
      <h2>Ads fill. CTAs monetize intent.</h2>
      <p>Every hub keeps ad inventory visible, but the stronger move is routing readers to a workflow or comparison page with attributable CTA clicks.</p>
    </section>
    <section class="newsletter-card">
      <div class="card-kicker">newsletter capture</div>
      <h2>Capture the builder who is not ready yet</h2>
      <form class="newsletter-form" method="post" action="/newsletter">
        <input type="hidden" name="route" value="${escapeAttribute(entry.route)}" />
        <input type="hidden" name="collection" value="${escapeAttribute(entry.kind)}" />
        <input type="hidden" name="ctaType" value="newsletter" />
        <label>
          <span class="meta-label">Email</span>
          <input type="email" name="email" required placeholder="operator@startup.com" />
        </label>
        <input type="submit" value="Get the memo" />
      </form>
    </section>
  </aside>
</div>`;

  return renderDocument({
    title: entry.title,
    description: entry.description,
    currentRoute: entry.route,
    content: body,
  });
}

const ledger = JSON.parse(readFileSync(join(contentRoot, 'ops', 'weekly-revenue-ledger.json'), 'utf8'));
const homePage = loadPageSource('home.md', 'home', '/', 'index.html');
const hubs = loadCollection(collectionConfig[0]);
const workflows = loadCollection(collectionConfig[1]);
const comparisons = loadCollection(collectionConfig[2]);
const pageMap = new Map();
for (const entry of [...hubs, ...workflows, ...comparisons]) {
  invariant(!pageMap.has(entry.route), `Duplicate route detected for ${entry.route}`);
  pageMap.set(entry.route, entry);
}

const clusterMap = new Map(hubs.map((entry) => [entry.slug, entry]));
const monthlyRevenueUsd = sumRevenue(ledger.weeks);
const revenueMix = {
  ads: sumByKey(ledger.weeks, 'ads'),
  affiliate: sumByKey(ledger.weeks, 'affiliate'),
  sponsorship: sumByKey(ledger.weeks, 'sponsorship'),
  other: sumByKey(ledger.weeks, 'other'),
};
const dashboard = {
  generatedAt,
  phaseOneDomain,
  deferredDomains: [deferredDomain],
  currentMonthlyRevenueUsd: monthlyRevenueUsd,
  revenueMix,
  northStarMonthlyRevenueUsd: 50,
  hoursPerWeek: '5-10',
  targets: {
    workflowsByDay90: 8,
    comparisonsByDay90: 4,
  },
  publishedPages: {
    home: 1,
    hubs: hubs.length,
    workflows: workflows.length,
    comparisons: comparisons.length,
    total: 1 + hubs.length + workflows.length + comparisons.length,
  },
  clusters: hubs.map((hub) => ({
    slug: hub.slug,
    title: hub.title,
    workflowCount: workflows.filter((entry) => entry.cluster === hub.slug).length,
    comparisonCount: comparisons.filter((entry) => entry.cluster === hub.slug).length,
  })),
  weeklyCadence: [
    { phase: 'Weeks 1-2', focus: 'Architecture, templates, launch batch' },
    { phase: 'Weeks 3-6', focus: 'Expand to five workflows and two comparisons' },
    { phase: 'Weeks 7-12', focus: 'Reach eight workflows, four comparisons, prune weak routes' },
  ],
};

const homeContent = renderDocument({
  title: homePage.title,
  description: homePage.description,
  currentRoute: '/',
  content: `<section class="hero">
    <div class="eyebrow">phase 1 · ${phaseOneDomain} only</div>
    <h1>${escapeHtml(homePage.title)}</h1>
    <p>${escapeHtml(homePage.description)} Keep the ritual experience on <a href="/ritual">/ritual</a>, move the monetizable surface to static HTML, and make every workflow page capable of earning via ads, affiliate CTA clicks, and newsletter capture.</p>
    <div class="hero-actions">
      <a class="button is-primary" href="/hub/ai-coding-workflows">Explore coding workflows</a>
      <a class="button" href="/hub/agent-operations">See agent ops hub</a>
      <a class="button" href="/ritual">Open the ritual screen</a>
    </div>
    <div class="metrics-grid">
      <article class="metric-card"><span class="metric-label">Published routes</span><span class="metric-value">${dashboard.publishedPages.total}</span></article>
      <article class="metric-card"><span class="metric-label">Monthly revenue tracked</span><span class="metric-value">${formatCurrency(monthlyRevenueUsd)}</span></article>
      <article class="metric-card"><span class="metric-label">90-day target</span><span class="metric-value">${formatCurrency(dashboard.northStarMonthlyRevenueUsd)}</span></article>
      <article class="metric-card"><span class="metric-label">Weekly operating budget</span><span class="metric-value">5–10h</span></article>
    </div>
  </section>
  <section class="section">
    ${homePage.html}
  </section>
  <section class="section">
    <div class="section-heading">
      <h2>Launch information architecture</h2>
      <p>Homepage + ${hubs.length} hubs + ${workflows.length} workflow pages + ${comparisons.length} comparison pages + ritual preservation.</p>
    </div>
    <div class="route-grid">
      ${[
        { kind: 'home', title: 'Homepage', description: 'Static entry point that reframes the brand around workflows.', path: '/' },
        ...hubs.map((entry) => ({ kind: 'hub', title: entry.title, description: entry.description, path: entry.route })),
        ...workflows.map((entry) => ({ kind: 'workflow', title: entry.title, description: entry.description, path: entry.route })),
        ...comparisons.map((entry) => ({ kind: 'comparison', title: entry.title, description: entry.description, path: entry.route })),
        { kind: 'ritual', title: 'Ritual screen', description: 'Preserved immersive experience under a subordinate route.', path: '/ritual' },
      ].map(renderRouteCard).join('')}
    </div>
  </section>
  <section class="section">
    <div class="section-heading">
      <h2>Clusters that fit a solo-builder cadence</h2>
      <p>Workflow-first hubs carry the publication engine; comparison pages stay secondary.</p>
    </div>
    <div class="card-grid">
      ${hubs.map(renderCard).join('')}
    </div>
  </section>
  <section class="section">
    <div class="section-heading">
      <h2>Featured workflow pages</h2>
      <p>Each page ships with a CTA block, an ad slot placeholder, and a route-specific newsletter form.</p>
    </div>
    <div class="card-grid">
      ${workflows.map(renderCard).join('')}
    </div>
  </section>
  <section class="section">
    <div class="section-heading">
      <h2>Measurement and revenue ops</h2>
      <p>Server-rendered page views, tracked CTA clicks, newsletter signups, and a weekly revenue ledger.</p>
    </div>
    <div class="card-grid">
      <article class="report-card">
        <div class="card-kicker">Revenue mix</div>
        <h3>Week-over-week ledger</h3>
        <ul>
          <li>Ads: ${formatCurrency(revenueMix.ads)}</li>
          <li>Affiliate/referral: ${formatCurrency(revenueMix.affiliate)}</li>
          <li>Sponsorship: ${formatCurrency(revenueMix.sponsorship)}</li>
          <li>Other: ${formatCurrency(revenueMix.other)}</li>
        </ul>
      </article>
      <article class="report-card">
        <div class="card-kicker">Verification artifacts</div>
        <h3>What execution can inspect directly</h3>
        <ul>
          <li><a href="/route-manifest.json">Route manifest</a></li>
          <li><a href="/ops/dashboard.json">Dashboard JSON</a></li>
          <li><a href="/ops/weekly-revenue-ledger.json">Weekly revenue ledger</a></li>
          <li><a href="/sitemap.xml">Sitemap</a></li>
        </ul>
      </article>
      <article class="report-card">
        <div class="card-kicker">Domain discipline</div>
        <h3>Only one public domain is active</h3>
        <p>${phaseOneDomain} is the only live phase-1 target. ${deferredDomain} remains explicitly deferred until the first domain proves traction.</p>
      </article>
    </div>
  </section>`,
});

rmSync(distRoot, { recursive: true, force: true });
mkdirSync(distRoot, { recursive: true });
writeFile('assets/site.css', readFileSync(cssSource, 'utf8'));
writeFile('index.html', homeContent);

for (const hub of hubs) {
  writeFile(hub.artifact, renderHubPage(hub, workflows, comparisons));
}
for (const entry of [...workflows, ...comparisons]) {
  writeFile(entry.artifact, renderPage(entry, pageMap, clusterMap));
}

const routeManifest = {
  generatedAt,
  domain: phaseOneDomain,
  deferredDomains: [deferredDomain],
  contentRoutes: [
    homePage,
    ...hubs,
    ...workflows,
    ...comparisons,
  ].map((entry) => ({
    kind: entry.kind,
    path: entry.route ?? entry.path ?? '/',
    title: entry.title,
    description: entry.description,
    artifact: entry.artifact,
    updatedAt: entry.updatedAt,
    cluster: entry.cluster,
    monetizationMode: entry.monetizationMode,
    cta: entry.ctaHref ? { type: entry.ctaType, href: entry.ctaHref, label: entry.ctaLabel } : null,
    related: entry.related,
    sourceFile: entry.sourceFile,
    status: entry.status,
  })),
  ritualRoutes: [
    { path: '/ritual', strategy: 'spa-shell' },
    { path: '/ritual/*', strategy: 'spa-shell' },
    { path: '/lab', strategy: 'redirect', target: '/ritual' },
    { path: '/lab/*', strategy: 'redirect', target: '/ritual' },
  ],
  analytics: {
    page_view: 'server-side on HTML route serve',
    cta_click: '/out?route=<encoded-route>',
    newsletter_signup: 'POST /newsletter',
    report: '/api/ops/report',
  },
};

const declaredLaunchInventory = launchBatchConfig.launchBatch
  .filter((entry) => entry.pageType !== 'lab')
  .map((entry) => ({
    path: entry.path,
    pageType: entry.pageType,
    source: entry.source,
    cluster: entry.cluster,
    status: entry.status,
  }))
  .sort((left, right) => left.path.localeCompare(right.path));
const builtLaunchInventory = routeManifest.contentRoutes
  .map((entry) => ({
    path: entry.path,
    pageType: entry.kind,
    source: entry.sourceFile,
    cluster: entry.cluster,
    status: entry.status,
  }))
  .sort((left, right) => left.path.localeCompare(right.path));

invariant(
  JSON.stringify(declaredLaunchInventory) === JSON.stringify(builtLaunchInventory),
  `launch-batch.json inventory does not match built content routes:\nexpected=${JSON.stringify(declaredLaunchInventory)}\nactual=${JSON.stringify(builtLaunchInventory)}`,
);
writeFile('route-manifest.json', `${JSON.stringify(routeManifest, null, 2)}\n`);
writeFile('ops/dashboard.json', `${JSON.stringify(dashboard, null, 2)}\n`);
writeFile('ops/weekly-revenue-ledger.json', `${JSON.stringify(ledger, null, 2)}\n`);
writeFile('robots.txt', `User-agent: *\nAllow: /\nSitemap: ${siteUrl}/sitemap.xml\n`);
writeFile('sitemap.xml', `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${routeManifest.contentRoutes.map((route) => `  <url><loc>${siteUrl}${route.path}</loc><lastmod>${route.updatedAt}</lastmod></url>`).join('\n')}\n  <url><loc>${siteUrl}/ritual</loc><lastmod>${generatedAt.slice(0, 10)}</lastmod></url>\n</urlset>\n`);

console.log(JSON.stringify({
  ok: true,
  generatedAt,
  pages: routeManifest.contentRoutes.length,
  outputDir: relative(projectRoot, distRoot),
}, null, 2));
