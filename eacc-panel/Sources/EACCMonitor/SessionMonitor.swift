import Foundation

// MARK: - Session Models

struct CodingSession: Identifiable, Sendable {
    let id: String
    let tool: CodingTool
    let projectPath: String
    let slug: String
    let status: SessionStatus
    let lastActivity: Date
    let signal: SessionSignal
    let pulse: SessionPulse

    var projectName: String {
        let name = (projectPath as NSString).lastPathComponent
        return name.isEmpty ? projectPath : name
    }
}

enum CodingTool: String, Sendable {
    case claudeCode = "Claude Code"
    case codex = "Codex"

    var icon: String {
        switch self {
        case .claudeCode: return "brain.head.profile"
        case .codex: return "cube.transparent"
        }
    }
}

enum SessionStatus: Sendable {
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

enum SessionSignal: Sendable {
    case booting
    case reasoning
    case tooling
    case responding
    case awaitingUser
    case quiet
    case completed

    var label: String {
        switch self {
        case .booting: return "Fresh prompt scent"
        case .reasoning: return "Thinking"
        case .tooling: return "Tool clatter"
        case .responding: return "Reply streaming"
        case .awaitingUser: return "Watching for you"
        case .quiet: return "Thread warmth"
        case .completed: return "Curled up"
        }
    }
}

enum SessionPulse: Int, Sendable {
    case sleeping = 0
    case drowsy = 1
    case listening = 2
    case warm = 3
    case hot = 4
}

// MARK: - Session Monitor

final class SessionMonitor {
    static let shared = SessionMonitor()

    private struct SessionTrace {
        let status: SessionStatus
        let signal: SessionSignal
        let pulse: SessionPulse
        let lastActivity: Date
    }

    private let home = NSHomeDirectory()
    private var claudeDir: String { home + "/.claude/projects" }
    private var codexIndex: String { home + "/.codex/session_index.jsonl" }
    private var codexSessions: String { home + "/.codex/sessions" }

    func scanSessions() -> [CodingSession] {
        var sessions: [CodingSession] = []
        sessions.append(contentsOf: scanClaudeSessions())
        sessions.append(contentsOf: scanCodexSessions())
        sessions.sort { lhs, rhs in
            if lhs.pulse != rhs.pulse { return lhs.pulse.rawValue > rhs.pulse.rawValue }
            return lhs.lastActivity > rhs.lastActivity
        }
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

                let recentEntries = readRecentJsonlEntries(path: filePath, limit: 12)
                let lastEntry = recentEntries.first
                let sessionId = String(file.dropLast(6))
                let cwd = lastEntry?["cwd"] as? String ?? decodeDirName(dir)
                let slug = lastEntry?["slug"] as? String ?? ""
                let trace = claudeTrace(recentEntries: recentEntries, fallbackDate: modified)

                sessions.append(
                    CodingSession(
                        id: sessionId,
                        tool: .claudeCode,
                        projectPath: cwd,
                        slug: slug,
                        status: trace.status,
                        lastActivity: trace.lastActivity,
                        signal: trace.signal,
                        pulse: trace.pulse
                    ))
            }
        }

        var best: [String: CodingSession] = [:]
        for session in sessions {
            if let existing = best[session.projectPath] {
                if session.lastActivity > existing.lastActivity { best[session.projectPath] = session }
            } else {
                best[session.projectPath] = session
            }
        }
        return Array(best.values)
    }

    private func claudeTrace(recentEntries: [[String: Any]], fallbackDate: Date) -> SessionTrace {
        for entry in recentEntries {
            let timestamp = parseISO(entry["timestamp"] as? String ?? "") ?? fallbackDate
            switch entry["type"] as? String ?? "" {
            case "assistant":
                return trace(for: replySignal(at: timestamp), timestamp: timestamp)
            case "user":
                return trace(for: .booting, timestamp: timestamp)
            case "progress":
                if let data = entry["data"] as? [String: Any],
                    data["type"] as? String == "hook_progress"
                {
                    return trace(for: .tooling, timestamp: timestamp)
                }
                return trace(for: .reasoning, timestamp: timestamp)
            default:
                continue
            }
        }
        return trace(for: .quiet, timestamp: fallbackDate)
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

        for line in lines.suffix(12).reversed() {
            guard let ld = line.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: ld) as? [String: Any],
                let sessionId = json["id"] as? String,
                let threadName = json["thread_name"] as? String,
                let updatedStr = json["updated_at"] as? String,
                let updated = parseISO(updatedStr),
                updated > cutoff
            else { continue }

            let filePath = locateCodexSessionFile(sessionId: sessionId, updated: updated)
            let recentEntries = filePath.map { readRecentJsonlEntries(path: $0, limit: 16) } ?? []
            let trace = codexTrace(recentEntries: recentEntries, fallbackDate: updated)
            let cwd = codexWorkspace(from: recentEntries)
            let projectPath = cwd ?? threadName
            let slug = cwd == nil || threadName == projectPath ? "" : threadName

            sessions.append(
                CodingSession(
                    id: sessionId,
                    tool: .codex,
                    projectPath: projectPath,
                    slug: slug,
                    status: trace.status,
                    lastActivity: trace.lastActivity,
                    signal: trace.signal,
                    pulse: trace.pulse
                ))
        }
        return sessions
    }

    private func locateCodexSessionFile(sessionId: String, updated: Date) -> String? {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd"
        let dayPath = codexSessions + "/" + df.string(from: updated)
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dayPath),
            let match = files.first(where: { $0.contains(sessionId) })
        else { return nil }
        return dayPath + "/" + match
    }

    private func codexWorkspace(from recentEntries: [[String: Any]]) -> String? {
        for entry in recentEntries {
            guard entry["type"] as? String == "turn_context",
                let payload = entry["payload"] as? [String: Any],
                let cwd = payload["cwd"] as? String,
                !cwd.isEmpty
            else { continue }
            return cwd
        }
        return nil
    }

    private func codexTrace(recentEntries: [[String: Any]], fallbackDate: Date) -> SessionTrace {
        for entry in recentEntries {
            let timestamp = parseISO(entry["timestamp"] as? String ?? "") ?? fallbackDate
            let topType = entry["type"] as? String ?? ""
            let payload = entry["payload"] as? [String: Any]

            switch topType {
            case "event_msg":
                switch payload?["type"] as? String ?? "" {
                case "agent_message":
                    return trace(for: replySignal(at: timestamp), timestamp: timestamp)
                case "agent_reasoning":
                    return trace(for: .reasoning, timestamp: timestamp)
                case "user_message":
                    return trace(for: .booting, timestamp: timestamp)
                case "task_complete":
                    return trace(for: .completed, timestamp: timestamp)
                default:
                    continue
                }
            case "response_item":
                switch payload?["type"] as? String ?? "" {
                case "function_call", "web_search_call":
                    return trace(for: .tooling, timestamp: timestamp)
                case "function_call_output":
                    return trace(for: replySignal(at: timestamp), timestamp: timestamp)
                case "reasoning":
                    return trace(for: .reasoning, timestamp: timestamp)
                case "message":
                    let role = payload?["role"] as? String ?? ""
                    if role == "assistant" {
                        return trace(for: replySignal(at: timestamp), timestamp: timestamp)
                    }
                    if role == "user" {
                        return trace(for: .booting, timestamp: timestamp)
                    }
                case "task_started":
                    return trace(for: .booting, timestamp: timestamp)
                case "task_complete":
                    return trace(for: .completed, timestamp: timestamp)
                default:
                    continue
                }
            default:
                continue
            }
        }
        return trace(for: .quiet, timestamp: fallbackDate)
    }

    // MARK: - Trace Mapping

    private func replySignal(at timestamp: Date) -> SessionSignal {
        let age = Date().timeIntervalSince(timestamp)
        return age < 18 ? .responding : .awaitingUser
    }

    private func trace(for signal: SessionSignal, timestamp: Date) -> SessionTrace {
        let age = Date().timeIntervalSince(timestamp)
        let status: SessionStatus
        let pulse: SessionPulse

        switch signal {
        case .booting, .reasoning, .tooling:
            if age < 90 {
                status = .working
            } else if age < 300 {
                status = .idle
            } else {
                status = .completed
            }

            if age < 10 {
                pulse = .hot
            } else if age < 45 {
                pulse = .warm
            } else if age < 180 {
                pulse = .listening
            } else if age < 300 {
                pulse = .drowsy
            } else {
                pulse = .sleeping
            }

        case .responding:
            if age < 20 {
                status = .working
            } else if age < 300 {
                status = .waitingForInput
            } else {
                status = .completed
            }

            if age < 10 {
                pulse = .hot
            } else if age < 45 {
                pulse = .warm
            } else if age < 180 {
                pulse = .listening
            } else if age < 300 {
                pulse = .drowsy
            } else {
                pulse = .sleeping
            }

        case .awaitingUser:
            status = age < 600 ? .waitingForInput : .idle

            if age < 180 {
                pulse = .listening
            } else if age < 600 {
                pulse = .drowsy
            } else {
                pulse = .sleeping
            }

        case .quiet:
            status = age < 300 ? .idle : .completed
            pulse = age < 180 ? .drowsy : .sleeping

        case .completed:
            status = .completed
            pulse = .sleeping
        }

        return SessionTrace(status: status, signal: signal, pulse: pulse, lastActivity: timestamp)
    }

    // MARK: - Helpers

    private func readRecentJsonlEntries(
        path: String, limit: Int, maxBytes: UInt64 = 131_072
    ) -> [[String: Any]] {
        guard let fh = FileHandle(forReadingAtPath: path) else { return [] }
        defer { fh.closeFile() }

        let fileSize = fh.seekToEndOfFile()
        guard fileSize > 0 else { return [] }

        let readSize = min(fileSize, maxBytes)
        fh.seek(toFileOffset: fileSize - readSize)
        let data = fh.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8) else { return [] }

        var results: [[String: Any]] = []
        for line in str.split(separator: "\n").reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                let raw = trimmed.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any]
            else { continue }
            results.append(json)
            if results.count == limit { break }
        }
        return results
    }

    private func decodeDirName(_ encoded: String) -> String {
        var path = encoded
        if path.hasPrefix("-") { path = String(path.dropFirst()) }
        return "/" + path.replacingOccurrences(of: "-", with: "/")
    }

    private func parseISO(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: str) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str)
    }
}
