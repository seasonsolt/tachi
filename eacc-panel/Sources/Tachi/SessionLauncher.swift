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

        // Codex/OpenCode/claude CLIs don't register pids anywhere, but we can
        // find the live process whose cwd matches the session's project.
        if let pid = liveCLIPid(for: session), let app = owningApplication(forProcess: pid) {
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

    private static func cliCommandHint(for tool: CodingTool) -> String? {
        switch tool {
        case .codex: return "codex"
        case .openCode: return "opencode"
        case .claudeCode: return "claude"
        case .claudeDesign, .pencil: return nil
        }
    }

    private static func liveCLIPid(for session: CodingSession) -> pid_t? {
        guard let hint = cliCommandHint(for: session.tool) else { return nil }

        let processes = listProcesses(commandHint: hint)
        guard !processes.isEmpty else { return nil }

        let target = normalizePath(session.projectPath)
        if let match = processes.first(where: { normalizePath($0.cwd) == target }) {
            return match.pid
        }
        // A single live instance is unambiguous even if cwd drifted.
        return processes.count == 1 ? processes[0].pid : nil
    }

    private static func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }

    private static func listProcesses(commandHint: String) -> [(pid: pid_t, cwd: String)] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-a", "-c", commandHint, "-d", "cwd", "-Fn"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return parseLsofPidCwdOutput(output)
    }

    // lsof -Fn emits "p<pid>" then "n<cwd>" line pairs per process.
    static func parseLsofPidCwdOutput(_ output: String) -> [(pid: pid_t, cwd: String)] {
        var results: [(pid: pid_t, cwd: String)] = []
        var currentPid: pid_t?
        for line in output.split(separator: "\n") {
            if line.hasPrefix("p") {
                currentPid = pid_t(line.dropFirst())
            } else if line.hasPrefix("n"), let pid = currentPid {
                let cwd = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !cwd.isEmpty {
                    results.append((pid: pid, cwd: cwd))
                }
                currentPid = nil
            }
        }
        return results
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
