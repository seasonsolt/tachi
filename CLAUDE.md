# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A monorepo for **EACC** — an ambient second-monitor experience that frames AI token consumption as a sacred "offering" ritual. Two projects:

- **`eacc-screen/`** — Web app + CLI server (TypeScript, pnpm monorepo)
- **`eacc-panel/`** — macOS menu bar app (Swift, SwiftPM)

Both communicate via WebSocket on port 3666 and sync theme state through `~/.eacc/theme.json`.

## Build & Run Commands

### eacc-screen (web + server)

```bash
cd eacc-screen
pnpm install                              # Install dependencies
pnpm -F @eacc/client build                # Build client SPA
pnpm -F cli dev                           # Start CLI server (port 3666, opens browser)
pnpm -F @eacc/client dev                  # Vite dev server (port 5173, proxies /ws to 3666)
pnpm -r build                             # Build all packages
```

### eacc-panel (macOS app)

```bash
cd eacc-panel
./build.sh                                # swift build → .app bundle
# Result: .build/EACCMonitor.app
```

## Architecture

### eacc-screen packages

| Package | What | Key files |
|---------|------|-----------|
| `packages/shared` | Types, constants, milestones, scriptures, 5 theme definitions | `types.ts`, `constants.ts` |
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

Theme changes propagate: any client → WebSocket → server writes `~/.eacc/theme.json` → macOS app's ThemeWatcher picks up → and vice versa. Both Swift and TypeScript share the same theme names and color values.

### eacc-panel architecture

Native SwiftUI menu bar app (`LSUIElement: true`). Major subsystems:
- **EACCBridge** — aggregates all watchers, broadcasts WebSocket messages
- **WebSocketServer** — NWListener on port 3666
- **StatsWatcher** — watches `~/.claude/stats-cache.json`
- **SessionMonitor** — scans Claude Code + Codex session files
- **ThemeSystem** — 5 anime-themed modes with companion pet views (Ghost in the Shell, Blade Runner, Matrix, Evangelion, Singularity)
- **FloatingPetWindow** — draggable NSPanel with mood-reactive companion

### Wire protocol

`EACCTypes.swift` and `packages/shared/src/types.ts` define the same WebSocket message types: `token_update`, `session_update`, `theme_change`, `milestone`, `connected`, `error`.

## Design System

**Read `eacc-screen/DESIGN.md` before any visual changes.** Key constraints:
- 0px border-radius everywhere (monument feel)
- Opacity hierarchy: hero 1.0, scripture 0.6, peripherals 0.3-0.5
- 5 themes: cyber, bladerunner, matrix, blood, singularity
- CSS particles only (no WebGL)
- Desktop-only (mobile shows redirect message)

## Important Conventions

- Config persists to `~/.eacc/config.json` (API keys) and `~/.eacc/theme.json` (theme)
- Milestones are hardcoded at 6 tiers (10K → 10M tokens) with Chinese names and effects
- Pricing tables for Claude models are hardcoded in both `claude-code.ts` and `StatsWatcher.swift` — update both when models change
- The client uses Zustand for state and localStorage for persistence (theme, volume, focus duration, API keys)

# gstack

For all web browsing, use the `/browse` skill from gstack. Never use `mcp__claude-in-chrome__*` tools.

## Troubleshooting

If gstack skills aren't working, run `cd .claude/skills/gstack && ./setup` to build the binary and register skills.
