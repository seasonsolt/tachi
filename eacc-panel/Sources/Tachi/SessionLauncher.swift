import AppKit
import Foundation

@MainActor
enum SessionLauncher {
    static func open(_ session: CodingSession) {
        // The session's registered pid tells us which app actually hosts the
        // conversation (Claude desktop, iTerm, Terminal, ...). Activating that
        // beats guessing from a hardcoded candidate list.
        if let pid = session.ownerPid, let app = owningApplication(forProcess: pid) {
            app.activate()
            return
        }

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

    // Walk the process ancestry until we hit something the workspace knows as
    // an activatable application.
    static func owningApplication(forProcess pid: Int32) -> NSRunningApplication? {
        var current = pid_t(pid)
        var hops = 0
        while current > 1, hops < 20 {
            if let app = NSRunningApplication(processIdentifier: current),
               app.activationPolicy != .prohibited,
               app.bundleURL != nil
            {
                return app
            }
            guard let parent = parentPid(of: current), parent != current else { return nil }
            current = parent
            hops += 1
        }
        return nil
    }

    private static func parentPid(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard result == size else { return nil }
        return pid_t(info.pbi_ppid)
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
        case .claudeDesign:
            return [
                "/Applications/Claude.app"
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
