import Foundation

// MARK: - Session Models

struct CodingSession: Identifiable, Sendable {
    let id: String
    let tool: CodingTool
    let projectPath: String
    let slug: String
    let taskTitle: String?
    let taskSummary: String?
    let status: SessionStatus
    let lastActivity: Date
    let signal: SessionSignal
    let pulse: SessionPulse

    var projectName: String {
        let name = (projectPath as NSString).lastPathComponent
        return name.isEmpty ? projectPath : name
    }

    var primaryTaskText: String? {
        let candidates = [taskSummary, taskTitle, slug]
        return candidates.first(where: { ($0 ?? "").isEmpty == false }) ?? nil
    }
}

struct SessionScanBreakdown: Sendable {
    let sessions: [CodingSession]
    let claudeDuration: TimeInterval
    let codexDuration: TimeInterval
    let openCodeDuration: TimeInterval
    let codexCacheHits: Int
    let codexFileListCacheHits: Int
    let openCodeCacheHits: Int

    var totalDuration: TimeInterval {
        claudeDuration + codexDuration + openCodeDuration
    }

    var claudeCount: Int {
        sessions.filter { $0.tool == .claudeCode }.count
    }

    var codexCount: Int {
        sessions.filter { $0.tool == .codex }.count
    }

    var openCodeCount: Int {
        sessions.filter { $0.tool == .openCode }.count
    }
}

enum CodingTool: String, Sendable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case openCode = "OpenCode"

    var icon: String {
        switch self {
        case .claudeCode: return "brain.head.profile"
        case .codex: return "cube.transparent"
        case .openCode: return "terminal"
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

    var compactLabel: String {
        switch self {
        case .booting: return "starting"
        case .reasoning: return "thinking"
        case .tooling: return "tooling"
        case .responding: return "replying"
        case .awaitingUser: return "waiting"
        case .quiet: return "warm"
        case .completed: return "done"
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

    private struct CodexIndexMetadata {
        let threadName: String
        let updated: Date
    }

    private struct CodexSessionCacheEntry {
        let modified: Date
        let size: UInt64
        let session: CodingSession
    }

    private struct CodexFileListCache {
        let createdAt: Date
        let paths: [String]
    }

    private struct FileSnapshot: Equatable {
        let modified: Date
        let size: UInt64
    }

    private struct OpenCodeCacheKey: Equatable {
        let db: FileSnapshot
        let wal: FileSnapshot?
    }

    private struct OpenCodeSessionCache {
        let createdAt: Date
        let key: OpenCodeCacheKey
        let sessions: [CodingSession]
    }

    private let home = NSHomeDirectory()
    private var claudeDir: String { home + "/.claude/projects" }
    private var codexIndex: String { home + "/.codex/session_index.jsonl" }
    private var codexSessions: String { home + "/.codex/sessions" }
    private var openCodeDB: String { home + "/.local/share/opencode/opencode.db" }
    private var codexSessionCache: [String: CodexSessionCacheEntry] = [:]
    private var codexFileListCache: CodexFileListCache?
    private var openCodeSessionCache: OpenCodeSessionCache?
    private var lastCodexCacheHits = 0
    private var lastCodexFileListCacheHits = 0
    private var lastOpenCodeCacheHits = 0
    private let scanLock = NSLock()

    func scanSessions() -> [CodingSession] {
        scanSessionBreakdown().sessions
    }

    func scanSessionBreakdown() -> SessionScanBreakdown {
        scanLock.lock()
        defer { scanLock.unlock() }

        let (claudeSessions, claudeDuration) = timedScan { scanClaudeSessions() }
        let (codexSessions, codexDuration) = timedScan { scanCodexSessions() }
        let (openCodeSessions, openCodeDuration) = timedScan { scanOpenCodeSessions() }

        var sessions = claudeSessions + codexSessions + openCodeSessions
        sessions.sort { lhs, rhs in
            if lhs.pulse != rhs.pulse { return lhs.pulse.rawValue > rhs.pulse.rawValue }
            return lhs.lastActivity > rhs.lastActivity
        }

        return SessionScanBreakdown(
            sessions: sessions,
            claudeDuration: claudeDuration,
            codexDuration: codexDuration,
            openCodeDuration: openCodeDuration,
            codexCacheHits: lastCodexCacheHits,
            codexFileListCacheHits: lastCodexFileListCacheHits,
            openCodeCacheHits: lastOpenCodeCacheHits
        )
    }

    private func timedScan(_ scan: () -> [CodingSession]) -> (sessions: [CodingSession], duration: TimeInterval) {
        let start = Date()
        let sessions = scan()
        return (sessions, Date().timeIntervalSince(start))
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
                let projectName = sanitizeTaskText((cwd as NSString).lastPathComponent)
                let trace = claudeTrace(recentEntries: recentEntries, fallbackDate: modified)

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
        let cutoff = Date().addingTimeInterval(-3600)
        let indexMetadata = loadCodexIndexMetadata(cutoff: cutoff)
        lastCodexFileListCacheHits = 0
        let recentFiles = recentCodexSessionFiles(cutoff: cutoff, limit: 96)
        let recentPaths = Set(recentFiles.map(\.path))
        var sessionsByID: [String: CodingSession] = [:]
        var cacheHits = 0

        codexSessionCache = codexSessionCache.filter { recentPaths.contains($0.key) }

        for file in recentFiles {
            let filePath = file.path
            if let cached = codexSessionCache[filePath],
               cached.modified == file.modified,
               cached.size == file.size {
                cacheHits += 1
                upsert(session: cached.session, into: &sessionsByID)
                continue
            }

            let recentEntries = readRecentJsonlEntries(path: filePath, limit: 40, maxBytes: 262_144)
            let metaEntry = readFirstJsonlEntry(path: filePath, maxBytes: 524_288)
            let metaPayload = metaEntry?["payload"] as? [String: Any]
            let fileName = (filePath as NSString).lastPathComponent
            let inferredID = fileName
                .replacingOccurrences(of: ".jsonl", with: "")
                .components(separatedBy: "-")
                .suffix(5)
                .joined(separator: "-")
            let sessionId = (metaPayload?["id"] as? String) ?? inferredID

            let modified = ((try? fm.attributesOfItem(atPath: filePath))?[.modificationDate] as? Date)
                ?? Date.distantPast
            let updated = indexMetadata[sessionId]?.updated ?? modified
            let trace = codexTrace(recentEntries: recentEntries, fallbackDate: updated)
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

            codexSessionCache[filePath] = CodexSessionCacheEntry(
                modified: file.modified,
                size: file.size,
                session: session
            )
            upsert(session: session, into: &sessionsByID)
        }

        lastCodexCacheHits = cacheHits
        return Array(sessionsByID.values)
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

    private func loadCodexIndexMetadata(cutoff: Date) -> [String: CodexIndexMetadata] {
        guard let content = readTailString(path: codexIndex, maxBytes: 524_288) else { return [:] }

        var metadata: [String: CodexIndexMetadata] = [:]
        for line in content.split(separator: "\n").reversed() {
            guard let ld = line.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: ld) as? [String: Any],
                let sessionId = json["id"] as? String,
                let threadName = json["thread_name"] as? String,
                let updatedStr = json["updated_at"] as? String,
                let updated = parseISO(updatedStr),
                updated > cutoff
            else { continue }
            metadata[sessionId] = CodexIndexMetadata(threadName: threadName, updated: updated)
            if metadata.count >= 64 { break }
        }
        return metadata
    }

    private func recentCodexSessionFiles(cutoff: Date, limit: Int) -> [(path: String, modified: Date, size: UInt64)] {
        guard let enumerator = FileManager.default.enumerator(atPath: codexSessions) else { return [] }

        let now = Date()
        if let cached = codexFileListCache,
           now.timeIntervalSince(cached.createdAt) < 30 {
            lastCodexFileListCacheHits = 1
            return cached.paths
                .compactMap { codexSessionFileInfo(path: $0, cutoff: cutoff) }
                .sorted { $0.modified > $1.modified }
                .prefix(limit)
                .map { $0 }
        }

        var files: [(path: String, modified: Date, size: UInt64)] = []
        while let relativePath = enumerator.nextObject() as? String {
            guard relativePath.hasSuffix(".jsonl") else { continue }
            let fullPath = codexSessions + "/" + relativePath
            guard let file = codexSessionFileInfo(path: fullPath, cutoff: cutoff) else { continue }
            files.append(file)
        }

        let recentFiles = files
            .sorted { $0.modified > $1.modified }
            .prefix(limit)
            .map { $0 }
        codexFileListCache = CodexFileListCache(
            createdAt: now,
            paths: recentFiles.map(\.path)
        )
        return recentFiles
    }

    private func codexSessionFileInfo(path: String, cutoff: Date) -> (path: String, modified: Date, size: UInt64)? {
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
                if let summary = extractText(from: payload?["message"] ?? payload?["content"]) {
                    return summary
                }
            case "response_item":
                guard payload?["type"] as? String == "message",
                    payload?["role"] as? String == "user"
                else { continue }
                if let summary = extractText(from: payload?["content"]) {
                    return summary
                }
            default:
                continue
            }
        }
        return sanitizeTaskText(fallback)
    }

    private func codexTrace(recentEntries: [[String: Any]], fallbackDate: Date) -> SessionTrace {
        for entry in recentEntries {
            let timestamp = parseISO(entry["timestamp"] as? String ?? "") ?? fallbackDate
            let topType = entry["type"] as? String ?? ""
            let payload = entry["payload"] as? [String: Any]
            let payloadType = payload?["type"] as? String ?? ""

            switch topType {
            case "event_msg":
                switch payloadType {
                case "agent_message":
                    return trace(for: replySignal(at: timestamp), timestamp: timestamp)
                case "agent_message_delta":
                    return trace(for: .responding, timestamp: timestamp)
                case "agent_reasoning":
                    return trace(for: .reasoning, timestamp: timestamp)
                case "user_message", "task_started":
                    return trace(for: .booting, timestamp: timestamp)
                case "task_complete":
                    return trace(for: .completed, timestamp: timestamp)
                case let kind where kind.hasSuffix("_begin") || kind.contains("command") || kind.contains("tool"):
                    return trace(for: .tooling, timestamp: timestamp)
                default:
                    continue
                }
            case "response_item":
                switch payloadType {
                case let kind where kind.hasSuffix("_call"):
                    return trace(for: .tooling, timestamp: timestamp)
                case let kind where kind.hasSuffix("_call_output"):
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

    // MARK: - OpenCode

    private func scanOpenCodeSessions() -> [CodingSession] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: openCodeDB),
              let cacheKey = openCodeCacheKey()
        else {
            lastOpenCodeCacheHits = 0
            openCodeSessionCache = nil
            return []
        }

        let now = Date()
        if let cached = openCodeSessionCache,
           cached.key == cacheKey,
           now.timeIntervalSince(cached.createdAt) < 30 {
            lastOpenCodeCacheHits = 1
            return cached.sessions
        }
        lastOpenCodeCacheHits = 0

        let cutoff = Date().addingTimeInterval(-3600)
        let query = [
            "select s.id, s.slug, s.directory, s.title, s.time_created, s.time_updated",
            "from session s",
            "where s.time_archived is null and s.time_updated >= \(Int64(cutoff.timeIntervalSince1970 * 1000))",
            "order by s.time_updated desc",
            "limit 64;"
        ].joined(separator: " ")

        let rows = runSQLiteLines(database: openCodeDB, sql: query)
        let sessionIds = rows.compactMap { row -> String? in
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard let sessionId = columns.first, !sessionId.isEmpty else { return nil }
            return sessionId
        }
        let messagesBySession = readOpenCodeMessagesBySession(sessionIds: sessionIds)
        var sessions: [CodingSession] = []

        for row in rows {
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 6 else { continue }

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
            let trace = openCodeTrace(latestMessage: latestMessage, fallbackDate: fallbackDate)
            let projectName = sanitizeTaskText((directory as NSString).lastPathComponent)
            let safeSlug = sanitizeTaskText(slug) ?? ""
            let fallbackTitle = title ?? sanitizeTaskText(safeSlug) ?? projectName

            sessions.append(
                CodingSession(
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
                ))
        }

        openCodeSessionCache = OpenCodeSessionCache(
            createdAt: now,
            key: cacheKey,
            sessions: sessions
        )
        return sessions
    }

    private func openCodeCacheKey() -> OpenCodeCacheKey? {
        guard let db = fileSnapshot(path: openCodeDB) else { return nil }
        let wal = fileSnapshot(path: openCodeDB + "-wal")
        return OpenCodeCacheKey(db: db, wal: wal)
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

    private func openCodeTrace(latestMessage: [String: Any]?, fallbackDate: Date) -> SessionTrace {
        guard let latestMessage else {
            return trace(for: .quiet, timestamp: fallbackDate)
        }

        let time = latestMessage["time"] as? [String: Any]
        let completedAt = millisToDate(time?["completed"])
        let createdAt = millisToDate(time?["created"])
        let timestamp = completedAt ?? createdAt ?? fallbackDate
        let role = latestMessage["role"] as? String ?? ""

        switch role {
        case "user":
            return trace(for: .booting, timestamp: timestamp)
        case "assistant":
            if completedAt == nil {
                return trace(for: .responding, timestamp: timestamp)
            }
            let finish = latestMessage["finish"] as? String ?? ""
            if finish == "tool-calls" {
                return trace(for: .tooling, timestamp: timestamp)
            }
            return trace(for: replySignal(at: timestamp), timestamp: timestamp)
        default:
            return trace(for: .quiet, timestamp: timestamp)
        }
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
        guard let str = readTailString(path: path, maxBytes: maxBytes) else { return [] }

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

    private func decodeDirName(_ encoded: String) -> String {
        var path = encoded
        if path.hasPrefix("-") { path = String(path.dropFirst()) }
        return "/" + path.replacingOccurrences(of: "-", with: "/")
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
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private func readOpenCodeMessagesBySession(sessionIds: [String], limit: Int = 8) -> [String: [[String: Any]]] {
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
        for row in runSQLiteLines(database: openCodeDB, sql: sql) {
            let columns = row.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            guard columns.count == 2,
                  let message = parseJSONString(columns[1])
            else { continue }
            messagesBySession[columns[0], default: []].append(message)
        }
        return messagesBySession
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
        if let text = raw as? String {
            return sanitizeTaskText(text)
        }

        if let dict = raw as? [String: Any] {
            if let text = dict["text"] as? String {
                return sanitizeTaskText(text)
            }
            if let content = dict["content"] {
                return extractText(from: content)
            }
            if let message = dict["message"] {
                return extractText(from: message)
            }
        }

        if let array = raw as? [Any] {
            let text = array.compactMap { item -> String? in
                if let string = item as? String {
                    return string
                }
                if let dict = item as? [String: Any] {
                    return extractText(from: dict["text"] ?? dict["content"] ?? dict["message"])
                }
                return nil
            }.joined(separator: " ")
            return sanitizeTaskText(text)
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

    private func parseISO(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: str) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str)
    }
}
