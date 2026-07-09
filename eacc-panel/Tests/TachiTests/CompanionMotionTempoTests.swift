import XCTest
@testable import Tachi

final class CompanionMotionTempoTests: XCTestCase {
    private func workingSession(_ id: String) -> CodingSession {
        CodingSession(
            id: id,
            tool: .claudeCode,
            projectPath: "/tmp/\(id)",
            slug: id,
            taskTitle: id,
            taskSummary: nil,
            status: .working,
            lastActivity: Date(timeIntervalSince1970: 200),
            signal: .booting,
            pulse: .hot
        )
    }

    @MainActor
    func testTempoIsCalmBaselineWithNoWorkingSessions() {
        let vm = ViewModel()
        vm.sessions = []
        XCTAssertEqual(vm.companionMotionTempo, 1.0, accuracy: 0.0001)
    }

    @MainActor
    func testTempoRisesWithConcurrentWorkingSessions() {
        let vm = ViewModel()
        vm.sessions = [workingSession("a"), workingSession("b")]
        // 1 + 0.55 * 2
        XCTAssertEqual(vm.companionMotionTempo, 2.1, accuracy: 0.0001)
    }

    @MainActor
    func testTempoIsCappedForBusyMachines() {
        let vm = ViewModel()
        vm.sessions = (0..<12).map { workingSession("s\($0)") }
        XCTAssertEqual(vm.companionMotionTempo, 4.0, accuracy: 0.0001)
    }

    func testRingSpeedScalesWithTempoAndStopsWithoutMotion() {
        let base = CyberSignalMotion.degreesPerSecond(hasMotion: true, tempo: 1.0)
        let fast = CyberSignalMotion.degreesPerSecond(hasMotion: true, tempo: 2.0)
        let stopped = CyberSignalMotion.degreesPerSecond(hasMotion: false, tempo: 3.0)

        // 10s per revolution at tempo 1 → -36°/s, counter-clockwise.
        XCTAssertEqual(base, -36, accuracy: 0.001)
        // Double the tempo → double the angular speed.
        XCTAssertEqual(fast, -72, accuracy: 0.001)
        XCTAssertLessThan(fast, base)
        XCTAssertEqual(stopped, 0, accuracy: 0.001)
    }
}
