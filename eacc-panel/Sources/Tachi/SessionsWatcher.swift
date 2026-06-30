import Foundation

// MARK: - Session watcher for provider-backed coding sessions

final class SessionsWatcher: @unchecked Sendable {
    private let queue = DispatchQueue(label: "sessions.watcher", qos: .utility)
    private let sessionMonitor: SessionMonitor
    private var sources: [DispatchSourceFileSystemObject] = []
    private var debounceWork: DispatchWorkItem?
    private var retryWork: DispatchWorkItem?
    private var pollTimer: DispatchSourceTimer?

    var onChange: (([EACCSessionInfo]) -> Void)?

    init(sessionMonitor: SessionMonitor = .shared) {
        self.sessionMonitor = sessionMonitor
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

        let watchPaths = existingWatchPaths()
        guard !watchPaths.isEmpty else {
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
        let home = NSHomeDirectory()
        let candidates = [
            home + "/.claude/projects",
            home + "/.claude/sessions",
            home + "/.codex/session_index.jsonl",
            home + "/.codex/sessions",
            home + "/.local/share/opencode",
            home + "/.local/share/opencode/opencode.db",
            home + "/.local/share/opencode/opencode.db-wal",
            home + "/Library/Application Support/Pencil"
        ]

        return Array(Set(candidates.filter { FileManager.default.fileExists(atPath: $0) }))
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
        let sessions = sessionMonitor.scanSessions().map(EACCSessionInfo.init(session:))
        onChange?(sessions)
    }
}
