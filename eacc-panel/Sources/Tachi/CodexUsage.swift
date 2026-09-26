import Foundation

struct CodexModelUsage: Sendable, Equatable, Identifiable {
    let model: String
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let costUSD: Double

    var id: String { model }
    var totalTokens: Int { inputTokens + outputTokens }
}

struct CodexUsageWindow: Sendable, Equatable {
    var costUSD: Double = 0
    var totalTokens: Int = 0
    var models: [CodexModelUsage] = []
}

struct CodexUsageSnapshot: Sendable, Equatable {
    var today = CodexUsageWindow()
    var month = CodexUsageWindow()
    var recent = CodexUsageWindow()
    var isTruncated = false

    var sourceData: EACCSourceData {
        EACCSourceData(
            connected: true,
            totalTokens: recent.totalTokens,
            todayTokens: today.totalTokens,
            monthTokens: month.totalTokens,
            costUSD: recent.costUSD,
            todayCostUSD: today.costUSD,
            monthCostUSD: month.costUSD,
            inputTokens: recent.models.reduce(0) { $0 + $1.inputTokens },
            outputTokens: recent.models.reduce(0) { $0 + $1.outputTokens },
            lastUpdated: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
}

struct CodexUsageEntry: Sendable, Equatable {
    let model: String
    let timestamp: Date
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
}

enum CodexUsageAggregator {
    private struct CachedFile {
        let modified: Date
        let size: Int
        let entries: [CodexUsageEntry]
        let isTruncated: Bool
    }

    private final class FileCache: @unchecked Sendable {
        private let lock = NSLock()
        private var files: [String: CachedFile] = [:]

        func value(path: String, modified: Date, size: Int) -> CachedFile? {
            lock.lock()
            defer { lock.unlock() }
            guard let value = files[path], value.modified == modified, value.size == size else { return nil }
            return value
        }

        func store(_ value: CachedFile, path: String) {
            lock.lock()
            files[path] = value
            lock.unlock()
        }
    }

    private static let fileCache = FileCache()
    private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dateFormatter = ISO8601DateFormatter()

    struct ModelPricing: Sendable, Equatable {
        let input: Double
        let cachedInput: Double
        let output: Double
    }

    static func pricing(for model: String) -> ModelPricing {
        let lower = model.lowercased()
        if lower.contains("gpt-5.4-mini") {
            return ModelPricing(input: 0.75, cachedInput: 0.075, output: 4.5)
        }
        if lower.contains("gpt-5.4") {
            return ModelPricing(input: 2.5, cachedInput: 0.25, output: 15)
        }
        if lower.contains("gpt-5.3-codex") || lower.contains("gpt-5.2") {
            return ModelPricing(input: 1.75, cachedInput: 0.175, output: 14)
        }
        if lower.contains("codex-mini") {
            return ModelPricing(input: 1.5, cachedInput: 0.375, output: 6)
        }
        if lower.contains("gpt-5-codex") || lower == "gpt-5" {
            return ModelPricing(input: 1.25, cachedInput: 0.125, output: 10)
        }
        // Models without a published API price use the current general-purpose
        // GPT-5.4 rate as a transparent local estimate.
        return ModelPricing(input: 2.5, cachedInput: 0.25, output: 15)
    }

    static func aggregate(
        entries: [CodexUsageEntry],
        now: Date,
        isTruncated: Bool = false
    ) -> CodexUsageSnapshot {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let recentCutoff = now.addingTimeInterval(-90 * 86_400)

        return CodexUsageSnapshot(
            today: window(from: entries.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }),
            month: window(from: entries.filter { $0.timestamp >= monthStart }),
            recent: window(from: entries.filter { $0.timestamp >= recentCutoff }),
            isTruncated: isTruncated
        )
    }

    static func parseLines(
        _ lines: [String],
        fallbackDate: Date,
        initialModel: String? = nil,
        initialTimestamp: Date? = nil
    ) -> [CodexUsageEntry] {
        var currentModel = initialModel ?? "Unknown"
        var previousInput = 0
        var previousCachedInput = 0
        var previousOutput = 0
        var entries: [CodexUsageEntry] = []
        var isFirstTokenSnapshot = true

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = row["type"] as? String,
                  let payload = row["payload"] as? [String: Any]
            else { continue }

            if type == "turn_context", let model = payload["model"] as? String, !model.isEmpty {
                currentModel = model
                continue
            }

            guard type == "event_msg",
                  payload["type"] as? String == "token_count",
                  let info = payload["info"] as? [String: Any],
                  let total = info["total_token_usage"] as? [String: Any]
            else { continue }

            let input = intValue(total["input_tokens"])
            let cachedInput = intValue(total["cached_input_tokens"])
            let output = intValue(total["output_tokens"])
            let inputDelta = delta(current: input, previous: previousInput)
            let cachedDelta = min(inputDelta, delta(current: cachedInput, previous: previousCachedInput))
            let outputDelta = delta(current: output, previous: previousOutput)

            previousInput = input
            previousCachedInput = cachedInput
            previousOutput = output

            guard inputDelta > 0 || outputDelta > 0 else { continue }
            entries.append(CodexUsageEntry(
                model: isFirstTokenSnapshot ? (initialModel ?? currentModel) : currentModel,
                timestamp: isFirstTokenSnapshot
                    ? (initialTimestamp ?? parseDate(row["timestamp"]) ?? fallbackDate)
                    : (parseDate(row["timestamp"]) ?? fallbackDate),
                inputTokens: inputDelta,
                cachedInputTokens: cachedDelta,
                outputTokens: outputDelta
            ))
            isFirstTokenSnapshot = false
        }

        return entries
    }

    static func snapshot(codexHome: String = NSHomeDirectory() + "/.codex", now: Date = Date()) -> CodexUsageSnapshot {
        let fileManager = FileManager.default
        let roots = [codexHome + "/sessions", codexHome + "/archived_sessions"]
        let cutoff = now.addingTimeInterval(-90 * 86_400)
        var files: [(url: URL, modified: Date, size: Int)] = []

        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension == "jsonl" {
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                      let modified = values.contentModificationDate,
                      modified >= cutoff
                else { continue }
                files.append((url, modified, values.fileSize ?? 0))
            }
        }

        var entries: [CodexUsageEntry] = []
        var hasTruncatedFile = false
        for file in files.sorted(by: { $0.modified > $1.modified }).prefix(256) {
            if let cached = fileCache.value(path: file.url.path, modified: file.modified, size: file.size) {
                entries.append(contentsOf: cached.entries)
                hasTruncatedFile = hasTruncatedFile || cached.isTruncated
                continue
            }

            guard let tail = tailString(at: file.url, maxBytes: 262_144) else { continue }
            let context = sessionContext(
                from: headString(at: file.url, maxBytes: 32_768) ?? "",
                fallbackDate: file.modified
            )
            let parsed = parseLines(
                tail.content.split(separator: "\n").map(String.init),
                fallbackDate: file.modified,
                initialModel: context.model,
                initialTimestamp: context.timestamp
            )
            entries.append(contentsOf: parsed)
            hasTruncatedFile = hasTruncatedFile || tail.isTruncated
            fileCache.store(
                CachedFile(
                    modified: file.modified,
                    size: file.size,
                    entries: parsed,
                    isTruncated: tail.isTruncated
                ),
                path: file.url.path
            )
        }
        return aggregate(
            entries: entries,
            now: now,
            isTruncated: files.count > 256 || hasTruncatedFile
        )
    }

    private static func sessionContext(
        from content: String,
        fallbackDate: Date
    ) -> (model: String?, timestamp: Date) {
        var timestamp: Date?
        for line in content.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            timestamp = timestamp ?? parseDate(row["timestamp"])
            if row["type"] as? String == "turn_context",
               let payload = row["payload"] as? [String: Any],
               let model = payload["model"] as? String,
               !model.isEmpty {
                return (model, timestamp ?? fallbackDate)
            }
        }
        return (nil, timestamp ?? fallbackDate)
    }

    private static func headString(at url: URL, maxBytes: Int) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard var data = try? handle.read(upToCount: maxBytes) else { return nil }
        if data.count == maxBytes, let newline = data.lastIndex(of: 0x0A) {
            data = data.subdata(in: data.startIndex..<data.index(after: newline))
        }
        return String(data: data, encoding: .utf8)
    }

    private static func tailString(
        at url: URL,
        maxBytes: UInt64
    ) -> (content: String, isTruncated: Bool)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        guard size > 0 else { return ("", false) }
        let start = size > maxBytes ? size - maxBytes : 0
        try? handle.seek(toOffset: start)
        guard var data = try? handle.readToEnd() else { return nil }
        if start > 0, let newline = data.firstIndex(of: 0x0A) {
            data = data.subdata(in: data.index(after: newline)..<data.endIndex)
        }
        guard let content = String(data: data, encoding: .utf8) else { return nil }
        return (content, start > 0)
    }

    private static func window(from entries: [CodexUsageEntry]) -> CodexUsageWindow {
        struct Accumulator {
            var input = 0
            var cachedInput = 0
            var output = 0
        }

        var byModel: [String: Accumulator] = [:]
        for entry in entries {
            var value = byModel[entry.model] ?? Accumulator()
            value.input += entry.inputTokens
            value.cachedInput += entry.cachedInputTokens
            value.output += entry.outputTokens
            byModel[entry.model] = value
        }

        let models = byModel.map { model, value in
            let pricing = pricing(for: model)
            let uncachedInput = max(0, value.input - value.cachedInput)
            let cost = (Double(uncachedInput) * pricing.input
                + Double(value.cachedInput) * pricing.cachedInput
                + Double(value.output) * pricing.output) / 1_000_000
            return CodexModelUsage(
                model: model,
                inputTokens: value.input,
                cachedInputTokens: value.cachedInput,
                outputTokens: value.output,
                costUSD: cost
            )
        }
        .sorted { $0.costUSD > $1.costUSD }

        return CodexUsageWindow(
            costUSD: models.reduce(0) { $0 + $1.costUSD },
            totalTokens: models.reduce(0) { $0 + $1.totalTokens },
            models: models
        )
    }

    private static func delta(current: Int, previous: Int) -> Int {
        current >= previous ? current - previous : current
    }

    private static func intValue(_ raw: Any?) -> Int {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        return 0
    }

    private static func parseDate(_ raw: Any?) -> Date? {
        guard let string = raw as? String else { return nil }
        return fractionalDateFormatter.date(from: string) ?? dateFormatter.date(from: string)
    }
}
