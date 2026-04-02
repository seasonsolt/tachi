import XCTest
@testable import EACCMonitor

final class IslandPresentationTests: XCTestCase {
    func testTriggersExpansionWhenDominantSessionChanges() {
        let first = IslandSnapshot(
            dominantSessionID: "a",
            signal: .reasoning,
            pulse: .warm,
            hasActiveSession: true
        )
        let second = IslandSnapshot(
            dominantSessionID: "b",
            signal: .reasoning,
            pulse: .warm,
            hasActiveSession: true
        )

        XCTAssertTrue(IslandPresentation.shouldAutoExpand(from: first, to: second))
    }

    func testTriggersExpansionWhenSignalChanges() {
        let first = IslandSnapshot(
            dominantSessionID: "a",
            signal: .reasoning,
            pulse: .warm,
            hasActiveSession: true
        )
        let second = IslandSnapshot(
            dominantSessionID: "a",
            signal: .tooling,
            pulse: .warm,
            hasActiveSession: true
        )

        XCTAssertTrue(IslandPresentation.shouldAutoExpand(from: first, to: second))
    }

    func testReturnsIdleLineWhenNoActiveSessionExists() {
        let mode = IslandPresentation.resolveVisibleMode(
            hasActiveSession: false,
            isDetailPresented: false,
            isTransientlyExpanded: false
        )

        XCTAssertEqual(mode, .idleLine)
    }

    func testKeepsExpandedModeForTransientCompletionPulse() {
        let mode = IslandPresentation.resolveVisibleMode(
            hasActiveSession: false,
            isDetailPresented: false,
            isTransientlyExpanded: true
        )

        XCTAssertEqual(mode, .eventExpanded)
    }

    func testViewModelBuildsIslandSnapshotFromDominantSession() {
        let vm = ViewModel()
        vm.sessions = [
            CodingSession(
                id: "session-one",
                tool: .codex,
                projectPath: "/tmp/session-one",
                slug: "session-one",
                taskTitle: "Fix dynamic island state machine",
                taskSummary: "Fix dynamic island state machine",
                status: .working,
                lastActivity: Date(timeIntervalSinceReferenceDate: 10),
                signal: .tooling,
                pulse: .hot
            )
        ]

        let snapshot = vm.islandSnapshot

        XCTAssertEqual(snapshot.dominantSessionID, "session-one")
        XCTAssertEqual(snapshot.signal, .tooling)
        XCTAssertEqual(snapshot.pulse, .hot)
        XCTAssertTrue(snapshot.hasActiveSession)
    }
}
