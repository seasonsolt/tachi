import Foundation

// MARK: - Recipe execution engine
// Loads collector recipes and produces EACCSourceData for each.

final class RecipeRuntime: @unchecked Sendable {
    private let queue = DispatchQueue(label: "recipe.runtime", qos: .utility)
    private let lock = NSLock()
    private var activeCollectors: [String: RecipeCollector] = [:]

    /// Called when a recipe's data updates
    var onSourceUpdate: ((String, EACCSourceData) -> Void)?

    // MARK: - Lifecycle

    /// Load all recipes and start enabled ones
    func start() {
        RecipeStore.installDefaults()
        let recipes = RecipeStore.loadAll()
        for recipe in recipes where recipe.enabled {
            startCollector(for: recipe)
        }
    }

    /// Stop all collectors
    func stop() {
        lock.lock()
        let collectors = activeCollectors
        activeCollectors.removeAll()
        lock.unlock()

        for (_, collector) in collectors {
            collector.stop()
        }
    }

    /// Add a new recipe at runtime
    func addRecipe(_ recipe: CollectorRecipe) {
        RecipeStore.save(recipe)
        if recipe.enabled {
            startCollector(for: recipe)
        }
    }

    /// Remove a recipe
    func removeRecipe(id: String) {
        lock.lock()
        let collector = activeCollectors.removeValue(forKey: id)
        lock.unlock()

        collector?.stop()
        RecipeStore.delete(id: id)
    }

    /// Get current data for a recipe
    func getData(for recipeId: String) -> EACCSourceData? {
        lock.lock()
        defer { lock.unlock() }
        return activeCollectors[recipeId]?.lastData
    }

    /// Get all active source data
    func getAllData() -> [String: EACCSourceData] {
        lock.lock()
        defer { lock.unlock() }
        var result: [String: EACCSourceData] = [:]
        for (id, collector) in activeCollectors {
            result[id] = collector.lastData
        }
        return result
    }

    // MARK: - Private

    private func startCollector(for recipe: CollectorRecipe) {
        let collector = RecipeCollector(recipe: recipe, queue: queue)
        lock.lock()
        // Stop existing collector for this ID if any
        activeCollectors[recipe.id]?.stop()
        activeCollectors[recipe.id] = collector
        lock.unlock()

        collector.start { [weak self] data in
            guard let self else { return }
            self.lock.lock()
            self.activeCollectors[recipe.id]?.lastData = data
            self.lock.unlock()
            self.onSourceUpdate?(recipe.id, data)
        }
    }
}

// MARK: - Single recipe collector

private final class RecipeCollector: @unchecked Sendable {
    let recipe: CollectorRecipe
    var lastData: EACCSourceData = .empty
    private var timer: DispatchSourceTimer?
    private var fileSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let queue: DispatchQueue

    init(recipe: CollectorRecipe, queue: DispatchQueue) {
        self.recipe = recipe
        self.queue = queue
    }

    func start(onUpdate: @escaping (EACCSourceData) -> Void) {
        switch recipe.type {
        case .apiPoll:
            startPolling(onUpdate: onUpdate)
        case .fileWatch:
            startFileWatch(onUpdate: onUpdate)
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        fileSource?.cancel()
        fileSource = nil
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    // MARK: - API Polling

    private func startPolling(onUpdate: @escaping (EACCSourceData) -> Void) {
        let intervalMs = recipe.pollIntervalMs ?? 60000
        let intervalSec = Double(intervalMs) / 1000.0

        let src = DispatchSource.makeTimerSource(queue: queue)
        src.schedule(deadline: .now(), repeating: intervalSec)
        src.setEventHandler { [weak self] in
            self?.poll(onUpdate: onUpdate)
        }
        timer = src
        src.resume()
    }

    private func poll(onUpdate: @escaping (EACCSourceData) -> Void) {
        guard let endpoint = recipe.endpoint,
              let url = URL(string: endpoint)
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = recipe.method ?? "GET"
        request.timeoutInterval = 30

        // Auth
        if let authType = recipe.authType, let keyValue = recipe.authKeyValue {
            switch authType {
            case .bearer:
                request.setValue("Bearer \(keyValue)", forHTTPHeaderField: "Authorization")
            case .header:
                request.setValue(keyValue, forHTTPHeaderField: "x-api-key")
            case .none:
                break
            }
        }

        // Extra headers
        if let headers = recipe.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                NSLog("[RecipeRuntime] Poll error for \(self.recipe.id): \(error.localizedDescription)")
                let errorData = EACCSourceData(
                    connected: false, totalTokens: self.lastData.totalTokens,
                    todayTokens: self.lastData.todayTokens, monthTokens: self.lastData.monthTokens,
                    costUSD: self.lastData.costUSD, todayCostUSD: self.lastData.todayCostUSD,
                    monthCostUSD: self.lastData.monthCostUSD, inputTokens: self.lastData.inputTokens,
                    outputTokens: self.lastData.outputTokens, lastUpdated: self.lastData.lastUpdated
                )
                onUpdate(errorData)
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data)
            else {
                NSLog("[RecipeRuntime] Parse error for \(self.recipe.id)")
                return
            }

            let sourceData = self.extractSourceData(from: json)
            onUpdate(sourceData)
        }
        task.resume()
    }

    private func extractSourceData(from json: Any) -> EACCSourceData {
        let totalTokens: Int
        if let path = recipe.extractTotalTokens {
            totalTokens = Self.extractInt(from: json, path: path)
        } else {
            totalTokens = 0
        }

        let costUSD: Double
        if let path = recipe.extractCostUSD {
            costUSD = Self.extractDouble(from: json, path: path)
        } else {
            costUSD = 0
        }

        let inputTokens: Int
        if let path = recipe.extractInputTokens {
            inputTokens = Self.extractInt(from: json, path: path)
        } else {
            inputTokens = 0
        }

        let outputTokens: Int
        if let path = recipe.extractOutputTokens {
            outputTokens = Self.extractInt(from: json, path: path)
        } else {
            outputTokens = 0
        }

        let todayTokens: Int
        if let path = recipe.extractTodayTokens {
            todayTokens = Self.extractInt(from: json, path: path)
        } else {
            todayTokens = 0
        }

        let monthTokens: Int
        if let path = recipe.extractMonthTokens {
            monthTokens = Self.extractInt(from: json, path: path)
        } else {
            monthTokens = 0
        }

        return EACCSourceData(
            connected: true,
            totalTokens: totalTokens,
            todayTokens: todayTokens,
            monthTokens: monthTokens,
            costUSD: costUSD,
            todayCostUSD: 0,
            monthCostUSD: 0,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            lastUpdated: Int(Date().timeIntervalSince1970 * 1000)
        )
    }

    // MARK: - File Watching

    private func startFileWatch(onUpdate: @escaping (EACCSourceData) -> Void) {
        guard let rawPath = recipe.watchPath else { return }
        let path = rawPath.replacingOccurrences(of: "~", with: NSHomeDirectory())

        // Initial read
        readFileAndNotify(path: path, onUpdate: onUpdate)

        // Watch for changes
        watchFile(path: path, onUpdate: onUpdate)
    }

    private func watchFile(path: String, onUpdate: @escaping (EACCSourceData) -> Void) {
        let fd = Darwin.open(path, O_EVTONLY)
        guard fd >= 0 else {
            // File doesn't exist yet — retry
            queue.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.watchFile(path: path, onUpdate: onUpdate)
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
                // File was replaced — re-open watcher
                self.stop()
                self.queue.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.startFileWatch(onUpdate: onUpdate)
                }
                return
            }
            self.readFileAndNotify(path: path, onUpdate: onUpdate)
        }

        src.setCancelHandler {
            Darwin.close(fd)
        }

        fileDescriptor = -1 // cancel handler will close
        fileSource = src
        src.resume()
    }

    private func readFileAndNotify(path: String, onUpdate: @escaping (EACCSourceData) -> Void) {
        guard let parseScript = recipe.parseScript else { return }

        switch parseScript {
        case "claude-code-stats":
            guard let data = FileManager.default.contents(atPath: path),
                  let parsed = StatsWatcher.parseStats(data: data)
            else { return }
            onUpdate(parsed)
        default:
            NSLog("[RecipeRuntime] Unknown parseScript: \(parseScript)")
        }
    }

    // MARK: - JSONPath-like extraction

    /// Extract a value from JSON using a simple path expression.
    /// Supports: $.key.nested, $.array[*].field (sums), addition with +
    static func extractValue(from json: Any, path: String) -> Any? {
        // Handle addition expressions: "$.a[*].x + $.a[*].y"
        if path.contains(" + ") {
            let parts = path.components(separatedBy: " + ")
            var sum = 0.0
            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                if let val = extractValue(from: json, path: trimmed) {
                    if let n = val as? Int { sum += Double(n) }
                    else if let n = val as? Double { sum += n }
                }
            }
            return sum
        }

        // Strip leading "$."
        var components = path.components(separatedBy: ".")
        if components.first == "$" {
            components.removeFirst()
        } else if components.first?.hasPrefix("$") == true {
            components[0] = String(components[0].dropFirst())
        }

        var current: Any = json
        for component in components {
            if component.hasSuffix("[*]") {
                // Array wildcard — get the field name after removing [*]
                let arrayKey = String(component.dropLast(3))
                if !arrayKey.isEmpty {
                    guard let dict = current as? [String: Any],
                          let arr = dict[arrayKey] as? [Any]
                    else { return nil }
                    current = arr
                } else {
                    // [*] alone means current is already an array
                    guard current is [Any] else { return nil }
                }
            } else if let dict = current as? [String: Any] {
                guard let next = dict[component] else { return nil }
                current = next
            } else if let arr = current as? [Any] {
                // Sum numeric field across array elements
                var sum = 0.0
                for item in arr {
                    if let dict = item as? [String: Any],
                       let val = dict[component] {
                        if let n = val as? Int { sum += Double(n) }
                        else if let n = val as? Double { sum += n }
                    }
                }
                return sum
            } else {
                return nil
            }
        }

        return current
    }

    static func extractInt(from json: Any, path: String) -> Int {
        guard let val = extractValue(from: json, path: path) else { return 0 }
        if let n = val as? Int { return n }
        if let n = val as? Double { return Int(n) }
        return 0
    }

    static func extractDouble(from json: Any, path: String) -> Double {
        guard let val = extractValue(from: json, path: path) else { return 0 }
        if let n = val as? Double { return n }
        if let n = val as? Int { return Double(n) }
        return 0
    }
}
