# Verification Evidence Pack Support

This worker lane owns the checklist and source artifacts that make final verification easier once the crawlable content surface ships.

## Evidence categories

### 1. Content inventory proof
Required artifacts:
- `content/launch-batch.json`
- Markdown source files for home, hub, workflow, comparison, and ritual/lab pages
- `ops/90-day-cadence.md`
- `ops/weekly-revenue-ledger.csv`

### 2. Crawlable HTML proof
Target proof once routing/build lands:
1. Capture generated HTML or `curl` output for `/`.
2. Capture generated HTML or `curl` output for one hub route.
3. Capture generated HTML or `curl` output for one workflow route.
4. Capture generated HTML or `curl` output for one comparison route.
5. Confirm the returned HTML includes page title + body copy before client-side JS runs.

Suggested command shape after local server/build support exists:
```bash
curl -s http://localhost:<port>/workflow/<slug> | sed -n '1,80p'
```

### 3. Route manifest proof
Expected verification goals:
- Every launch-batch slug resolves to a content route entry.
- Public content routes do not rely on the ritual SPA fallback.
- `/ritual` remains reachable as the preserved lab route.

### 4. Analytics / CTA proof
Expected evidence to capture after implementation:
- One `page_view` event tied to a content slug.
- One outbound CTA click event tied to a workflow or comparison slug.
- One newsletter capture event.
- One sample weekly ledger update that records revenue-source mix.

### 5. Ops / north-star proof
The weekly operating artifacts should answer:
- How many pages are live?
- How many of them are workflows vs comparisons?
- Which cluster is driving the most CTA activity?
- What is the revenue mix (ads / affiliate / sponsorship / other)?
- Is the site on pace toward `$50/month`?

## Review checklist
- [ ] Required frontmatter fields exist in every content markdown source.
- [ ] Workflows remain the primary page type in launch artifacts.
- [ ] `e-accs.com` appears only as deferred backlog, not as an active route.
- [ ] Revenue ledger columns can answer the north-star question without external spreadsheets.
- [ ] The ritual route is explicitly preserved and linked from the content system.
