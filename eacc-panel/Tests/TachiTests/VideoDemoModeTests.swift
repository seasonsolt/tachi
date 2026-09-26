import XCTest
@testable import Tachi

final class VideoDemoModeTests: XCTestCase {
    func testVideoDemoArgumentObeysBuildConfiguration() {
        let mode = VideoDemoMode.parse(arguments: ["Tachi", "--video-demo", "overview"])

#if DEBUG
        XCTAssertEqual(mode, .overview)
#else
        XCTAssertNil(mode)
#endif
    }

    func testMissingOrInvalidVideoDemoArgumentStaysInNormalMode() {
        XCTAssertNil(VideoDemoMode.parse(arguments: ["Tachi"]))
        XCTAssertNil(VideoDemoMode.parse(arguments: ["Tachi", "--video-demo"]))
        XCTAssertNil(VideoDemoMode.parse(arguments: ["Tachi", "--video-demo", "invalid"]))
    }

    func testOverviewProvidesOneSessionInEachStoryStatus() {
        let sessions = VideoDemoMode.overview.sessions(
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(sessions.map(\.tool), [.claudeCode, .codex, .openCode])
        XCTAssertEqual(sessions.map(\.status), [.working, .waitingForInput, .completed])
        XCTAssertEqual(
            sessions.map(\.displayTitle),
            ["Build launch sequence", "Approve release copy", "Export product trailer"]
        )
    }

    @MainActor
    func testApplyingThreeSessionDemoLocksSignalPersonaAndSessionCount() {
        let vm = ViewModel()

        vm.applyVideoDemo(.three, now: Date(timeIntervalSince1970: 1_000))

        XCTAssertEqual(vm.videoDemoMode, .three)
        XCTAssertEqual(vm.workingSessionCount, 3)
        XCTAssertEqual(vm.companionPersonaMode, .cyberSignal)
        XCTAssertEqual(vm.selectedTheme, .cyber)
    }

    @MainActor
    func testDemoPersonaSelectionDoesNotPersistProductPreferences() {
        let defaults = UserDefaults.standard
        let personaKey = "companionPersonaMode"
        let themeKey = "ritualTheme"
        let previousPersona = defaults.object(forKey: personaKey)
        let previousTheme = defaults.object(forKey: themeKey)
        defer {
            if let previousPersona {
                defaults.set(previousPersona, forKey: personaKey)
            } else {
                defaults.removeObject(forKey: personaKey)
            }
            if let previousTheme {
                defaults.set(previousTheme, forKey: themeKey)
            } else {
                defaults.removeObject(forKey: themeKey)
            }
        }

        defaults.removeObject(forKey: personaKey)
        defaults.removeObject(forKey: themeKey)

        let vm = ViewModel()
        vm.applyVideoDemo(.overview, now: Date(timeIntervalSince1970: 1_000))
        vm.setCompanionPersonaMode(.voidMonolith)

        XCTAssertNil(defaults.object(forKey: personaKey))
        XCTAssertNil(defaults.object(forKey: themeKey))
        XCTAssertEqual(vm.selectedTheme, .voidTheme)
    }

    @MainActor
    func testDemoRefreshIntervalSelectionDoesNotPersistProductPreferences() {
        let defaults = UserDefaults.standard
        let refreshIntervalKey = "refreshInterval"
        let previousRefreshInterval = defaults.object(forKey: refreshIntervalKey)
        defer {
            if let previousRefreshInterval {
                defaults.set(previousRefreshInterval, forKey: refreshIntervalKey)
            } else {
                defaults.removeObject(forKey: refreshIntervalKey)
            }
        }

        defaults.removeObject(forKey: refreshIntervalKey)

        let vm = ViewModel()
        vm.applyVideoDemo(.overview, now: Date(timeIntervalSince1970: 1_000))
        vm.refreshInterval = 10

        XCTAssertNil(defaults.object(forKey: refreshIntervalKey))
    }
}
