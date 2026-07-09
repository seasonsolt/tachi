import XCTest
@testable import Tachi

final class FloatingPetWindowPlacementTests: XCTestCase {
    func testInitialFrameUsesDefaultBottomRightPlacement() {
        let visibleFrame = CGRect(x: 0, y: 38, width: 1440, height: 862)
        let frame = FloatingPetWindowPlacement.initialFrame(
            size: CGSize(width: 168, height: 172),
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.origin.x, 1248)
        XCTAssertEqual(frame.origin.y, 110)
        XCTAssertEqual(frame.size.width, 168)
        XCTAssertEqual(frame.size.height, 172)
    }

    func testResizePreservesCurrentBottomTrailingAnchorAfterDrag() {
        let visibleFrame = CGRect(x: 0, y: 38, width: 1440, height: 862)
        let draggedFrame = CGRect(x: 240, y: 260, width: 168, height: 172)

        let resized = FloatingPetWindowPlacement.resizedFrame(
            currentFrame: draggedFrame,
            newSize: CGSize(width: 340, height: 410),
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(resized.origin.x, 68)
        XCTAssertEqual(resized.origin.y, 260)
        XCTAssertEqual(resized.size.width, 340)
        XCTAssertEqual(resized.size.height, 410)
    }

    func testResizePreservesCurrentAnchorNearScreenEdge() {
        let visibleFrame = CGRect(x: 0, y: 38, width: 1440, height: 862)
        let draggedFrame = CGRect(x: 20, y: 20, width: 168, height: 172)

        let resized = FloatingPetWindowPlacement.resizedFrame(
            currentFrame: draggedFrame,
            newSize: CGSize(width: 340, height: 410),
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(resized.origin.x, -152)
        XCTAssertEqual(resized.origin.y, 20)
    }

    func testResizeRoundTripKeepsDraggedFrameStableNearScreenEdge() {
        let visibleFrame = CGRect(x: 0, y: 38, width: 1440, height: 862)
        let draggedFrame = CGRect(x: 20, y: 20, width: 168, height: 172)

        let expanded = FloatingPetWindowPlacement.resizedFrame(
            currentFrame: draggedFrame,
            newSize: CGSize(width: 340, height: 410),
            visibleFrame: visibleFrame
        )
        let collapsedAgain = FloatingPetWindowPlacement.resizedFrame(
            currentFrame: expanded,
            newSize: draggedFrame.size,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(collapsedAgain.origin.x, draggedFrame.origin.x)
        XCTAssertEqual(collapsedAgain.origin.y, draggedFrame.origin.y)
    }

    func testPetDragFollowsAbsoluteCursorDelta() {
        // Window at origin (240,260); cursor moved +42 right, +18 up (screen
        // coords are y-up, matching setFrameOrigin), so the window follows the
        // cursor 1:1 — the same delta, no shrink-back.
        let dragged = FloatingPetWindowPlacement.draggedFrame(
            anchorOrigin: CGPoint(x: 240, y: 260),
            anchorMouse: CGPoint(x: 900, y: 500),
            currentMouse: CGPoint(x: 942, y: 518),
            size: CGSize(width: 168, height: 172)
        )

        XCTAssertEqual(dragged.origin.x, 282)
        XCTAssertEqual(dragged.origin.y, 278)
        XCTAssertEqual(dragged.size.width, 168)
        XCTAssertEqual(dragged.size.height, 172)
    }

    func testPetDragIsStableWhenCursorHoldsStillAsWindowMoves() {
        // Regression for the oscillation: re-evaluating the drag with the SAME
        // cursor position must return the SAME origin, no matter where the
        // window currently is. (The old translation-based math moved the window
        // a little every frame even when the cursor was stationary.)
        let anchorOrigin = CGPoint(x: 240, y: 260)
        let anchorMouse = CGPoint(x: 900, y: 500)
        let heldMouse = CGPoint(x: 960, y: 500)

        let first = FloatingPetWindowPlacement.draggedFrame(
            anchorOrigin: anchorOrigin, anchorMouse: anchorMouse,
            currentMouse: heldMouse, size: CGSize(width: 168, height: 172)
        )
        let second = FloatingPetWindowPlacement.draggedFrame(
            anchorOrigin: anchorOrigin, anchorMouse: anchorMouse,
            currentMouse: heldMouse, size: CGSize(width: 168, height: 172)
        )

        XCTAssertEqual(first.origin.x, 300)
        XCTAssertEqual(second.origin.x, first.origin.x)
        XCTAssertEqual(second.origin.y, first.origin.y)
    }
}
