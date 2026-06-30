import AppKit
import Foundation

@MainActor
enum SessionLauncher {
    static func open(_ session: CodingSession) {
        if let appURL = preferredApplicationURL(for: session.tool) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in }
            return
        }

        let projectURL = URL(fileURLWithPath: session.projectPath)
        if FileManager.default.fileExists(atPath: projectURL.path) {
            NSWorkspace.shared.open(projectURL)
        }
    }

    private static func preferredApplicationURL(for tool: CodingTool) -> URL? {
        candidateApplicationPaths(for: tool)
            .map(URL.init(fileURLWithPath:))
            .first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    private static func candidateApplicationPaths(for tool: CodingTool) -> [String] {
        switch tool {
        case .codex:
            return [
                "/Applications/Codex.app",
                "/Applications/ChatGPT.app"
            ]
        case .openCode:
            return [
                "/Applications/OpenCode.app",
                "/Applications/OpenCode Desktop.app"
            ]
        case .pencil:
            return [
                "/Applications/Pencil.app"
            ]
        case .claudeCode:
            return [
                "/Applications/iTerm.app",
                "/System/Applications/Utilities/Terminal.app",
                "/Applications/Claude.app"
            ]
        }
    }
}
