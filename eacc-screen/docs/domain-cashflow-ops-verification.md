# domain-cashflow-ops verification checklist

Last updated: 2026-04-16

## Purpose
This checklist is the verification lane for the PRD/test-spec in `.omx/plans/prd-domain-cashflow-ops.md` and `.omx/plans/test-spec-domain-cashflow-ops.md`.
It is intentionally read-only against the app runtime until the content/site skeleton lands.

## Exact commands

### Install
```bash
cd eacc-screen && pnpm install
```

### Typecheck + production build
```bash
cd eacc-screen && pnpm build
```

### Existing unit tests
```bash
cd eacc-screen && pnpm -F eacc-screen test
```

### Client test command without false-failing on an empty suite
```bash
cd eacc-screen/packages/client && pnpm exec vitest run --passWithNoTests
```

### Artifact / contract audit
```bash
cd eacc-screen && node ./scripts/verify-domain-cashflow-ops.mjs
# or audit the integrated leader tree from the worker harness
node /Users/Thin/Source/git/seasonsolt/e-acc-team-domain-cashflow-ops/.omx/team/execute-omx-plans-prd-domain-c/worktrees/worker-2/eacc-screen/scripts/verify-domain-cashflow-ops.mjs /Users/Thin/Source/git/seasonsolt/e-acc-team-domain-cashflow-ops/eacc-screen
```

### Non-JS crawlability smoke check
After the content package and public slugs exist:
```bash
cd eacc-screen && pnpm build
cd eacc-screen && node packages/cli/dist/index.js --port 4173 --no-open
curl -s http://127.0.0.1:4173/<public-content-slug> | tee /tmp/domain-cashflow-ops.html
grep -E '<title>|<main|<article|<h1' /tmp/domain-cashflow-ops.html
```
Pass criteria:
- The fetched HTML contains real page content before JS executes.
- The response is not just `<div id="root"></div>` plus one script tag.
- The route resolves without falling through to a global SPA fallback for public content pages.

### Route-manifest spot check
```bash
cd eacc-screen && find . -type f \( -name '*manifest*.json' -o -name '*routes*.json' -o -name 'sitemap*.xml' \)
```
Pass criteria:
- Published slugs are enumerated by a route manifest or sitemap artifact.
- Manifest entries line up with emitted HTML files.

### Analytics / revenue-ledger spot check
```bash
cd eacc-screen && rg -n 'page_view|cta_click|analytics|newsletter_signup|revenue_recorded|ledger|revenue' packages docs
```
Pass criteria:
- Pageview tracking exists for the content surface.
- Outbound CTA tracking exists for monetized links.
- Newsletter/email capture is present if claimed.
- A weekly revenue ledger artifact exists and distinguishes at least ads vs affiliate/referral.

## Baseline findings before the content skeleton landed
- `cd eacc-screen && pnpm build` — PASS on the pre-content ritual baseline.
- `cd eacc-screen && pnpm test` — FAIL on the baseline because `@eacc/client` has no test files and Vitest exits with code 1.
- `packages/client/dist/` currently contains only the ritual SPA shell (`index.html`, one JS bundle, ambient audio asset).
- `packages/cli/src/server.ts` currently serves unknown routes through a global SPA fallback.
- No route-manifest, content HTML batch, analytics verification surface, or weekly revenue ledger artifact exists yet on the baseline.

## Integrated leader checkpoint — 2026-04-16
Verification target: `/Users/Thin/Source/git/seasonsolt/e-acc-team-domain-cashflow-ops/eacc-screen`

### PASS
- `cd /Users/Thin/Source/git/seasonsolt/e-acc-team-domain-cashflow-ops/eacc-screen && pnpm install`
  - Install completed successfully for all 6 workspace projects.
  - Follow-up `git status --short eacc-screen/pnpm-lock.yaml` stayed clean, so verification left no lockfile drift behind.
- `cd /Users/Thin/Source/git/seasonsolt/e-acc-team-domain-cashflow-ops/eacc-screen && pnpm -F @eacc/site test`
  - PASS: 3/3 `packages/site/src/lib.test.mjs` checks green.
- `cd /Users/Thin/Source/git/seasonsolt/e-acc-team-domain-cashflow-ops/eacc-screen/packages/client && pnpm exec vitest run --passWithNoTests`
  - PASS: client package currently has no tests, but the explicit `--passWithNoTests` check exits 0.
- `cd /Users/Thin/Source/git/seasonsolt/e-acc-team-domain-cashflow-ops/eacc-screen/packages/cli && pnpm exec vitest run src/content-site.test.ts src/content-ops/contracts.test.ts src/content-ops/event-store.test.ts src/content-ops/revenue-ledger.test.ts`
  - PASS: 4 files / 11 tests green for content routing + analytics + ledger helpers.

### FAIL
- `cd /Users/Thin/Source/git/seasonsolt/e-acc-team-domain-cashflow-ops/eacc-screen && pnpm build`
  - FAIL in `packages/site build`.
  - Blocking error: a launch content file was missing required frontmatter such as `description`.
- `node /Users/Thin/Source/git/seasonsolt/e-acc-team-domain-cashflow-ops/.omx/team/execute-omx-plans-prd-domain-c/worktrees/worker-2/eacc-screen/scripts/verify-domain-cashflow-ops.mjs /Users/Thin/Source/git/seasonsolt/e-acc-team-domain-cashflow-ops/eacc-screen`
  - FAIL: no emitted pre-rendered HTML artifacts yet.
  - FAIL: no route manifest / sitemap artifact detected yet.
  - PASS: content package (`packages/site`), analytics/content-ops helpers, revenue ledger artifacts, and ritual/lab references are present.

### Current blocker summary
- Build completeness is the blocker, not the verification harness.
- Until the missing frontmatter is fixed and the site build emits artifacts, non-JS crawlability and manifest proof remain blocked downstream.

## Final acceptance checklist
- [ ] `e-acc.ai` remains the only active phase-1 domain; `e-accs.com` is deferred.
- [ ] Build passes after the new content surface lands.
- [ ] Workflow/tutorial pages are primary; comparison pages are secondary.
- [ ] Public content routes resolve to emitted HTML artifacts.
- [ ] At least one workflow page proves non-JS crawlable HTML.
- [ ] Route manifest/sitemap enumerates published slugs.
- [ ] `/ritual` or `/lab` still preserves the legacy ritual experience.
- [ ] Analytics events cover `page_view`, `cta_click`, and `newsletter_signup`.
- [ ] Weekly revenue ledger exists with revenue-source mix.
- [ ] Evidence summary can report published page count, cluster coverage, CTA tracking, and revenue mix.
