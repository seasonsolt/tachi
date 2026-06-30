import XCTest
@testable import Tachi

final class CyberSignalMotionTests: XCTestCase {
    func testRotationDegreesKeepMovingCounterclockwise() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        let atStart = CyberSignalMotion.rotationDegrees(
            at: start,
            startDate: start,
            hasMotion: true
        )
        let quarterTurn = CyberSignalMotion.rotationDegrees(
            at: start.addingTimeInterval(2.5),
            startDate: start,
            hasMotion: true
        )
        let halfTurn = CyberSignalMotion.rotationDegrees(
            at: start.addingTimeInterval(5),
            startDate: start,
            hasMotion: true
        )

        XCTAssertEqual(atStart, 0, accuracy: 0.001)
        XCTAssertEqual(quarterTurn, -90, accuracy: 0.001)
        XCTAssertEqual(halfTurn, -180, accuracy: 0.001)
        XCTAssertLessThan(quarterTurn, atStart)
        XCTAssertLessThan(halfTurn, quarterTurn)
    }

    func testRotationStopsWhenMotionDisabled() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let later = start.addingTimeInterval(7.5)

        let angle = CyberSignalMotion.rotationDegrees(
            at: later,
            startDate: start,
            hasMotion: false
        )

        XCTAssertEqual(angle, 0, accuracy: 0.001)
    }
}
