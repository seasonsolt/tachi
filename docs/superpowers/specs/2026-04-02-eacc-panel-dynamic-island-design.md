# EACC Panel Dynamic Island MVP Design

**Date:** 2026-04-02
**Status:** Approved in conversation, awaiting final file review before implementation planning

## Goal

Replace the current bottom-right companion-style floating panel in `eacc-panel` with a top-center, dynamic-island-style surface that makes active coding sessions feel ambient and immediate. The MVP should prioritize monitoring and jump-back behavior, not in-island approvals or a miniature dashboard.

## Product Shape

The island becomes the primary native surface for `eacc-panel`. The menu bar app remains, but only as a weak fallback for app presence, settings, and recovery actions. The island is visually dominant; the menu bar is no longer the main interaction model.

## Confirmed MVP Decisions

- Use a top-center floating island on the main screen.
- Keep a weak menu bar presence as the backup entry point.
- Idle state is a thin “breathing line”, not a full capsule.
- The island tracks a single dominant session, not multiple side-by-side sessions.
- Clicking the island opens a very small detail popover first; the user then clicks the session row to jump back to the tool.
- The island auto-expands only when session state changes, then settles back to the breathing-line state.
- The default content priority is the current dominant session, not token/cost analytics.

## States

### 1. Idle Line

When there are no active sessions, or no recent session events worth surfacing, the panel renders as a narrow glowing line centered near the macOS notch area. It should suggest presence without becoming a permanent status bar.

### 2. Event Expansion

When a dominant session meaningfully changes state, the line briefly expands into a compact island capsule. The capsule shows the current task headline, tool identity, and heat/signal status. This is informational only; it does not directly jump.

### 3. Detail Popover

When the user clicks the capsule, a very small popover appears beneath it. This popover contains:

- Dominant session task line
- Project name
- Tool name
- Session signal/heat label
- One clear jump target row
- Optional `+N more active` secondary hint, without in-MVP multi-session switching

Clicking the row launches the existing session target behavior through `SessionLauncher`.

## Session Selection

The island should use the existing dominant-session ordering already present in the `ViewModel` exactly as-is for the MVP. `dominantSession`, `companionTaskLine`, and related summary helpers remain the source of truth for session copy. The MVP does not introduce a new ranking model.

## Auto-Expand Rules

The island should auto-expand when one of these happens:

- A new dominant session appears
- The dominant session moves into a more active state, especially `working`
- The dominant session’s `signal` enum changes
- The dominant session’s `pulse` enum changes
- A session completes, producing one short completion pulse before returning to idle

The island should not stay permanently expanded during long-running work. After the transient event window ends, it should collapse back to the breathing-line state.

## Architecture

The implementation should reuse the existing `NSPanel` foundation in `FloatingPetWindow.swift` instead of replacing the window system. The main change is presentation architecture: the current right-aligned companion panel becomes a main-screen, top-centered island panel with a small state machine for idle, event-expanded, and detail-popover modes.

The `ViewModel` remains responsible for session-derived content and should gain a minimal presentation layer for “should auto-expand now” decisions. This should stay separate from collector logic and session discovery. `SessionLauncher` continues to handle jump-back behavior.

## Visual Direction

The MVP should feel closer to a native dynamic island than to a dashboard or pet widget:

- Pure capsule silhouette with strong horizontal bias
- Minimal copy and strong truncation discipline
- No full card stack in the default state
- Motion should be subtle and event-driven
- The breathing line should be visible but restrained

The chosen direction is structurally closest to the “Pure Island” option explored during brainstorming, but with a second-step detail popover rather than direct single-click jumping.

## Out of Scope

These are explicitly excluded from the MVP:

- In-island approvals or reply input
- Multi-session carousel or full session switcher
- Multi-monitor following behavior
- A new analytics-focused island mode
- Rebuilding the full menu panel UI around the island
- Replacing the underlying session monitoring pipeline

## Testing Strategy

The MVP should add regression coverage for deterministic presentation-state rules. The first unit tests should target:

- Whether a given session-state transition should auto-expand
- Whether idle vs expanded vs detail states resolve correctly from view-model inputs
- Existing jump-back behavior should continue to work through manual verification

Verification should include:

- `swift test`
- `swift build`
- Manual restart of `EACCMonitor.app`
- Manual validation of idle line, automatic expansion, click-to-popover, and jump-back flow

## Files Likely To Change

- `eacc-panel/Sources/EACCMonitor/FloatingPetWindow.swift`
- `eacc-panel/Sources/EACCMonitor/ViewModel.swift`
- `eacc-panel/Sources/EACCMonitor/Views.swift`
- `eacc-panel/Sources/EACCMonitor/SessionLauncher.swift` only if jump ergonomics need a minimal change
- New Swift test files for island presentation logic

## Notes

This design intentionally biases toward a narrow MVP. If the island proves useful, future versions can add approvals, richer session switching, better multi-display placement, or a deeper integration with the menu bar fallback surface.
