# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A monorepo for **EACC** — an ambient second-monitor experience that frames AI token consumption as a sacred "offering" ritual. Two projects:

- **`eacc-screen/`** — Web app + CLI server (TypeScript, pnpm monorepo)
- **`eacc-panel/`** — macOS menu bar app (Swift, SwiftPM) — also an **agent-native** app with LLM capabilities

Both communicate via WebSocket on port 3666 and sync theme state through `~/.eacc/theme.json`.

## Build & Run Commands

### eacc-screen (web + server)

```bash
cd eacc-screen
pnpm install                              # Install dependencies
pnpm -F @eacc/client build                # Build client SPA
pnpm -F eacc-screen dev                   # Start CLI server (port 3666, opens browser)
pnpm -F @eacc/client dev                  # Vite dev server (port 5173, proxies /ws to 3666)
pnpm -r build                             # Build all packages
```

### eacc-panel (macOS app)

```bash
cd eacc-panel
./build.sh                                # swift build → .app bundle
# Result: EACCMonitor.app
```

## Architecture

### eacc-screen packages

| Package | What | Key files |
|---------|------|-----------|
| `packages/shared` | Types, constants, milestones, scriptures, 4 theme definitions | `types.ts`, `constants.ts` |
| `packages/cli` | Hono HTTP + WebSocket server, 4 data collectors | `server.ts`, `collectors/*.ts` |
| `packages/client` | Vite + React 19 SPA, Zustand state, CSS particle system | `App.tsx`, `stores/store.ts`, `hooks/useWebSocket.ts` |
| `packages/worker` | Cloudflare Worker CORS proxy for web-mode API calls | `index.ts` |

### Data flow

The CLI server runs 4 collectors in parallel:
- **claude-code** — watches `~/.claude/stats-cache.json` (file watcher)
- **anthropic-api** — polls Anthropic Admin API (requires `sk-ant-admin` key)
- **openai-api** — polls OpenAI usage API
- **claude-sessions** — watches `~/.claude/sessions/` for active sessions

Collectors feed `buildTokenData()` in `server.ts`, which aggregates and broadcasts `token_update` messages via WebSocket.

### Dual operation modes

- **CLI mode**: Client connects to local WebSocket server, gets real-time data from all 3 sources
- **Web mode**: Client polls Anthropic/OpenAI APIs directly through the Cloudflare Worker CORS proxy (no Claude Code data)

### Cross-process theme sync

Theme changes propagate: any client → WebSocket → server writes `~/.eacc/theme.json` → macOS app's ThemeWatcher (mtime polling, 1s) picks up → and vice versa.

### eacc-panel architecture

Native SwiftUI menu bar app (`LSUIElement: true`). Three layers:

**Agent Layer (agent-native):**
- **AgentCore** — Anthropic Messages API client with tool-use conversation loop. Auto-detects credentials from env vars (`ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, `ANTHROPIC_BASE_URL`). Supports both `x-api-key` and Bearer auth.
- **AgentTools** — 6 tools: `http_probe`, `create_recipe`, `update_recipe`, `list_recipes`, `query_data`, `get_system_info`. Agent uses these to discover APIs, configure collectors, and answer usage questions.
- Auto-detects 12 AI provider env vars (OpenAI, OpenRouter, Together, Groq, Fireworks, Mistral, Google, DeepSeek, Perplexity, Cohere)

**Recipe Layer (dynamic collectors):**
- **Recipe** — Declarative collector config (api_poll or file_watch type). Stored as JSON in `~/.eacc/recipes/`
- **RecipeRuntime** — Executes recipes: HTTP polling with auth + JSONPath extraction, or file watching with built-in parsers
- 3 built-in recipes pre-installed: claude-code, anthropic-api, openai-api
- Agent can create new recipes at runtime for any API

**Infrastructure Layer:**
- **EACCBridge** — aggregates hardcoded + dynamic sources, broadcasts WebSocket messages
- **WebSocketServer** — NWListener on port 3666
- **StatsWatcher** — watches `~/.claude/stats-cache.json`
- **ThemeSystem** — 4 themes with companion pet views
- **FloatingPetWindow** — draggable NSPanel with mood-reactive companion

### Wire protocol

`EACCTypes.swift` and `packages/shared/src/types.ts` define the same WebSocket message types: `token_update`, `session_update`, `theme_change`, `milestone`, `connected`, `error`.

## Design System

**Read `eacc-screen/DESIGN.md` before any visual changes.** Key constraints:
- 0px border-radius everywhere (monument feel)
- Opacity hierarchy: hero 1.0, scripture 0.6, peripherals 0.3-0.5
- 4 themes: cyber, matrix, amber, void (light theme)
- CSS particles only (no WebGL)
- Desktop-only (mobile shows redirect message)

## Important Conventions

- Config persists to `~/.eacc/config.json` (API keys) and `~/.eacc/theme.json` (theme)
- Agent persists to `~/.eacc/agent/config.json` (API key) and `~/.eacc/agent/history.json` (conversation)
- Recipes persist to `~/.eacc/recipes/*.json` (collector configs)
- Milestones are hardcoded at 6 tiers (10K → 10M tokens) with Chinese names and effects
- Pricing tables for Claude models are hardcoded in both `claude-code.ts` and `StatsWatcher.swift` — update both when models change
- The client uses Zustand for state and localStorage for persistence (theme, volume, focus duration, API keys)
- Panel Views.swift uses `vm.themeColors.*` for all colors — no hardcoded color globals (except semantic `redAccent`/`purpleAccent` for status indicators)

# gstack

For all web browsing, use the `/browse` skill from gstack. Never use `mcp__claude-in-chrome__*` tools.

## Troubleshooting

If gstack skills aren't working, run `cd .claude/skills/gstack && ./setup` to build the binary and register skills.
