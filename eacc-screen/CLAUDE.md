# EACC Screen

Full-screen web experience that frames AI token consumption as a sacred "offering" ritual. Designed for a second monitor during vibe coding sessions.

## Quick Start
```bash
pnpm install
pnpm -F @eacc/client build
pnpm -F cli dev
```

## Architecture
- `packages/shared` — Types, constants, scriptures, milestones
- `packages/cli` — Node.js server (Hono + WebSocket) on port 3666
- `packages/client` — Vite + React SPA with CSS particles
- `packages/worker` — Cloudflare Worker CORS proxy

## Design System
Always read DESIGN.md before making any visual or UI decisions.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.
