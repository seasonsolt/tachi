# EACC Panel Dynamic Island MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current bottom-right companion floating panel with a top-center dynamic-island MVP that shows a breathing idle line, auto-expands on session changes, and opens a tiny jump-back popover on click.

**Architecture:** Keep the existing `NSPanel` infrastructure, but swap the floating pet presentation for an island-specific presentation state machine. Put deterministic expand/collapse logic into a small testable model, then let the SwiftUI window layer render `idle`, `event-expanded`, and `detail` states from that model.

**Tech Stack:** SwiftUI, AppKit `NSPanel`, Swift Package Manager, XCTest

---

## File Structure

- Modify: `eacc-panel/Sources/EACCMonitor/FloatingPetWindow.swift`
  Purpose: replace the right-bottom pet presentation with the top-center island panel and wire click / auto-collapse behavior.
- Modify: `eacc-panel/Sources/EACCMonitor/ViewModel.swift`
  Purpose: expose dominant-session island copy and event transitions to the panel layer without changing session collection.
- Modify: `eacc-panel/Sources/EACCMonitor/EACCMonitorApp.swift`
  Purpose: keep the menu bar app as a weak fallback entry point while ensuring the island panel is the primary surface.
- Create: `eacc-panel/Sources/EACCMonitor/IslandPresentation.swift`
  Purpose: hold deterministic island-state rules for idle / expanded / detail modes and auto-expand triggers.
- Create: `eacc-panel/Tests/EACCMonitorTests/IslandPresentationTests.swift`
  Purpose: regression coverage for expansion triggers and state resolution.

### Task 1: Add Deterministic Island Presentation Rules

**Files:**
- Create: `eacc-panel/Sources/EACCMonitor/IslandPresentation.swift`
- Test: `eacc-panel/Tests/EACCMonitorTests/IslandPresentationTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import EACCMonitor

final class IslandPresentationTests: XCTestCase {
    func testTriggersExpansionWhenDominantSessionChanges() {
        let first = IslandSnapshot(dominantSessionID: "a", signal: .reasoning, pulse: .warm, hasActiveSession: true)
        let second = IslandSnapshot(dominantSessionID: "b", signal: .reasoning, pulse: .warm, hasActiveSession: true)

        XCTAssertTrue(IslandPresentation.shouldAutoExpand(from: first, to: second))
    }

    func testTriggersExpansionWhenSignalChanges() {
        let first = IslandSnapshot(dominantSessionID: "a", signal: .reasoning, pulse: .warm, hasActiveSession: true)
        let second = IslandSnapshot(dominantSessionID: "a", signal: .tooling, pulse: .warm, hasActiveSession: true)

        XCTAssertTrue(IslandPresentation.shouldAutoExpand(from: first, to: second))
    }

    func testReturnsIdleWhenNoActiveSessionExists() {
        let state = IslandPresentation.resolveVisibleMode(
            hasActiveSession: false,
            isDetailPresented: false,
            isTransientlyExpanded: false
        )

        XCTAssertEqual(state, .idleLine)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd eacc-panel && swift test`
Expected: FAIL because `IslandSnapshot`, `IslandPresentation`, and `IslandVisibleMode` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

struct IslandSnapshot: Equatable {
    let dominantSessionID: String?
    let signal: SessionSignal?
    let pulse: SessionPulse?
    let hasActiveSession: Bool
}

enum IslandVisibleMode: Equatable {
    case idleLine
    case eventExpanded
    case detailPopover
}

enum IslandPresentation {
    static func shouldAutoExpand(from old: IslandSnapshot?, to new: IslandSnapshot) -> Bool {
        guard new.hasActiveSession else { return false }
        guard let old else { return new.dominantSessionID != nil }
        if old.dominantSessionID != new.dominantSessionID { return true }
        if old.signal != new.signal { return true }
        if old.pulse != new.pulse { return true }
        return false
    }

    static func resolveVisibleMode(
        hasActiveSession: Bool,
        isDetailPresented: Bool,
        isTransientlyExpanded: Bool
    ) -> IslandVisibleMode {
        if isDetailPresented { return .detailPopover }
        if hasActiveSession && isTransientlyExpanded { return .eventExpanded }
        return .idleLine
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd eacc-panel && swift test`
Expected: PASS for the new island-presentation tests.

### Task 2: Replace Pet Window UI With Island Panel

**Files:**
- Modify: `eacc-panel/Sources/EACCMonitor/FloatingPetWindow.swift`
- Modify: `eacc-panel/Sources/EACCMonitor/ViewModel.swift`

- [ ] **Step 1: Write a focused failing test for view-model snapshot building**

```swift
func testIslandSnapshotUsesDominantActiveSession() {
    let vm = ViewModel()
    vm.sessions = [
        CodingSession(
            id: "one",
            tool: .codex,
            projectPath: "/tmp/one",
            slug: "one",
            taskTitle: "Task one",
            taskSummary: "Task one",
            status: .working,
            lastActivity: Date(timeIntervalSinceReferenceDate: 10),
            signal: .tooling,
            pulse: .hot
        )
    ]

    let snapshot = vm.islandSnapshot

    XCTAssertEqual(snapshot.dominantSessionID, "one")
    XCTAssertEqual(snapshot.signal, .tooling)
    XCTAssertEqual(snapshot.pulse, .hot)
    XCTAssertTrue(snapshot.hasActiveSession)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd eacc-panel && swift test`
Expected: FAIL because `ViewModel.islandSnapshot` does not exist.

- [ ] **Step 3: Add the view-model surface and new island view**

```swift
extension ViewModel {
    var islandSnapshot: IslandSnapshot {
        IslandSnapshot(
            dominantSessionID: dominantSession?.id,
            signal: dominantSession?.signal,
            pulse: dominantSession?.pulse,
            hasActiveSession: !activeSessions.isEmpty
        )
    }
}
```

```swift
// FloatingPetWindow.swift
// - replace DesktopPetView with a horizontal island view
// - position the NSPanel at visibleFrame.midX with a fixed top inset
// - render IslandVisibleMode.idleLine as a thin glowing line
// - render IslandVisibleMode.eventExpanded as a capsule with dominant task copy
// - render IslandVisibleMode.detailPopover as the same capsule plus one jump row
// - use a short Task-based timer to collapse eventExpanded back to idleLine
```

- [ ] **Step 4: Run tests and build after the panel swap**

Run: `cd eacc-panel && swift test`
Expected: PASS

Run: `cd eacc-panel && swift build`
Expected: PASS

### Task 3: Weaken Menu Bar Entry And Verify End-To-End Behavior

**Files:**
- Modify: `eacc-panel/Sources/EACCMonitor/EACCMonitorApp.swift`
- Modify: `eacc-panel/Sources/EACCMonitor/Views.swift`

- [ ] **Step 1: Reduce the menu bar label to a weak fallback entry**

```swift
// EACCMonitorApp.swift
// keep MenuBarExtra, but change its label to a short fallback status such as:
// - idle: "•"
// - active session: "◉"
// - loading: "⏳"
// detailed task copy stays in the island, not the menu bar
```

- [ ] **Step 2: Ensure the fallback detail surface still works**

```swift
// Views.swift
// keep ContentView and its existing sections reachable from MenuBarExtra
// do not delete agent, provider, or recipe sections during the island MVP
```

- [ ] **Step 3: Run final verification**

Run: `cd eacc-panel && swift test`
Expected: PASS

Run: `cd eacc-panel && swift build`
Expected: PASS

Run: `cd eacc-panel && ./build.sh`
Expected: PASS and refresh `EACCMonitor.app`

- [ ] **Step 4: Manually verify MVP**

Check:
- idle state shows a thin top-center breathing line
- session activity briefly expands the island
- clicking the island opens the tiny detail popover
- clicking the popover row jumps back to the tool
- menu bar icon remains as a weak fallback entry
