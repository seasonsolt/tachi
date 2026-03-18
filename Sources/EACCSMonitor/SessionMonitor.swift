import Foundation

// MARK: - Session Models

struct CodingSession: Identifiable {
    let id: String
    let tool: CodingTool
    let projectPath: String
    let slug: String
    let status: SessionStatus
    let lastActivity: Date

    var projectName: String {
        (projectPath as NSString).lastPathComponent
    }
}

enum CodingTool: String {
    case claudeCode = "Claude Code"
    case codex = "Codex"

    var icon: String {
        switch self {
        case .claudeCode: return "brain.head.profile"
        case .codex: return "cube.transparent"
        }
    }
}

enum SessionStatus {
    case working
    case waitingForInput
    case idle
    case completed

    var label: String {
        switch self {
        case .working: return "Working"
        case .waitingForInput: return "Waiting"
        case .idle: return "Idle"
        case .completed: return "Done"
        }
    }
}

// MARK: - Session Monitor

final class SessionMonitor {
    static let shared = SessionMonitor()

    private let home = NSHomeDirectory()
    private var claudeDir: String { home + "/.claude/projects" }
    private var codexIndex: String { home + "/.codex/session_index.jsonl" }
    private var codexSessions: String { home + "/.codex/sessions" }

    func scanSessions() -> [CodingSession] {
        var sessions: [CodingSession] = []
        sessions.append(contentsOf: scanClaudeSessions())
        sessions.append(contentsOf: scanCodexSessions())
        sessions.sort { $0.lastActivity > $1.lastActivity }
        return sessions
    }

    // MARK: - Claude Code

    private func scanClaudeSessions() -> [CodingSession] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(atPath: claudeDir) else { return [] }
        let cutoff = Date().addingTimeInterval(-3600)
        var sessions: [CodingSession] = []

        for dir in dirs {
            let projectDir = claudeDir + "/" + dir
            guard let files = try? fm.contentsOfDirectory(atPath: projectDir) else { continue }

            for file in files where file.hasSuffix(".jsonl") {
                let filePath = projectDir + "/" + file
                guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                    let modified = attrs[.modificationDate] as? Date,
                    modified > cutoff
                else { continue }

                let sessionId = String(file.dropLast(6))
                let lastEntry = readLastJsonlEntry(path: filePath)
                let cwd = lastEntry?["cwd"] as? String ?? decodeDirName(dir)
                let slug = lastEntry?["slug"] as? String ?? ""
                let lastType = lastEntry?["type"] as? String ?? ""
                let status = statusFromTimestamp(modified: modified, lastType: lastType)

                sessions.append(
                    CodingSession(
                        id: sessionId,
                        tool: .claudeCode,
                        projectPath: cwd,
                        slug: slug,
                        status: status,
                        lastActivity: modified
                    ))
            }
        }

        // Keep only the most recent session per project
        var best: [String: CodingSession] = [:]
        for s in sessions {
            if let existing = best[s.projectPath] {
                if s.lastActivity > existing.lastActivity { best[s.projectPath] = s }
            } else {
                best[s.projectPath] = s
            }
        }
        return Array(best.values)
    }

    private func statusFromTimestamp(modified: Date, lastType: String) -> SessionStatus {
        let age = Date().timeIntervalSince(modified)
        if age < 15 {
            // File changed in last 15s — actively writing
            switch lastType {
            case "assistant", "progress":
                return .working
            case "user":
                return .waitingForInput
            default:
                return .working
            }
        }
        if age < 300 {
            // Changed in last 5 min — likely waiting for input or paused
            switch lastType {
            case "assistant", "progress":
                return .waitingForInput
            case "user":
                return .waitingForInput
            default:
                return .idle
            }
        }
        return .completed
    }

    // MARK: - Codex

    private func scanCodexSessions() -> [CodingSession] {
        let fm = FileManager.default
        guard let data = fm.contents(atPath: codexIndex),
            let content = String(data: data, encoding: .utf8)
        else { return [] }

        let cutoff = Date().addingTimeInterval(-3600)
        let lines = content.split(separator: "\n")
        var sessions: [CodingSession] = []

        for line in lines.suffix(10).reversed() {
            guard let ld = line.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: ld) as? [String: Any],
                let sessionId = json["id"] as? String,
                let threadName = json["thread_name"] as? String,
                let updatedStr = json["updated_at"] as? String,
                let updated = parseISO(updatedStr),
                updated > cutoff
            else { continue }

            let status = codexSessionStatus(sessionId: sessionId, updated: updated)
            sessions.append(
                CodingSession(
                    id: sessionId,
                    tool: .codex,
                    projectPath: threadName,
                    slug: "",
                    status: status,
                    lastActivity: updated
                ))
        }
        return sessions
    }

    private func codexSessionStatus(sessionId: String, updated: Date) -> SessionStatus {
        // Try to find and read the actual session file
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd"
        let dayPath = codexSessions + "/" + df.string(from: updated)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: dayPath),
            let match = files.first(where: { $0.contains(sessionId) })
        else {
            let age = Date().timeIntervalSince(updated)
            return age < 300 ? .idle : .completed
        }
        let filePath = dayPath + "/" + match
        guard let entry = readLastJsonlEntry(path: filePath),
            let payload = entry["payload"] as? [String: Any],
            let type = payload["type"] as? String
        else {
            let age = Date().timeIntervalSince(updated)
            return age < 300 ? .idle : .completed
        }
        switch type {
        case "task_started", "agent_message": return .working
        case "task_complete": return .completed
        case "user_message": return .waitingForInput
        default: return .idle
        }
    }

    // MARK: - Helpers

    private func readLastJsonlEntry(path: String) -> [String: Any]? {
        guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
        defer { fh.closeFile() }
        let fileSize = fh.seekToEndOfFile()
        guard fileSize > 0 else { return nil }
        let readSize = min(fileSize, 8192)
        fh.seek(toFileOffset: fileSize - readSize)
        let data = fh.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        for line in str.split(separator: "\n").reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                let d = trimmed.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
            else { continue }
            return json
        }
        return nil
    }

    private func decodeDirName(_ encoded: String) -> String {
        var path = encoded
        if path.hasPrefix("-") { path = String(path.dropFirst()) }
        return "/" + path.replacingOccurrences(of: "-", with: "/")
    }

    private func parseISO(_ str: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: str) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: str)
    }
}
