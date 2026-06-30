import Foundation

final class CodexSessionProvider: CodingSessionProvider {
    let id = "codex"
    let displayName = "Codex"
    let tool = CodingTool.codex

    private struct IndexMetadata {
        let threadName: String
        let updated: Date
    }

    private struct SessionCacheEntry {
        let modified: Date
        let size: UInt64
        let session: CodingSession
    }

    private struct FileListCache {
        let createdAt: Date
        let paths: [String]
    }

    private let indexPath: String
    private let sessionsPath: String
    private var sessionCache: [String: SessionCacheEntry] = [:]
    private var fileListCache: FileListCache?

    init(
        indexPath: String = NSHomeDirectory() + "/.codex/session_index.jsonl",
        sessionsPath: String = NSHomeDirectory() + "/.codex/sessions"
    ) {
        self.indexPath = indexPath
        self.sessionsPath = sessionsPath
    }

    func scanSessions(now: Date = Date()) -> SessionProviderResult {
        let cutoff = now.addingTimeInterval(-3600)
        let indexMetadata = loadIndexMetadata()
        var fileListCacheHit = 0
        let recentFiles = recentSessionFiles(cutoff: cutoff, limit: 96, now: now, cacheHit: &fileListCacheHit)
        let recentPaths = Set(recentFiles.map(\.path))
        var sessionsByID: [String: CodingSession] = [:]
        var sessionCacheHits = 0

        sessionCache = sessionCache.filter { recentPaths.contains($0.key) }

        for file in recentFiles {
            let filePath = file.path
            if let cached = sessionCache[filePath],
               cached.modified == file.modified,
               cached.size == file.size {
                sessionCacheHits += 1
                upsert(session: cached.session, into: &sessionsByID)
                continue
            }

            let recentEntries = readRecentJsonlEntries(path: filePath, limit: 40, maxBytes: 262_144)
            let metaEntry = readFirstJsonlEntry(path: filePath, maxBytes: 524_288)
            let metaPayload = metaEntry?["payload"] as? [String: Any]
            let sessionId = codexSessionId(filePath: filePath, metaPayload: metaPayload)
            let updated = indexMetadata[sessionId]?.updated ?? file.modified
            let trace = codexTrace(recentEntries: recentEntries, fallbackDate: updated, now: now)
            let threadName = sanitizeTaskText(indexMetadata[sessionId]?.threadName)
            let cwd = codexWorkspace(from: recentEntries, metaPayload: metaPayload)
            let projectPath = cwd ?? threadName ?? "Codex"
            let slug = threadName == nil || threadName == projectPath ? "" : (threadName ?? "")
            let projectName = sanitizeTaskText((projectPath as NSString).lastPathComponent)
            let taskTitle = threadName ?? projectName

            let session = CodingSession(
                id: sessionId,
                tool: .codex,
                projectPath: projectPath,
                slug: slug,
                taskTitle: taskTitle,
                taskSummary: codexTaskSummary(
                    recentEntries: recentEntries,
                    fallback: taskTitle ?? projectName
                ),
                status: trace.status,
                lastActivity: trace.lastActivity,
                signal: trace.signal,
                pulse: trace.pulse
            )

            sessionCache[filePath] = SessionCacheEntry(
                modified: file.modified,
                size: file.size,
                session: session
            )
            upsert(session: session, into: &sessionsByID)
        }

        return SessionProviderResult(
            sessions: Array(sessionsByID.values),
            cacheHits: [
                "codex": sessionCacheHits,
                "codex-file-list": fileListCacheHit
            ]
        )
    }

    private func codexSessionId(filePath: String, metaPayload: [String: Any]?) -> String {
        if let id = metaPayload?["id"] as? String, !id.isEmpty {
            return id
        }

        return (filePath as NSString).lastPathComponent
            .replacingOccurrences(of: ".jsonl", with: "")
            .components(separatedBy: "-")
            .suffix(5)
            .joined(separator: "-")
    }

    private func upsert(session: CodingSession, into sessionsByID: inout [String: CodingSession]) {
        if let existing = sessionsByID[session.id] {
            if session.lastActivity > existing.lastActivity {
                sessionsByID[session.id] = session
            }
            return
        }

        sessionsByID[session.id] = session
    }

    private func codexWorkspace(from recentEntries: [[String: Any]], metaPayload: [String: Any]?) -> String? {
        for entry in recentEntries {
            guard entry["type"] as? String == "turn_context",
                  let payload = entry["payload"] as? [String: Any],
                  let cwd = payload["cwd"] as? String,
                  !cwd.isEmpty
            else { continue }
            return cwd
        }
        return sanitizeTaskText(metaPayload?["cwd"] as? String)
    }

    private func loadIndexMetadata() -> [String: IndexMetadata] {
        guard let content = readTailString(path: indexPath, maxBytes: 8_388_608) else { return [:] }

        var metadata: [String: IndexMetadata] = [:]
        for line in content.split(separator: "\n").reversed() {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sessionId = json["id"] as? String,
                  let threadName = json["thread_name"] as? String,
                  let updatedStr = json["updated_at"] as? String,
                  let updated = parseISO(updatedStr)
            else { continue }
            metadata[sessionId] = IndexMetadata(threadName: threadName, updated: updated)
        }
        return metadata
    }

    private func recentSessionFiles(
        cutoff: Date,
        limit: Int,
        now: Date,
        cacheHit: inout Int
    ) -> [(path: String, modified: Date, size: UInt64)] {
        if let cached = fileListCache,
           now.timeIntervalSince(cached.createdAt) < 30 {
            cacheHit = 1
            return cached.paths
                .compactMap { sessionFileInfo(path: $0, cutoff: cutoff) }
                .sorted { $0.modified > $1.modified }
                .prefix(limit)
                .map { $0 }
        }

        guard let enumerator = FileManager.default.enumerator(atPath: sessionsPath) else { return [] }
        var files: [(path: String, modified: Date, size: UInt64)] = []
        while let relativePath = enumerator.nextObject() as? String {
            guard relativePath.hasSuffix(".jsonl") else { continue }
            let fullPath = sessionsPath + "/" + relativePath
            guard let file = sessionFileInfo(path: fullPath, cutoff: cutoff) else { continue }
            files.append(file)
        }

        let recentFiles = files
            .sorted { $0.modified > $1.modified }
            .prefix(limit)
            .map { $0 }
        fileListCache = FileListCache(createdAt: now, paths: recentFiles.map(\.path))
        return recentFiles
    }

    private func sessionFileInfo(path: String, cutoff: Date) -> (path: String, modified: Date, size: UInt64)? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modified = attrs[.modificationDate] as? Date,
              let rawSize = attrs[.size],
              modified > cutoff
        else { return nil }

        let size: UInt64
        if let value = rawSize as? UInt64 {
            size = value
        } else if let value = rawSize as? NSNumber {
            size = value.uint64Value
        } else {
            return nil
        }

        return (path: path, modified: modified, size: size)
    }

    private func codexTaskSummary(recentEntries: [[String: Any]], fallback: String?) -> String? {
        for entry in recentEntries {
            let topType = entry["type"] as? String ?? ""
            let payload = entry["payload"] as? [String: Any]

            switch topType {
            case "event_msg":
                guard payload?["type"] as? String == "user_message" else { continue }
                if let summary = codexPromptText(from: payload?["message"] ?? payload?["content"]) {
                    return summary
                }
            case "response_item":
                guard payload?["type"] as? String == "message",
                      payload?["role"] as? String == "user"
                else { continue }
                if let summary = codexPromptText(from: payload?["content"]) {
                    return summary
                }
            default:
                continue
            }
        }
        return sanitizeTaskText(fallback)
    }

    private func codexPromptText(from raw: Any?) -> String? {
        guard var text = extractRawText(from: raw) else { return nil }

        for marker in ["## My request for Codex:", "My request for Codex:"] {
            if let range = text.range(of: marker) {
                text = String(text[range.upperBound...])
                break
            }
        }

        text = text.replacingOccurrences(
            of: #"\[@[^\]]+\]\(plugin://[^)]+\)"#,
            with: "",
            options: .regularExpression
        )

        let cleaned = sanitizeTaskText(text)
        guard let cleaned else { return nil }
        let normalized = cleaned.lowercased()
        if normalized.hasPrefix("# files mentioned by the user")
            || normalized.hasPrefix("files mentioned by the user")
        {
            return nil
        }
        return cleaned
    }

    private func codexTrace(recentEntries: [[String: Any]], fallbackDate: Date, now: Date) -> SessionTrace {
        for entry in recentEntries {
            let timestamp = parseISO(entry["timestamp"] as? String ?? "") ?? fallbackDate
            let topType = entry["type"] as? String ?? ""
            let payload = entry["payload"] as? [String: Any]
            let payloadType = payload?["type"] as? String ?? ""

            switch topType {
            case "event_msg":
                switch payloadType {
                case "agent_message":
                    return trace(for: replySignal(at: timestamp, now: now), timestamp: timestamp, now: now)
                case "agent_message_delta":
                    return trace(for: .responding, timestamp: timestamp, now: now)
                case "agent_reasoning":
                    return trace(for: .reasoning, timestamp: timestamp, now: now)
                case "user_message", "task_started":
                    return trace(for: .booting, timestamp: timestamp, now: now)
                case "task_complete":
                    return trace(for: .completed, timestamp: timestamp, now: now)
                case let kind where kind.hasSuffix("_begin") || kind.contains("command") || kind.contains("tool"):
                    return trace(for: .tooling, timestamp: timestamp, now: now)
                default:
                    continue
                }
            case "response_item":
                switch payloadType {
                case let kind where kind.hasSuffix("_call"):
                    return trace(for: .tooling, timestamp: timestamp, now: now)
                case let kind where kind.hasSuffix("_call_output"):
                    return trace(for: replySignal(at: timestamp, now: now), timestamp: timestamp, now: now)
                case "reasoning":
                    return trace(for: .reasoning, timestamp: timestamp, now: now)
                case "message":
                    let role = payload?["role"] as? String ?? ""
                    if role == "assistant" {
                        return trace(for: replySignal(at: timestamp, now: now), timestamp: timestamp, now: now)
                    }
                    if role == "user" {
                        return trace(for: .booting, timestamp: timestamp, now: now)
                    }
                case "task_complete":
                    return trace(for: .completed, timestamp: timestamp, now: now)
                default:
                    continue
                }
            default:
                continue
            }
        }
        return trace(for: .quiet, timestamp: fallbackDate, now: now)
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

    private func readFirstJsonlEntry(path: String, maxBytes: Int = 32_768) -> [String: Any]? {
        guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
        defer { fh.closeFile() }

        var buffer = Data()
        while buffer.count < maxBytes {
            let chunk = fh.readData(ofLength: min(65_536, maxBytes - buffer.count))
            guard !chunk.isEmpty else { break }
            buffer.append(chunk)
            if buffer.firstIndex(of: 0x0A) != nil { break }
        }

        guard let newlineIndex = buffer.firstIndex(of: 0x0A) ?? buffer.indices.last,
              let raw = Data(buffer[...newlineIndex]).split(separator: 0x0A).first,
              let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any]
        else { return nil }
        return json
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
