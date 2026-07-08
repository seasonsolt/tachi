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

    func testPetDragUsesSwiftUIGestureCoordinates() {
        let startFrame = CGRect(x: 240, y: 260, width: 168, height: 172)

        let dragged = FloatingPetWindowPlacement.draggedFrame(
            startFrame: startFrame,
            translation: CGSize(width: 42, height: 18)
        )

        XCTAssertEqual(dragged.origin.x, 282)
        XCTAssertEqual(dragged.origin.y, 242)
        XCTAssertEqual(dragged.size.width, startFrame.size.width)
        XCTAssertEqual(dragged.size.height, startFrame.size.height)
    }
}
