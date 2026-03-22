# TODOS

## Agent-Native

### TODO: Agent onboarding flow polish
- **What:** First-launch experience: agent auto-detects installed AI tools + env credentials, greets user, sets up recipes
- **Context:** AgentCore auto-detects 12 provider env vars. Onboarding triggers via `triggerOnboarding()` in ViewModel. Needs UX polish for the chat flow.
- **Status:** Open

### TODO: Wire RecipeRuntime as primary data source
- **What:** Currently EACCBridge uses both hardcoded watchers (StatsWatcher) AND RecipeRuntime. Migrate fully to RecipeRuntime as the single source of truth.
- **Why:** Avoid duplicate data from StatsWatcher + recipe runtime both watching the same file
- **Status:** Open

### TODO: Agent can answer usage questions from collected data
- **What:** `query_data` tool currently reads raw stats-cache.json. Should query RecipeRuntime's aggregated data for accurate cross-source answers.
- **Status:** Open

## Pre-implementation Research

### TODO: Verify Anthropic Admin API behavior
- **What:** Confirm request rate limits, data latency, billing granularity for `/v1/organizations/usage_report/messages` endpoint
- **Status:** Open

### TODO: Confirm music source SDK limitations
- **What:** Validate Spotify Web Playback SDK, YouTube autoplay restrictions, source CC0 ambient tracks
- **Status:** Open

## Architecture

### TODO: Unify pricing tables between TypeScript and Swift
- **What:** Model pricing hardcoded in both `claude-code.ts` and `StatsWatcher.swift` — easy to miss when models change
- **Options:** Shared JSON file, or agent-maintained pricing via `update_recipe`
- **Status:** Open

### TODO: Add tests
- **What:** No test infrastructure exists in either project
- **Priority areas:** Shared package (formatters, milestone logic), AgentCore tool execution, RecipeRuntime JSONPath extraction
- **Status:** Open

### TODO: CI/CD pipeline
- **What:** Set up GitHub Actions for lint, typecheck, test, and build verification
- **Status:** Open

## Features

### TODO: Milestone visual effects
- **What:** 6 milestone tiers defined but effects only partially implemented
- **Effects needed:** flash (10K), color pulse (100K), particle burst (500K), screen glow (1M), theme shift (5M), permanent unlock (10M)
- **Status:** Open

### TODO: Web mode Claude Code data
- **What:** In web mode (no local CLI server), Claude Code stats are unavailable
- **Status:** Open

## Design

### TODO: Update DESIGN.md to cover all 4 themes
- **What:** DESIGN.md still documents old 2-theme system. Needs rewrite for: cyber, matrix, amber, void
- **Status:** Open

## Infrastructure

### TODO: Document Cloudflare Worker deployment
- **What:** `packages/worker/` has a wrangler.toml but no deployment docs
- **Status:** Open

### TODO: macOS app distribution
- **What:** Currently built via `./build.sh` locally. No code signing, notarization, or distribution mechanism.
- **Status:** Open
