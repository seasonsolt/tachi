# Content Ops Analytics + Revenue Ledger Contract

Owner: worker-4 analytics/CTA/revenue-ledger lane  
Scope: isolated helpers/specs only — no homepage/layout/shared route edits.

## Phase-1 domain guard
- Public domain under active development remains `e-acc.ai` only.
- The analytics + revenue ledger layer should reject or ignore phase-1 writes for any other public domain.

## Narrow integration contract for the content shell
These hooks are intentionally small so worker-1 can wire them into the eventual crawlable site package without route-shell overlap.

### Proposed endpoints
1. `POST /api/content/events`
   - Accepts one `ContentEvent` payload.
   - Initial event names:
     - `page_view`
     - `cta_click`
     - `newsletter_signup`
     - `ad_impression`
     - `revenue_recorded`
2. `POST /api/content/newsletter`
   - Accepts one `NewsletterLeadCapture` payload or a browser-side input that is normalized server-side.
3. `POST /api/content/revenue`
   - Accepts one `RevenueLedgerEntry` payload.
   - Used by manual ops or lightweight admin tooling until a richer CMS exists.

## Event naming / payload rules
- `page_view`: emitted once the content page loads/hydrates.
- `cta_click`: emitted for affiliate/referral/internal/newsletter CTA taps.
- `newsletter_signup`: emitted after consented email submission; store only a SHA-256 email hash.
- `ad_impression`: emitted when an ad slot is actually rendered.
- `revenue_recorded`: mirrors weekly ledger entries so revenue mix can be audited alongside CTA data.

## Revenue-source categories
Weekly ledger totals should roll up into:
- `ads`
- `affiliate`
- `sponsorship`
- `other`

## File map
- `packages/cli/src/content-ops/contracts.ts`
  - Type contracts, event builders, week-bucket logic, path normalization, email hashing.
- `packages/cli/src/content-ops/event-store.ts`
  - NDJSON event log + newsletter lead persistence helpers.
- `packages/cli/src/content-ops/revenue-ledger.ts`
  - Weekly ledger entry helpers + snapshot generation.

## Default artifact paths
- Events log: `~/.eacc/content-ops/content-events.ndjson`
- Newsletter lead file: `~/.eacc/content-ops/newsletter-leads.json`
- Weekly revenue ledger: `~/.eacc/content-ops/weekly-revenue-ledger.json`

## Suggested worker-1 integration points (when shell exists)
1. Page analytics helper invoked from prerendered content templates after hydration.
2. CTA component wrapper calls `createCtaClickEvent(...)` before navigation.
3. Newsletter form posts to `/api/content/newsletter` and emits `newsletter_signup`.
4. Manual weekly revenue entry form or script posts to `/api/content/revenue`.

## Verification intent
The contract is shaped so final verification can prove:
- CTA clicks are attributable by page/cluster/path.
- Newsletter capture is supported without storing raw emails in the analytics log.
- Weekly revenue can be summed by source category for the `$50/month` north-star check.
