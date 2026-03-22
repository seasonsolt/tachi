import Foundation

// MARK: - Watches ~/.eacc/theme.json for cross-process theme sync
// Uses mtime polling (1s) instead of kqueue/DispatchSource because
// Node.js writeFileSync (O_TRUNC) doesn't reliably trigger kqueue .write events.

final class ThemeWatcher: @unchecked Sendable {
    private let themePath: String
    private let queue = DispatchQueue(label: "theme.watcher", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var lastMtime: TimeInterval = 0
    private var lastTheme: String?

    /// Called with the theme name string whenever theme.json changes
    var onChange: ((String) -> Void)?

    init() {
        let dir = NSHomeDirectory() + "/.eacc"
        self.themePath = dir + "/theme.json"
        Self.migrateIfNeeded()
    }

    // MARK: - Lifecycle

    func start() {
        ensureDirectory()
        // Read initial state
        if let theme = readTheme() {
            lastTheme = theme
            lastMtime = fileMtime() ?? 0
            onChange?(theme)
        }
        startPolling()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Write theme (called when macOS app changes theme)

    func writeTheme(_ theme: String) {
        ensureDirectory()
        let json = "{\"theme\":\"\(theme)\"}\n"
        queue.async { [self] in
            try? json.write(toFile: themePath, atomically: true, encoding: .utf8)
            // Update our tracking so we don't re-notify for our own write
            lastMtime = fileMtime() ?? 0
            lastTheme = theme
        }
    }

    // MARK: - Read current theme

    func readTheme() -> String? {
        guard let data = FileManager.default.contents(atPath: themePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let theme = json["theme"] as? String
        else { return nil }
        return theme
    }

    // MARK: - Polling (1s interval, compare mtime)

    private func startPolling() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 1, repeating: 1.0)
        t.setEventHandler { [weak self] in
            self?.checkForChanges()
        }
        timer = t
        t.resume()
    }

    private func checkForChanges() {
        guard let mtime = fileMtime() else { return }
        guard mtime != lastMtime else { return }
        lastMtime = mtime

        guard let theme = readTheme(), theme != lastTheme else { return }
        lastTheme = theme
        onChange?(theme)
    }

    private func fileMtime() -> TimeInterval? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: themePath),
              let date = attrs[.modificationDate] as? Date
        else { return nil }
        return date.timeIntervalSince1970
    }

    private func ensureDirectory() {
        let dir = NSHomeDirectory() + "/.eacc"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    /// One-time migration: copy files from ~/.ritual-screen/ to ~/.eacc/ if the new dir doesn't exist
    private static func migrateIfNeeded() {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let oldDir = home + "/.ritual-screen"
        let newDir = home + "/.eacc"

        guard fm.fileExists(atPath: oldDir), !fm.fileExists(atPath: newDir) else { return }

        try? fm.createDirectory(atPath: newDir, withIntermediateDirectories: true)
        if let files = try? fm.contentsOfDirectory(atPath: oldDir) {
            for file in files {
                try? fm.copyItem(atPath: oldDir + "/" + file, toPath: newDir + "/" + file)
            }
        }
    }
}
