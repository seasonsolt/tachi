# TODOS

## Pre-implementation Research

### TODO: Verify Anthropic Admin API behavior
- **What:** Confirm request rate limits, data latency, billing granularity for `/v1/organizations/usage_report/messages` endpoint
- **Why:** If the API doesn't support 1-minute granularity or has strict rate limits, the data layer polling strategy needs to change
- **Context:** API requires admin key (`sk-ant-admin...`), not regular API key. Docs suggest 1-minute bucket granularity is available but rate limits are undocumented.
- **Status:** Open

### TODO: Confirm music source SDK limitations
- **What:** Validate Spotify Web Playback SDK (Premium requirement?), YouTube embed autoplay restrictions, and source CC0/royalty-free ambient tracks for default playlist
- **Why:** User chose "user-selectable music source" which involves three independent integrations
- **Context:** YouTube integration already exists in `useAudio.ts`. Spotify and local file support TBD. Need 3-5 CC0 ambient tracks (10+ min each) as default/fallback.
- **Status:** Open

### TODO: Document local file formats for Claude Code and Codex CLI
- **What:** Inspect `~/.claude/stats-cache.json` and `~/.codex/` SQLite database, document schema, write TypeScript type definitions
- **Why:** These file formats have no official documentation and may change between versions
- **Context:** Parsers already exist in both `claude-code.ts` and `StatsWatcher.swift` but are based on reverse engineering. Codex SQLite support exists in Swift (`SessionMonitor.swift`) but not in TypeScript.
- **Status:** Open
- **Blocked by:** Claude Code and Codex CLI must be installed locally

## Architecture

### TODO: Unify pricing tables between TypeScript and Swift
- **What:** Model pricing is hardcoded in both `eacc-screen/packages/cli/src/collectors/claude-code.ts` and `eacc-panel/Sources/EACCMonitor/StatsWatcher.swift`
- **Why:** When new models launch, both must be updated independently — easy to miss one
- **Options:** Shared JSON file that both read, or single source of truth generated at build time
- **Status:** Open

### TODO: Add Codex session collector to TypeScript CLI
- **What:** Swift `SessionMonitor.swift` scans `~/.codex/session_index.jsonl` + day-organized session files, but the TypeScript CLI (`claude-sessions.ts`) only watches Claude Code sessions
- **Why:** Parity between macOS app and web experience
- **Status:** Open

### TODO: Add tests
- **What:** No test infrastructure exists in either project
- **Priority areas:** Shared package (formatters, milestone logic), collectors (parsing), WebSocket message serialization
- **Status:** Open

### TODO: CI/CD pipeline
- **What:** Set up GitHub Actions for lint, typecheck, test, and build verification
- **Status:** Open

## Features

### TODO: Milestone visual effects
- **What:** 6 milestone tiers defined in constants but visual effects only partially implemented in the client
- **Effects needed:** flash (10K), color pulse (100K), particle burst (500K), screen glow (1M), theme shift (5M), permanent unlock (10M / singularity theme)
- **Status:** Open

### TODO: Spotify integration for audio
- **What:** Add Spotify Web Playback as a third audio source alongside YouTube and local file
- **Blocker:** Requires Spotify Premium, needs API key management
- **Status:** Open
- **Blocked by:** Music source SDK research

### TODO: Web mode Claude Code data
- **What:** In web mode (no local CLI server), Claude Code stats are unavailable. Consider a remote relay or cloud sync option.
- **Status:** Open

## Design

### TODO: Update DESIGN.md to cover all 5 themes
- **What:** DESIGN.md only documents 2 themes (Ancient Altar, Cyber Shrine) but code has 5: cyber, bladerunner, matrix, blood, singularity
- **Why:** Design system should be the single source of truth for all visual decisions
- **Status:** Open

### TODO: Companion pet design specs
- **What:** The macOS floating pet window has 5 themed companions (Laughing Man, Voight-Kampff Eye, Matrix Agent, NERV Hex, Singularity) but no design spec
- **Status:** Open

## Infrastructure

### TODO: Document Cloudflare Worker deployment
- **What:** `packages/worker/` has a wrangler.toml but no deployment docs or environment setup instructions
- **Status:** Open

### TODO: macOS app distribution
- **What:** Currently built via `./build.sh` locally. No code signing, notarization, or distribution mechanism.
- **Status:** Open
