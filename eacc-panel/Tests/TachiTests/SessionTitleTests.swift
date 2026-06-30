import XCTest
@testable import Tachi

@MainActor
final class SessionTitleTests: XCTestCase {
    func testDisplayTitlePrefersCodexThreadNameOverAttachmentSummary() {
        let session = CodingSession(
            id: "codex-session",
            tool: .codex,
            projectPath: "/Users/test/e-acc",
            slug: "重构 mac App 性能",
            taskTitle: "重构 mac App 性能",
            taskSummary: "# Files mentioned by the user: ## codex-clipboard.png",
            status: .working,
            lastActivity: Date(timeIntervalSince1970: 1),
            signal: .booting,
            pulse: .hot
        )

        XCTAssertEqual(session.primaryTaskText, "重构 mac App 性能")
        XCTAssertEqual(session.displayTitle, "重构 mac App 性能")
    }

    func testCompanionTaskLineDoesNotUseAttachmentPrelude() {
        let vm = ViewModel()
        let session = CodingSession(
            id: "codex-session",
            tool: .codex,
            projectPath: "/Users/test/e-acc",
            slug: "",
            taskTitle: nil,
            taskSummary: "# Files mentioned by the user: ## codex-clipboard.png",
            status: .working,
            lastActivity: Date(timeIntervalSince1970: 1),
            signal: .booting,
            pulse: .hot
        )

        XCTAssertEqual(vm.companionTaskLine(for: session), "e-acc")
    }
}
