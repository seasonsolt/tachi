import Foundation

// MARK: - Recipe execution engine
// Loads collector recipes and produces EACCSourceData for each.

final class RecipeRuntime: @unchecked Sendable {
    private let queue = DispatchQueue(label: "recipe.runtime", qos: .utility)
    private let lock = NSLock()
    private var activeCollectors: [String: RecipeCollector] = [:]

    /// Called when a recipe's data updates (supports multiple listeners)
    private var sourceUpdateHandlers: [(String, EACCSourceData) -> Void] = []

    func addSourceUpdateHandler(_ handler: @escaping (String, EACCSourceData) -> Void) {
        lock.lock()
        sourceUpdateHandlers.append(handler)
        lock.unlock()
    }

    /// Legacy single-callback setter (for backward compat)
    var onSourceUpdate: ((String, EACCSourceData) -> Void)? {
        didSet {
            if let handler = onSourceUpdate {
                lock.lock()
                sourceUpdateHandlers.append(handler)
                lock.unlock()
            }
        }
    }

    private func notifySourceUpdate(id: String, data: EACCSourceData) {
        lock.lock()
        let handlers = sourceUpdateHandlers
        lock.unlock()
        for handler in handlers {
            handler(id, data)
        }
    }

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
            self.notifySourceUpdate(id: recipe.id, data: data)
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

        // Build base request
        func makeRequest(bodyOverride: String? = nil) -> URLRequest {
            var req = URLRequest(url: url)
            req.httpMethod = recipe.method ?? "GET"
            req.timeoutInterval = 30
            if let authType = recipe.authType, let keyValue = recipe.authKeyValue {
                switch authType {
                case .bearer: req.setValue("Bearer \(keyValue)", forHTTPHeaderField: "Authorization")
                case .header: req.setValue(keyValue, forHTTPHeaderField: "x-api-key")
                case .none: break
                }
            }
            if let headers = recipe.headers {
                for (key, value) in headers { req.setValue(value, forHTTPHeaderField: key) }
            }
            let body = bodyOverride ?? recipe.body
            if let body, !body.isEmpty { req.httpBody = body.data(using: .utf8) }
            return req
        }

        // If recipe has todayBody/monthBody, do 3 parallel requests
        let hasPeriods = recipe.todayBody != nil || recipe.monthBody != nil

        if hasPeriods {
            let group = DispatchGroup()
            var totalData: EACCSourceData = .empty
            var todayTokens = 0, todayCost = 0.0
            var monthTokens = 0, monthCost = 0.0

            // Main request (alltime)
            group.enter()
            URLSession.shared.dataTask(with: makeRequest()) { [weak self] data, _, error in
                defer { group.leave() }
                guard let self, error == nil, let data,
                      let json = try? JSONSerialization.jsonObject(with: data) else { return }
                totalData = self.extractSourceData(from: json)
            }.resume()

            // Today request
            if let todayBody = recipe.todayBody {
                group.enter()
                URLSession.shared.dataTask(with: makeRequest(bodyOverride: todayBody)) { data, _, error in
                    defer { group.leave() }
                    guard error == nil, let data,
                          let json = try? JSONSerialization.jsonObject(with: data) else { return }
                    let (tokens, cost) = Self.sumModelArray(json)
                    todayTokens = tokens; todayCost = cost
                }.resume()
            }

            // Month request
            if let monthBody = recipe.monthBody {
                group.enter()
                URLSession.shared.dataTask(with: makeRequest(bodyOverride: monthBody)) { data, _, error in
                    defer { group.leave() }
                    guard error == nil, let data,
                          let json = try? JSONSerialization.jsonObject(with: data) else { return }
                    let (tokens, cost) = Self.sumModelArray(json)
                    monthTokens = tokens; monthCost = cost
                }.resume()
            }

            group.notify(queue: queue) {
                let merged = EACCSourceData(
                    connected: totalData.connected,
                    totalTokens: totalData.totalTokens,
                    todayTokens: todayTokens,
                    monthTokens: monthTokens,
                    costUSD: totalData.costUSD,
                    todayCostUSD: todayCost,
                    monthCostUSD: monthCost,
                    inputTokens: totalData.inputTokens,
                    outputTokens: totalData.outputTokens,
                    lastUpdated: Int(Date().timeIntervalSince1970 * 1000)
                )
                onUpdate(merged)
            }
        } else {
            // Simple single request
            URLSession.shared.dataTask(with: makeRequest()) { [weak self] data, _, error in
                guard let self else { return }
                if let error {
                    NSLog("[RecipeRuntime] Poll error for \(self.recipe.id): \(error.localizedDescription)")
                    onUpdate(EACCSourceData(
                        connected: false, totalTokens: self.lastData.totalTokens,
                        todayTokens: self.lastData.todayTokens, monthTokens: self.lastData.monthTokens,
                        costUSD: self.lastData.costUSD, todayCostUSD: self.lastData.todayCostUSD,
                        monthCostUSD: self.lastData.monthCostUSD, inputTokens: self.lastData.inputTokens,
                        outputTokens: self.lastData.outputTokens, lastUpdated: self.lastData.lastUpdated
                    ))
                    return
                }
                guard let data, let json = try? JSONSerialization.jsonObject(with: data) else { return }
                onUpdate(self.extractSourceData(from: json))
            }.resume()
        }
    }

    /// Sum tokens and cost from a model-stats array response: { data: [{ allTokens, costs: { total } }] }
    private static func sumModelArray(_ json: Any) -> (tokens: Int, cost: Double) {
        guard let root = json as? [String: Any],
              let arr = root["data"] as? [[String: Any]]
        else { return (0, 0) }
        var tokens = 0, cost = 0.0
        for model in arr {
            tokens += (model["allTokens"] as? Int) ?? 0
            if let costs = model["costs"] as? [String: Any] {
                cost += (costs["total"] as? Double) ?? 0
            }
        }
        return (tokens, cost)
    }

    private func extractSourceData(from json: Any) -> EACCSourceData {
        // Auto-detect model-stats array response: { data: [{ allTokens, costs }] }
        if let root = json as? [String: Any], let arr = root["data"] as? [[String: Any]], !arr.isEmpty,
           arr[0]["allTokens"] != nil || arr[0]["costs"] != nil {
            let (tokens, cost) = Self.sumModelArray(json)
            var input = 0, output = 0
            for m in arr {
                input += (m["inputTokens"] as? Int) ?? 0
                output += (m["outputTokens"] as? Int) ?? 0
            }
            return EACCSourceData(
                connected: true, totalTokens: tokens, todayTokens: 0, monthTokens: 0,
                costUSD: cost, todayCostUSD: 0, monthCostUSD: 0,
                inputTokens: input, outputTokens: output,
                lastUpdated: Int(Date().timeIntervalSince1970 * 1000)
            )
        }

        // Standard JSONPath extraction
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

        // For directory-scanning parsers (codex-sessions), use timer instead of file watch
        if recipe.parseScript == "codex-sessions" {
            readFileAndNotify(path: path, onUpdate: onUpdate)
            let interval = Double(recipe.pollIntervalMs ?? 120000) / 1000.0
            let src = DispatchSource.makeTimerSource(queue: queue)
            src.schedule(deadline: .now() + interval, repeating: interval)
            src.setEventHandler { [weak self] in
                self?.readFileAndNotify(path: path, onUpdate: onUpdate)
            }
            timer = src
            src.resume()
            return
        }

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
        case "codex-sessions":
            let data = Self.scanCodexSessions()
            onUpdate(data)
        default:
            NSLog("[RecipeRuntime] Unknown parseScript: \(parseScript)")
        }
    }

    // MARK: - Codex session scanner

    /// Scan all Codex session .jsonl files and sum up token usage.
    /// Each session's last `total_token_usage` entry gives that session's total.
    private static func scanCodexSessions() -> EACCSourceData {
        let home = NSHomeDirectory()
        let sessionsDir = home + "/.codex/sessions"
        let archivedDir = home + "/.codex/archived_sessions"
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-90 * 24 * 60 * 60)
        let maxFiles = 256

        var files: [(path: String, modified: Date)] = []
        if let enumerator = fm.enumerator(atPath: sessionsDir) {
            while let file = enumerator.nextObject() as? String {
                guard file.hasSuffix(".jsonl") else { continue }
                let path = sessionsDir + "/" + file
                guard let modified = modificationDate(at: path, fileManager: fm),
                      modified >= cutoff
                else { continue }
                files.append((path: path, modified: modified))
            }
        }
        if let archived = try? fm.contentsOfDirectory(atPath: archivedDir) {
            for f in archived where f.hasSuffix(".jsonl") {
                let path = archivedDir + "/" + f
                guard let modified = modificationDate(at: path, fileManager: fm),
                      modified >= cutoff
                else { continue }
                files.append((path: path, modified: modified))
            }
        }

        let today = Self.todayString()
        let month = String(today.prefix(7))

        var totalTokens = 0, todayTokens = 0, monthTokens = 0
        var totalInput = 0, totalOutput = 0

        for file in files.sorted(by: { $0.modified > $1.modified }).prefix(maxFiles) {
            guard let content = tailString(path: file.path, maxBytes: 262_144) else { continue }

            var sessionDate: String?
            var lastTotal = 0, lastInput = 0, lastOutput = 0

            for line in content.split(separator: "\n") {
                guard !line.isEmpty,
                      let entry = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
                else { continue }

                // Get session date from first entry's timestamp
                if sessionDate == nil, let ts = entry["timestamp"] as? String, ts.count >= 10 {
                    sessionDate = String(ts.prefix(10))
                }

                // Look for total_token_usage in payload.info
                if let payload = entry["payload"] as? [String: Any],
                   let info = payload["info"] as? [String: Any],
                   let usage = info["total_token_usage"] as? [String: Any] {
                    lastTotal = (usage["total_tokens"] as? Int) ?? 0
                    lastInput = (usage["input_tokens"] as? Int) ?? 0
                    lastOutput = (usage["output_tokens"] as? Int) ?? 0
                }
            }

            totalTokens += lastTotal
            totalInput += lastInput
            totalOutput += lastOutput
            if let d = sessionDate {
                if d == today { todayTokens += lastTotal }
                if d.hasPrefix(month) { monthTokens += lastTotal }
            }
        }

        // Estimate cost using OpenAI pricing (codex uses OpenAI models)
        // Approximate: $2.50/1M input, $10/1M output for GPT-4.1
        let costUSD = Double(totalInput) * 2.5 / 1_000_000.0 + Double(totalOutput) * 10.0 / 1_000_000.0
        let todayCost = Double(todayTokens) * 5.0 / 1_000_000.0  // blended rate
        let monthCost = Double(monthTokens) * 5.0 / 1_000_000.0

        return EACCSourceData(
            connected: true,
            totalTokens: totalTokens,
            todayTokens: todayTokens,
            monthTokens: monthTokens,
            costUSD: costUSD,
            todayCostUSD: todayCost,
            monthCostUSD: monthCost,
            inputTokens: totalInput,
            outputTokens: totalOutput,
            lastUpdated: Int(Date().timeIntervalSince1970 * 1000)
        )
    }

    private static func modificationDate(at path: String, fileManager: FileManager) -> Date? {
        (try? fileManager.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    private static func tailString(path: String, maxBytes: UInt64) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { handle.closeFile() }

        let size = handle.seekToEndOfFile()
        guard size > 0 else { return "" }

        let readSize = min(size, maxBytes)
        handle.seek(toFileOffset: size - readSize)
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
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
