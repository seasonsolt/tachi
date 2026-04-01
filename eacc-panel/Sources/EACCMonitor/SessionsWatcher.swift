import Foundation

// MARK: - Session watcher for ~/.claude/sessions and OpenCode sqlite state

final class SessionsWatcher: @unchecked Sendable {
    private struct OpenCodeProcess {
        let pid: Int
        let cwd: String
    }

    private struct OpenCodeSessionRecord {
        let sessionId: String
        let cwd: String
        let startedAt: Int
        let taskTitle: String?
        let taskSummary: String?
    }

    private let claudeSessionsDir: String
    private let openCodeDir: String
    private let openCodeDB: String
    private let queue = DispatchQueue(label: "sessions.watcher", qos: .utility)
    private var sources: [DispatchSourceFileSystemObject] = []
    private var debounceWork: DispatchWorkItem?
    private var retryWork: DispatchWorkItem?
    private var pollTimer: DispatchSourceTimer?

    var onChange: (([EACCSessionInfo]) -> Void)?

    init() {
        let home = NSHomeDirectory()
        claudeSessionsDir = home + "/.claude/sessions"
        openCodeDir = home + "/.local/share/opencode"
        openCodeDB = openCodeDir + "/opencode.db"
    }

    // MARK: - Lifecycle

    func start() {
        queue.async { [self] in
            readAndNotify()
        }
        startWatching()
        startPolling()
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        retryWork?.cancel()
        retryWork = nil
        pollTimer?.cancel()
        pollTimer = nil

        for source in sources {
            source.cancel()
        }
        sources.removeAll()
    }

    // MARK: - Watching

    private func startWatching() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        retryWork?.cancel()
        retryWork = nil

        let fm = FileManager.default
        if !fm.fileExists(atPath: claudeSessionsDir) {
            try? fm.createDirectory(atPath: claudeSessionsDir, withIntermediateDirectories: true)
        }

        let watchPaths = existingWatchPaths()
        if watchPaths.isEmpty {
            scheduleRetry()
            return
        }

        var openedAny = false
        for path in watchPaths {
            let fd = Darwin.open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            openedAny = true

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete, .extend],
                queue: queue
            )

            source.setEventHandler { [weak self] in
                self?.debouncedRead()
            }

            source.setCancelHandler {
                Darwin.close(fd)
            }

            sources.append(source)
            source.resume()
        }

        if !openedAny {
            scheduleRetry()
        }
    }

    private func existingWatchPaths() -> [String] {
        let fm = FileManager.default
        var paths: [String] = [claudeSessionsDir]

        if fm.fileExists(atPath: openCodeDir) {
            paths.append(openCodeDir)
        }
        if fm.fileExists(atPath: openCodeDB) {
            paths.append(openCodeDB)
        }

        let wal = openCodeDB + "-wal"
        if fm.fileExists(atPath: wal) {
            paths.append(wal)
        }

        return Array(Set(paths))
    }

    private func scheduleRetry() {
        let work = DispatchWorkItem { [weak self] in
            self?.startWatching()
        }
        retryWork = work
        queue.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            self?.readAndNotify()
            self?.startWatching()
        }
        pollTimer = timer
        timer.resume()
    }

    private func debouncedRead() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.readAndNotify()
            self?.startWatching()
        }
        debounceWork = work
        queue.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func readAndNotify() {
        let sessions = readSessions()
        onChange?(sessions)
    }

    // MARK: - Session reading

    private func readSessions() -> [EACCSessionInfo] {
        readClaudeSessions() + readOpenCodeSessions()
    }

    private func readClaudeSessions() -> [EACCSessionInfo] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: claudeSessionsDir) else { return [] }

        var sessions: [EACCSessionInfo] = []
        for file in files where file.hasSuffix(".json") {
            let path = claudeSessionsDir + "/" + file
            guard let data = fm.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            guard let pid = json["pid"] as? Int,
                  let sessionId = json["sessionId"] as? String,
                  let cwd = json["cwd"] as? String,
                  let startedAt = json["startedAt"] as? Int
            else { continue }

            let alive = kill(Int32(pid), 0) == 0
            guard alive else { continue }

            sessions.append(EACCSessionInfo(
                pid: pid,
                sessionId: sessionId,
                cwd: cwd,
                startedAt: startedAt,
                alive: alive,
                tool: "claude_code",
                taskTitle: nil,
                taskSummary: nil
            ))
        }

        return sessions
    }

    private func readOpenCodeSessions() -> [EACCSessionInfo] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: openCodeDB) else { return [] }

        let processes = readOpenCodeProcesses()
        guard !processes.isEmpty else { return [] }

        var sessionsByID: [String: EACCSessionInfo] = [:]
        for process in processes {
            guard let record = readLatestOpenCodeSession(for: process.cwd) else { continue }

            let session = EACCSessionInfo(
                pid: process.pid,
                sessionId: record.sessionId,
                cwd: record.cwd,
                startedAt: record.startedAt,
                alive: true,
                tool: "open_code",
                taskTitle: record.taskTitle,
                taskSummary: record.taskSummary
            )

            if let existing = sessionsByID[record.sessionId] {
                if session.startedAt >= existing.startedAt {
                    sessionsByID[record.sessionId] = session
                }
            } else {
                sessionsByID[record.sessionId] = session
            }
        }

        return Array(sessionsByID.values)
    }

    private func readOpenCodeProcesses() -> [OpenCodeProcess] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-a", "-c", "opencode", "-d", "cwd", "-Fn"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0,
              let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        else { return [] }

        var results: [OpenCodeProcess] = []
        var pid: Int?
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            if line.hasPrefix("p") {
                pid = Int(line.dropFirst())
                continue
            }
            if line.hasPrefix("n"), let currentPID = pid {
                let cwd = String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                if !cwd.isEmpty, kill(Int32(currentPID), 0) == 0 {
                    results.append(OpenCodeProcess(pid: currentPID, cwd: cwd))
                }
                pid = nil
            }
        }

        return results
    }

    private func readLatestOpenCodeSession(for cwd: String) -> OpenCodeSessionRecord? {
        let sql = [
            "select id, slug, directory, title, time_created",
            "from session",
            "where directory = \(quoteSQLite(cwd)) and time_archived is null",
            "order by time_updated desc",
            "limit 1;"
        ].joined(separator: " ")

        guard let output = runSQLite(sql: sql) else { return nil }
        let columns = output.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard columns.count >= 5 else { return nil }

        let sessionId = columns[0]
        let slug = columns[1]
        let directory = columns[2]
        let startedAt = Int(columns[4]) ?? 0
        guard !sessionId.isEmpty, !directory.isEmpty, startedAt > 0 else { return nil }

        let taskTitle = openCodeTaskTitle(title: columns[3], slug: slug)
        let messages = readOpenCodeMessages(sessionId: sessionId)

        return OpenCodeSessionRecord(
            sessionId: sessionId,
            cwd: directory,
            startedAt: startedAt,
            taskTitle: taskTitle,
            taskSummary: openCodeTaskSummary(messages: messages, fallback: taskTitle)
        )
    }

    private func readOpenCodeMessages(sessionId: String, limit: Int = 8) -> [[String: Any]] {
        let sql = [
            "select data",
            "from message",
            "where session_id = \(quoteSQLite(sessionId))",
            "order by time_updated desc",
            "limit \(limit);"
        ].joined(separator: " ")

        guard let output = runSQLiteMultiline(sql: sql) else { return [] }
        return output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { raw in
                guard let data = raw.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return nil }
                return json
            }
    }

    private func openCodeTaskTitle(title rawTitle: String?, slug rawSlug: String?) -> String? {
        let title = sanitizeTaskText(rawTitle)
        if let title, !title.hasPrefix("New session - ") {
            return title
        }
        return sanitizeTaskText(rawSlug)
    }

    private func openCodeTaskSummary(messages: [[String: Any]], fallback: String?) -> String? {
        if let userMessage = messages.first(where: { ($0["role"] as? String) == "user" }) {
            if let summary = extractText(from: userMessage["summary"]) {
                return summary
            }
            if let summary = extractText(from: userMessage["content"] ?? userMessage["message"]) {
                return summary
            }
        }

        if let latestMessage = messages.first,
           let summary = extractText(from: latestMessage["summary"]) {
            return summary
        }

        return sanitizeTaskText(fallback)
    }

    // MARK: - Helpers

    private func runSQLite(sql: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-separator", "\t", openCodeDB, sql]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0,
              let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty
        else { return nil }

        return output
    }

    private func runSQLiteMultiline(sql: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [openCodeDB, sql]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0,
              let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty
        else { return nil }

        return output
    }

    private func quoteSQLite(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "''"))'"
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
            let joined = array.compactMap { item -> String? in
                if let text = item as? String {
                    return text
                }
                if let dict = item as? [String: Any] {
                    return extractText(from: dict["text"] ?? dict["content"] ?? dict["message"])
                }
                return nil
            }.joined(separator: " ")
            return sanitizeTaskText(joined)
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
        guard squashed.count <= 120 else {
            return String(squashed.prefix(117)) + "..."
        }
        return squashed
    }
}
