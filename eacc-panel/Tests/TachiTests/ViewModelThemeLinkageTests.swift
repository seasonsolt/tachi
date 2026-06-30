import XCTest
@testable import Tachi

@MainActor
final class ViewModelThemeLinkageTests: XCTestCase {
    private let personaKey = "companionPersonaMode"
    private let themeKey = "ritualTheme"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: personaKey)
        UserDefaults.standard.removeObject(forKey: themeKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: personaKey)
        UserDefaults.standard.removeObject(forKey: themeKey)
        super.tearDown()
    }

    func testCompanionSelectionSyncsTheme() {
        let vm = ViewModel()

        vm.setCompanionPersonaMode(.matrixAgent)

        XCTAssertEqual(vm.companionPersonaMode, .matrixAgent)
        XCTAssertEqual(vm.selectedTheme, .matrix)
        XCTAssertEqual(UserDefaults.standard.string(forKey: personaKey), "matrixAgent")
        XCTAssertEqual(UserDefaults.standard.string(forKey: themeKey), "matrix")
    }

    func testExternalThemeChangeKeepsCompanionLinked() {
        let vm = ViewModel()
        vm.setCompanionPersonaMode(.cyberSignal)

        vm.handleExternalThemeChange("void")

        XCTAssertEqual(vm.selectedTheme, .voidTheme)
        XCTAssertEqual(vm.companionPersonaMode, .voidMonolith)
        XCTAssertEqual(UserDefaults.standard.string(forKey: personaKey), "voidMonolith")
        XCTAssertEqual(UserDefaults.standard.string(forKey: themeKey), "void")
    }
}
