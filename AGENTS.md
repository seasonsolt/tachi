# E-ACC Agent Guide

## Scope
- This repository contains two apps:
- `eacc-screen/` — TypeScript `pnpm` monorepo with web client, CLI server, shared types, and a Cloudflare Worker.
- `eacc-panel/` — macOS menu bar app built with SwiftUI and Swift Package Manager.
- The two apps communicate over WebSocket port `3666` and sync theme state through `~/.eacc/theme.json`.
- Session tracking is a product feature; changes may need to account for Claude Code, Codex, and OpenCode session sources.

## Existing Agent Rules
- Repo rule file exists at `CLAUDE.md`; follow it for architecture, conventions, and safety.
- Additional screen-specific rule file exists at `eacc-screen/CLAUDE.md`.
- Existing screen-specific agent note exists at `eacc-screen/AGENTS.md`, but it is minimal; use this file as the repo-wide source of truth.
- No `.cursorrules` file was found.
- No files were found under `.cursor/rules/`.
- No `.github/copilot-instructions.md` file was found.

## Working Norms
- Reply in the user's language; be concise and direct.
- Edit existing files when possible; avoid creating files unless they add clear value.
- Do not over-engineer or add speculative abstractions.
- Do not hardcode API keys, tokens, or passwords.
- Do not commit or push unless the user explicitly asks.
- Do not amend existing commits; create a new commit instead.
- Never revert unrelated user changes in a dirty worktree.

## Repository Layout
- `eacc-screen/package.json` — workspace entry point for build/test/clean.
- `eacc-screen/packages/client` — React 19 + Vite SPA.
- `eacc-screen/packages/cli` — Hono HTTP/WebSocket server and collectors.
- `eacc-screen/packages/shared` — shared TS types, constants, milestones, theme definitions.
- `eacc-screen/packages/worker` — Cloudflare Worker proxy.
- `eacc-panel/Package.swift` — SwiftPM package for the menu bar app.
- `eacc-panel/Sources/EACCMonitor` — all Swift source files.

## Install And Run
- Screen workspace install: `cd eacc-screen && pnpm install`
- Screen dev server: `cd eacc-screen && pnpm dev`
- Client-only dev: `cd eacc-screen && pnpm -F @eacc/client dev`
- CLI-only dev: `cd eacc-screen && pnpm -F eacc-screen dev`
- Worker dev: `cd eacc-screen && pnpm -F @eacc/worker dev`
- Panel app build script: `cd eacc-panel && ./build.sh`
- Panel raw Swift build: `cd eacc-panel && swift build -c release`
- Launch built panel app: `cd eacc-panel && open EACCMonitor.app`

## Build Commands
- Build all TS packages: `cd eacc-screen && pnpm build`
- Build client only: `cd eacc-screen && pnpm -F @eacc/client build`
- Build CLI only: `cd eacc-screen && pnpm -F eacc-screen build`
- Build shared package only: `cd eacc-screen && pnpm -F @eacc/shared build`
- Worker has no dedicated build script; use Wrangler during dev/deploy.
- Build panel app bundle: `cd eacc-panel && ./build.sh`
- Build panel without bundling: `cd eacc-panel && swift build`

## Lint / Static Checks
- There is no dedicated lint script in this repository.
- There is no ESLint, Prettier, Biome, SwiftLint, or SwiftFormat config checked in.
- For TypeScript changes, use package builds as the primary type check because `tsc` runs during package builds.
- Best screen sanity check: `cd eacc-screen && pnpm build`
- Targeted screen sanity check: `cd eacc-screen && pnpm -F @eacc/client build` or `pnpm -F eacc-screen build`
- Best panel sanity check: `cd eacc-panel && swift build`

## Test Commands
- Run all JS/TS tests: `cd eacc-screen && pnpm test`
- Run CLI package tests: `cd eacc-screen && pnpm -F eacc-screen test`
- Client package tests: `cd eacc-screen && pnpm -F @eacc/client test`
- Current checked-in test file: `eacc-screen/packages/cli/src/collectors/claude-code.test.ts`
- No Swift test target exists today under `eacc-panel/Tests`.

## Single Test Commands
- Run one test file: `cd eacc-screen && pnpm -F eacc-screen test -- src/collectors/claude-code.test.ts`
- Run one named Vitest case: `cd eacc-screen && pnpm -F eacc-screen test -- src/collectors/claude-code.test.ts -t "marks source as connected"`
- Alternative form using Vitest directly: `cd eacc-screen/packages/cli && pnpm exec vitest run src/collectors/claude-code.test.ts -t "computes todayTokens from dailyModelTokens matching today"`
- If more tests are added to the client package, the equivalent pattern is `cd eacc-screen && pnpm -F @eacc/client test -- <path> -t "<name>"`.

## Clean Commands
- Clean all screen packages: `cd eacc-screen && pnpm clean`
- Clean individual screen packages: `cd eacc-screen && pnpm -F @eacc/client clean` or `pnpm -F eacc-screen clean`

## TypeScript Style
- The workspace uses TypeScript `strict` mode; preserve strict typing.
- Prefer explicit domain types and shared interfaces from `@eacc/shared` over ad hoc object types.
- Use `import type` for type-only imports.
- Prefer named exports for components, hooks, utilities, and shared helpers.
- Use ESM throughout; local imports usually include the `.js` extension in runtime TS files when needed by the build.
- Keep functions small and side effects localized.
- Prefer early returns over deep nesting.
- Favor `const` over `let`; mutate only when there is a real state transition.
- Use union types for message protocols and finite state.
- Keep storage/config keys centralized or obviously named constants.
- Do not introduce `any` unless absolutely unavoidable; if forced, narrow it immediately.

## TypeScript Imports And Formatting
- Follow the existing import grouping style: external packages first, then local modules.
- `node:` imports are used for Node built-ins in the CLI.
- Keep one import per module source unless a type-only split improves clarity.
- Semicolons and single quotes are the established TS style.
- Indentation is 2 spaces in TypeScript and TSX.
- Trailing commas are common in multiline objects, arrays, and call arguments; preserve them.
- Inline style objects and CSS string blocks are common in the client; match surrounding style rather than rewriting to a new pattern.

## TypeScript Naming
- Components: PascalCase, e.g. `AltarScene`, `FocusTimer`.
- Hooks: `useX`, e.g. `useWebSocket`, `useApiPolling`.
- Store hooks: `useStore` with selector lambdas kept short.
- Shared interfaces/types: PascalCase.
- Config constants and file paths: `UPPER_SNAKE_CASE` for true constants.
- Internal helper functions: camelCase.
- WebSocket message `type` strings are lowercase snake-like literals such as `token_update` and `theme_change`; preserve wire compatibility.

## TypeScript Error Handling
- Throw explicit `Error` objects for real API failures when the caller needs context.
- Silent `catch {}` blocks are used only where failure is intentionally non-fatal, such as config/theme watchers and keepalive parsing.
- When swallowing an error, keep the fallback behavior obvious and safe.
- For API collectors, convert HTTP status codes into human-readable messages.
- Avoid logging noisy recoverable errors in hot paths unless the code already logs there.

## React / Client Conventions
- The screen client is desktop-first; mobile should show the redirect-style fallback, not a full responsive rebuild.
- Zustand is the state container; extend the store surgically instead of adding parallel state systems.
- Theme values come from shared theme objects and CSS variables; do not scatter hardcoded colors.
- Preserve accessibility hooks already present: focus-visible styles, reduced-motion handling, and adequate touch target sizing.
- Keep the altar composition immersive; this product is an ambient experience, not a conventional dashboard.

## Screen Design Rules
- Read `eacc-screen/DESIGN.md` before making visual changes.
- Preserve the ritual/monument feel.
- Use `0px` border radius throughout the screen UI.
- Keep the opacity hierarchy: hero strongest, scripture mid, peripheral controls muted.
- Maintain the four themes: `cyber`, `matrix`, `amber`, `void`.
- Prefer CSS particles and layered gradients; do not introduce WebGL-only critical UI.
- Keep mobile behavior as a simple blocker message for widths under `768px`.

## CLI / Server Conventions
- The CLI server uses Hono plus `ws` and aggregates collector output.
- Shared protocol types live in `@eacc/shared`; update both producer and consumer when changing message shapes.
- Config persists to `~/.eacc/config.json`; theme sync persists to `~/.eacc/theme.json`.
- When updating Claude pricing logic, keep the TypeScript and Swift implementations in sync.
- If you extend session tracking, document the on-disk source and keep session discovery behavior aligned across the screen CLI and panel app when both surfaces expose live sessions.

## Swift Style
- Follow existing Swift formatting: 4-space indentation and one top-level type per logical block.
- Favor `struct` for value models and `final class` for shared mutable controllers.
- Use `private` and `private(set)` to narrow access by default.
- Use `guard` for validation and early exits.
- `try?` is common for intentionally lossy file and JSON operations; keep it limited to non-critical paths.
- Use `NSLog` for existing diagnostic logging instead of inventing a second logging style.
- Keep SwiftUI view decomposition pragmatic; extract modifiers/views only when reused or meaningfully clearer.

## Swift Naming And State
- Types and enums use PascalCase.
- Properties and methods use camelCase.
- Enum cases use lowerCamelCase, including themed cases like `voidTheme`.
- Async UI actions usually run inside `Task { ... }` from views.
- Preserve theme-driven colors through `vm.themeColors.*` or related semantic theme objects; avoid ad hoc hardcoded UI colors except existing semantic accents.

## Cross-Project Consistency
- Wire protocol types must stay aligned between `eacc-screen/packages/shared/src/types.ts` and `eacc-panel/Sources/EACCMonitor/EACCTypes.swift`.
- Theme changes must respect both web and panel theme systems.
- Recipe/config persistence paths under `~/.eacc/` are part of the contract; do not rename casually.
- Session-related concepts and labels should stay consistent across TypeScript and Swift, especially when adding support for new tools such as OpenCode.

## Practical Agent Advice
- Before editing, identify whether the change belongs to `eacc-screen`, `eacc-panel`, or both.
- For UI changes in the screen app, check `DESIGN.md` first.
- For protocol or pricing changes, search both TypeScript and Swift implementations.
- For session-tracking changes, inspect `eacc-screen/packages/cli/src/collectors/claude-sessions.ts` and `eacc-panel/Sources/EACCMonitor/SessionMonitor.swift` first; OpenCode support should be added intentionally rather than only in one surface.
- Prefer the smallest viable patch.
- If no lint command exists, report that explicitly instead of inventing one.
