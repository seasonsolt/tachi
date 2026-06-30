import Foundation

final class OpenCodeSessionProvider: CodingSessionProvider {
    let id = "opencode"
    let displayName = "OpenCode"
    let tool = CodingTool.openCode

    private struct FileSnapshot: Equatable {
        let modified: Date
        let size: UInt64
    }

    private struct CacheKey: Equatable {
        let db: FileSnapshot
        let wal: FileSnapshot?
    }

    private struct SessionCache {
        let createdAt: Date
        let key: CacheKey
        let sessions: [CodingSession]
    }

    private let databasePath: String
    private var cache: SessionCache?

    init(databasePath: String = NSHomeDirectory() + "/.local/share/opencode/opencode.db") {
        self.databasePath = databasePath
    }

    func scanSessions(now: Date = Date()) -> SessionProviderResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: databasePath),
              let cacheKey = openCodeCacheKey()
        else {
            cache = nil
            return SessionProviderResult(sessions: [])
        }

        if let cache,
           cache.key == cacheKey,
           now.timeIntervalSince(cache.createdAt) < 30 {
            return SessionProviderResult(sessions: cache.sessions, cacheHits: ["opencode": 1])
        }

        let cutoff = now.addingTimeInterval(-3600)
        let rows = runSQLiteLines(database: databasePath, sql: [
            "select s.id, s.slug, s.directory, s.title, s.time_created, s.time_updated",
            "from session s",
            "where s.time_archived is null and s.time_updated >= \(Int64(cutoff.timeIntervalSince1970 * 1000))",
            "order by s.time_updated desc",
            "limit 64;"
        ].joined(separator: " "))

        let sessionIds = rows.compactMap { row -> String? in
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard let sessionId = columns.first, !sessionId.isEmpty else { return nil }
            return sessionId
        }
        let messagesBySession = readMessagesBySession(sessionIds: sessionIds)

        let sessions = rows.compactMap { row -> CodingSession? in
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 6 else { return nil }

            let sessionId = columns[0]
            let slug = columns[1]
            let directory = columns[2]
            let title = openCodeTaskTitle(title: columns[3], slug: slug)
            let createdAtMs = Double(columns[4]) ?? 0
            let updatedAtMs = Double(columns[5]) ?? 0
            let recentMessages = messagesBySession[sessionId] ?? []
            let latestMessage = recentMessages.first
            let latestUserMessage = recentMessages.first(where: { ($0["role"] as? String) == "user" })
            let fallbackDate = updatedAtMs > 0
                ? Date(timeIntervalSince1970: updatedAtMs / 1000)
                : Date(timeIntervalSince1970: createdAtMs / 1000)
            let trace = openCodeTrace(latestMessage: latestMessage, fallbackDate: fallbackDate, now: now)
            let projectName = sanitizeTaskText((directory as NSString).lastPathComponent)
            let safeSlug = sanitizeTaskText(slug) ?? ""
            let fallbackTitle = title ?? sanitizeTaskText(safeSlug) ?? projectName

            return CodingSession(
                id: sessionId,
                tool: .openCode,
                projectPath: directory,
                slug: safeSlug,
                taskTitle: fallbackTitle,
                taskSummary: openCodeTaskSummary(
                    latestMessage: latestMessage,
                    latestUserMessage: latestUserMessage,
                    fallback: fallbackTitle
                ),
                status: trace.status,
                lastActivity: trace.lastActivity,
                signal: trace.signal,
                pulse: trace.pulse
            )
        }

        cache = SessionCache(createdAt: now, key: cacheKey, sessions: sessions)
        return SessionProviderResult(sessions: sessions)
    }

    private func openCodeCacheKey() -> CacheKey? {
        guard let db = fileSnapshot(path: databasePath) else { return nil }
        return CacheKey(db: db, wal: fileSnapshot(path: databasePath + "-wal"))
    }

    private func fileSnapshot(path: String) -> FileSnapshot? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modified = attrs[.modificationDate] as? Date,
              let rawSize = attrs[.size]
        else { return nil }

        let size: UInt64
        if let value = rawSize as? UInt64 {
            size = value
        } else if let value = rawSize as? NSNumber {
            size = value.uint64Value
        } else {
            return nil
        }

        return FileSnapshot(modified: modified, size: size)
    }

    private func readMessagesBySession(sessionIds: [String], limit: Int = 8) -> [String: [[String: Any]]] {
        let uniqueIds = Array(Set(sessionIds)).filter { !$0.isEmpty }
        guard !uniqueIds.isEmpty else { return [:] }

        let quotedIds = uniqueIds.map(quoteSQLite).joined(separator: ",")
        let sql = [
            "select session_id, data",
            "from (",
            "select session_id, data,",
            "row_number() over (partition by session_id order by time_updated desc) as row_num",
            "from message",
            "where session_id in (\(quotedIds))",
            ")",
            "where row_num <= \(limit)",
            "order by session_id, row_num;"
        ].joined(separator: " ")

        var messagesBySession: [String: [[String: Any]]] = [:]
        for row in runSQLiteLines(database: databasePath, sql: sql) {
            let columns = row.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            guard columns.count == 2,
                  let message = parseJSONString(columns[1])
            else { continue }
            messagesBySession[columns[0], default: []].append(message)
        }
        return messagesBySession
    }

    private func openCodeTaskSummary(
        latestMessage: [String: Any]?, latestUserMessage: [String: Any]?, fallback: String?
    ) -> String? {
        if let summary = extractText(from: latestUserMessage?["summary"]) {
            return summary
        }
        if let summary = extractText(from: latestUserMessage?["content"] ?? latestUserMessage?["message"]) {
            return summary
        }
        if let summary = extractText(from: latestMessage?["summary"]) {
            return summary
        }
        return sanitizeTaskText(fallback)
    }

    private func openCodeTaskTitle(title rawTitle: String?, slug rawSlug: String?) -> String? {
        let title = sanitizeTaskText(rawTitle)
        if let title, !title.hasPrefix("New session - ") {
            return title
        }
        return sanitizeTaskText(rawSlug)
    }

    private func openCodeTrace(latestMessage: [String: Any]?, fallbackDate: Date, now: Date) -> SessionTrace {
        guard let latestMessage else {
            return trace(for: .quiet, timestamp: fallbackDate, now: now)
        }

        let time = latestMessage["time"] as? [String: Any]
        let completedAt = millisToDate(time?["completed"])
        let createdAt = millisToDate(time?["created"])
        let timestamp = completedAt ?? createdAt ?? fallbackDate
        let role = latestMessage["role"] as? String ?? ""

        switch role {
        case "user":
            return trace(for: .booting, timestamp: timestamp, now: now)
        case "assistant":
            if completedAt == nil {
                return trace(for: .responding, timestamp: timestamp, now: now)
            }
            let finish = latestMessage["finish"] as? String ?? ""
            if finish == "tool-calls" {
                return trace(for: .tooling, timestamp: timestamp, now: now)
            }
            return trace(for: replySignal(at: timestamp, now: now), timestamp: timestamp, now: now)
        default:
            return trace(for: .quiet, timestamp: timestamp, now: now)
        }
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

    private func runSQLiteLines(database: String, sql: String) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-separator", "\t", database, sql]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return [] }
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private func quoteSQLite(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "''"))'"
    }

    private func parseJSONString(_ raw: String) -> [String: Any]? {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private func millisToDate(_ raw: Any?) -> Date? {
        if let value = raw as? Double { return Date(timeIntervalSince1970: value / 1000) }
        if let value = raw as? Int { return Date(timeIntervalSince1970: Double(value) / 1000) }
        if let value = raw as? Int64 { return Date(timeIntervalSince1970: Double(value) / 1000) }
        return nil
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
}
