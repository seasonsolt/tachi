# TODOS

## Pre-implementation Research

### TODO: Verify Anthropic Admin API behavior
- **What:** Confirm request rate limits, data latency, billing granularity for `/v1/organizations/usage_report/messages` endpoint
- **Why:** If the API doesn't support 1-minute granularity or has strict rate limits, the data layer polling strategy needs to change
- **Context:** API requires admin key (`sk-ant-admin...`), not regular API key. Docs suggest 1-minute bucket granularity is available but rate limits are undocumented. Test with a real admin key and measure actual response latency.
- **Status:** Open
- **Blocked by:** Nothing

### TODO: Confirm music source SDK limitations
- **What:** Validate Spotify Web Playback SDK (Premium requirement?), YouTube embed autoplay restrictions, and source CC0/royalty-free ambient tracks for default playlist
- **Why:** User chose "user-selectable music source" which involves three independent integrations. Need to confirm feasibility before writing integration code.
- **Context:** Spotify Web Playback SDK likely requires Premium. YouTube has autoplay restrictions that require user interaction first. Need 3-5 CC0 ambient tracks (10+ min each) as default/fallback.
- **Status:** Open
- **Blocked by:** Nothing

### TODO: Document local file formats for Claude Code and Codex CLI
- **What:** Inspect `~/.claude/stats-cache.json` and `~/.codex/` SQLite database on a real machine, document the schema, and write TypeScript type definitions for the parsers
- **Why:** These file formats have no official documentation and may change between versions. Parsers must be based on actual file contents, not guesses.
- **Context:** Claude Code stores daily token usage by model in stats-cache.json. Codex CLI moved to SQLite. Both may change format without notice — parsers should be defensive with schema validation.
- **Status:** Open
- **Blocked by:** Claude Code and Codex CLI must be installed locally

## Design System

### TODO: Generate complete DESIGN.md via /design-consultation
- **What:** Run /design-consultation to create a formal design system document covering color palette, typography, spacing, motion, and component patterns
- **Why:** This product is 100% visual experience. Without a formal design system, implementation will have visual inconsistencies between themes, states, and components.
- **Context:** Design review (2026-03-20) defined core design tokens (spacing 8px base, 0px border-radius, font size hierarchy, animation timing) and two themes (Ancient Altar + Cyber Shrine). DESIGN.md should codify these into a complete reference. Design doc at `~/.gstack/projects/garrytan/Thin-unknown-design-20260320-191759.md`.
- **Status:** Open
- **Blocked by:** Nothing
