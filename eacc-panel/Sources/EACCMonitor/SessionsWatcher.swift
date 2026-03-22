import Foundation

// MARK: - ~/.claude/sessions/ directory watcher
// Distinct from SessionMonitor.swift which reads ~/.claude/projects/**/*.jsonl
// This reads ~/.claude/sessions/*.json for pid/sessionId/cwd/startedAt

final class SessionsWatcher: @unchecked Sendable {
    private let sessionsDir: String
    private let queue = DispatchQueue(label: "sessions.watcher", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var debounceWork: DispatchWorkItem?

    var onChange: (([EACCSessionInfo]) -> Void)?

    init() {
        self.sessionsDir = NSHomeDirectory() + "/.claude/sessions"
    }

    // MARK: - Lifecycle

    func start() {
        // Initial read
        readAndNotify()

        // Watch directory
        startWatching()
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    // MARK: - Directory watching

    private func startWatching() {
        let fm = FileManager.default
        // Ensure directory exists
        if !fm.fileExists(atPath: sessionsDir) {
            try? fm.createDirectory(atPath: sessionsDir, withIntermediateDirectories: true)
        }

        let fd = Darwin.open(sessionsDir, O_EVTONLY)
        guard fd >= 0 else {
            queue.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.startWatching()
            }
            return
        }
        fileDescriptor = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: queue
        )

        src.setEventHandler { [weak self] in
            self?.debouncedRead()
        }

        src.setCancelHandler {
            Darwin.close(fd)
        }

        fileDescriptor = -1
        source = src
        src.resume()
    }

    private func debouncedRead() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.readAndNotify()
        }
        debounceWork = work
        queue.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func readAndNotify() {
        let sessions = readSessions()
        onChange?(sessions)
    }

    // MARK: - Session reading (matches claude-sessions.ts)

    private func readSessions() -> [EACCSessionInfo] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: sessionsDir) else { return [] }

        var sessions: [EACCSessionInfo] = []
        for file in files where file.hasSuffix(".json") {
            let path = sessionsDir + "/" + file
            guard let data = fm.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            // Validate required fields
            guard let pid = json["pid"] as? Int,
                  let sessionId = json["sessionId"] as? String,
                  let cwd = json["cwd"] as? String,
                  let startedAt = json["startedAt"] as? Int
            else { continue }

            // PID alive check (Darwin signal 0)
            let alive = kill(Int32(pid), 0) == 0

            guard alive else { continue }

            sessions.append(EACCSessionInfo(
                pid: pid,
                sessionId: sessionId,
                cwd: cwd,
                startedAt: startedAt,
                alive: alive
            ))
        }

        return sessions
    }
}
