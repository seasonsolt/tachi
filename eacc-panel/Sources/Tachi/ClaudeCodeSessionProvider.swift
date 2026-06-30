import Foundation

final class ClaudeCodeSessionProvider: CodingSessionProvider {
    let id = "claude-code"
    let displayName = "Claude Code"
    let tool = CodingTool.claudeCode

    private let projectsPath: String

    init(projectsPath: String = NSHomeDirectory() + "/.claude/projects") {
        self.projectsPath = projectsPath
    }

    func scanSessions(now: Date = Date()) -> SessionProviderResult {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(atPath: projectsPath) else {
            return SessionProviderResult(sessions: [])
        }

        let cutoff = now.addingTimeInterval(-3600)
        var sessions: [CodingSession] = []

        for dir in dirs {
            let projectDir = projectsPath + "/" + dir
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
                let projectName = sanitizeTaskText((cwd as NSString).lastPathComponent)
                let trace = claudeTrace(recentEntries: recentEntries, fallbackDate: modified, now: now)

                sessions.append(
                    CodingSession(
                        id: sessionId,
                        tool: .claudeCode,
                        projectPath: cwd,
                        slug: slug,
                        taskTitle: sanitizeTaskText(slug) ?? projectName,
                        taskSummary: claudeTaskSummary(
                            recentEntries: recentEntries,
                            fallback: sanitizeTaskText(slug) ?? projectName
                        ),
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
                if session.lastActivity > existing.lastActivity {
                    best[session.projectPath] = session
                }
            } else {
                best[session.projectPath] = session
            }
        }
        return SessionProviderResult(sessions: Array(best.values))
    }

    private func claudeTrace(recentEntries: [[String: Any]], fallbackDate: Date, now: Date) -> SessionTrace {
        for entry in recentEntries {
            let timestamp = parseISO(entry["timestamp"] as? String ?? "") ?? fallbackDate
            switch entry["type"] as? String ?? "" {
            case "assistant":
                return trace(for: replySignal(at: timestamp, now: now), timestamp: timestamp, now: now)
            case "user":
                return trace(for: .booting, timestamp: timestamp, now: now)
            case "progress":
                if let data = entry["data"] as? [String: Any],
                   data["type"] as? String == "hook_progress"
                {
                    return trace(for: .tooling, timestamp: timestamp, now: now)
                }
                return trace(for: .reasoning, timestamp: timestamp, now: now)
            default:
                continue
            }
        }
        return trace(for: .quiet, timestamp: fallbackDate, now: now)
    }

    private func claudeTaskSummary(recentEntries: [[String: Any]], fallback: String?) -> String? {
        for entry in recentEntries {
            guard entry["type"] as? String == "user" else { continue }
            if let summary = extractText(from: entry["message"] ?? entry["content"]) {
                return summary
            }
        }
        return sanitizeTaskText(fallback)
    }

    private func replySignal(at timestamp: Date, now: Date) -> SessionSignal {
        now.timeIntervalSince(timestamp) < 18 ? .responding : .awaitingUser
    }

    private func trace(for signal: SessionSignal, timestamp: Date, now: Date) -> SessionTrace {
        let age = now.timeIntervalSince(timestamp)
        let status: SessionStatus
        let pulse: SessionPulse

        switch signal {
        case .booting, .reasoning, .tooling:
            status = age < 90 ? .working : (age < 300 ? .idle : .completed)
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
            status = age < 20 ? .working : (age < 300 ? .waitingForInput : .completed)
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
            pulse = age < 180 ? .listening : (age < 600 ? .drowsy : .sleeping)
        case .quiet:
            status = age < 300 ? .idle : .completed
            pulse = age < 180 ? .drowsy : .sleeping
        case .completed:
            status = .completed
            pulse = .sleeping
        }

        return SessionTrace(status: status, signal: signal, pulse: pulse, lastActivity: timestamp)
    }

    private func readRecentJsonlEntries(path: String, limit: Int, maxBytes: UInt64 = 131_072) -> [[String: Any]] {
        guard let string = readTailString(path: path, maxBytes: maxBytes) else { return [] }

        var results: [[String: Any]] = []
        for line in string.split(separator: "\n").reversed() {
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

    private func readTailString(path: String, maxBytes: UInt64) -> String? {
        guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
        defer { fh.closeFile() }

        let fileSize = fh.seekToEndOfFile()
        guard fileSize > 0 else { return "" }

        let readSize = min(fileSize, maxBytes)
        fh.seek(toFileOffset: fileSize - readSize)
        let data = fh.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func decodeDirName(_ encoded: String) -> String {
        var path = encoded
        if path.hasPrefix("-") { path = String(path.dropFirst()) }
        return "/" + path.replacingOccurrences(of: "-", with: "/")
    }

    private func extractText(from raw: Any?) -> String? {
        sanitizeTaskText(extractRawText(from: raw))
    }

    private func extractRawText(from raw: Any?) -> String? {
        if let text = raw as? String {
            return text
        }

        if let dict = raw as? [String: Any] {
            if let text = dict["text"] as? String {
                return text
            }
            if let content = dict["content"] {
                return extractRawText(from: content)
            }
            if let message = dict["message"] {
                return extractRawText(from: message)
            }
        }

        if let array = raw as? [Any] {
            let text = array.compactMap { item -> String? in
                if let string = item as? String {
                    return string
                }
                if let dict = item as? [String: Any] {
                    return extractRawText(from: dict["text"] ?? dict["content"] ?? dict["message"])
                }
                return nil
            }.joined(separator: " ")
            return text
        }

        return nil
    }

    private func sanitizeTaskText(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let squashed = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !squashed.isEmpty else { return nil }
        guard squashed.count > 120 else { return squashed }
        return String(squashed.prefix(117)) + "..."
    }

    private static let isoFormatterFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func parseISO(_ string: String) -> Date? {
        if let date = Self.isoFormatterFractional.date(from: string) { return date }
        return Self.isoFormatter.date(from: string)
    }
}
