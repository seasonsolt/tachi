import Foundation

// MARK: - Watches ~/.ritual-screen/theme.json for cross-process theme sync

final class ThemeWatcher: @unchecked Sendable {
    private let themePath: String
    private let queue = DispatchQueue(label: "theme.watcher", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    /// Called with the theme name string whenever theme.json changes
    var onChange: ((String) -> Void)?

    init() {
        let dir = NSHomeDirectory() + "/.ritual-screen"
        self.themePath = dir + "/theme.json"
    }

    // MARK: - Lifecycle

    func start() {
        ensureDirectory()
        readAndNotify()
        startWatching()
    }

    func stop() {
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    // MARK: - Write theme (called when macOS app changes theme)

    func writeTheme(_ theme: String) {
        ensureDirectory()
        let json = "{\"theme\":\"\(theme)\"}\n"
        queue.async {
            try? json.write(toFile: self.themePath, atomically: true, encoding: .utf8)
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

    // MARK: - File watching (same pattern as StatsWatcher)

    private func startWatching() {
        let fd = Darwin.open(themePath, O_EVTONLY)
        guard fd >= 0 else {
            // File doesn't exist yet, poll periodically
            queue.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.startWatching()
            }
            return
        }
        fileDescriptor = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = src.data
            if flags.contains(.delete) || flags.contains(.rename) {
                // File was replaced (atomic write) — re-open watcher
                self.stop()
                self.queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.start()
                }
                return
            }
            self.readAndNotify()
        }

        src.setCancelHandler {
            Darwin.close(fd)
        }

        // Prevent close in stop() since the cancel handler will do it
        fileDescriptor = -1
        source = src
        src.resume()
    }

    private func readAndNotify() {
        guard let theme = readTheme() else { return }
        onChange?(theme)
    }

    private func ensureDirectory() {
        let dir = NSHomeDirectory() + "/.ritual-screen"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }
}
