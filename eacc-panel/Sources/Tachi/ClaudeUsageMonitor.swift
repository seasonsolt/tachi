import Foundation

// MARK: - Claude Code token-usage from per-session JSONL transcripts
//
// Claude Code writes one JSONL transcript per session under
// ~/.claude/projects/<encoded-project>/<sessionId>.jsonl (plus nested folders
// like .../subagents/*.jsonl). Each assistant turn is logged, and a SINGLE
// assistant message is written across 2–4 rows (one per content block) that ALL
// carry the SAME message-level `usage`. We therefore dedup by `message.id`,
// counting each message once, or tokens would be overcounted ~2.3x.

// MARK: - Value types

struct ClaudeModelUsage: Sendable, Equatable, Identifiable {
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let costUSD: Double

    var id: String { model }

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
}

struct ClaudeUsageWindow: Sendable, Equatable {
    var costUSD: Double = 0
    var totalTokens: Int = 0
    var models: [ClaudeModelUsage] = [] // sorted by costUSD desc
}

struct ClaudeUsageSnapshot: Sendable, Equatable {
    var today: ClaudeUsageWindow
    var week: ClaudeUsageWindow
    var month: ClaudeUsageWindow

    init(
        today: ClaudeUsageWindow = ClaudeUsageWindow(),
        week: ClaudeUsageWindow = ClaudeUsageWindow(),
        month: ClaudeUsageWindow = ClaudeUsageWindow()
    ) {
        self.today = today
        self.week = week
        self.month = month
    }
}

/// A single deduped assistant message's usage, extracted from a transcript line.
struct ClaudeUsageEntry: Sendable, Equatable {
    let messageId: String
    let model: String
    let timestamp: Date
    let input: Int
    let output: Int
    let cacheCreation: Int
    let cacheRead: Int
}

// MARK: - Pure, testable aggregation + scanning

enum ClaudeUsageAggregator {

    // MARK: Pricing (per-MILLION USD)

    struct ModelPricing: Sendable {
        let input: Double
        let output: Double
        let cacheRead: Double
        let cacheCreate: Double
    }

    /// Match model by lowercased-substring. Fields map exactly to the usage
    /// fields — cache_creation → cacheCreate, cache_read → cacheRead.
    static func pricing(for model: String) -> ModelPricing {
        let lower = model.lowercased()
        if lower.contains("opus") {
            return ModelPricing(input: 15, output: 75, cacheRead: 1.5, cacheCreate: 18.75)
        }
        if lower.contains("haiku") {
            return ModelPricing(input: 0.8, output: 4, cacheRead: 0.08, cacheCreate: 1.0)
        }
        // sonnet / fable / default
        return ModelPricing(input: 3, output: 15, cacheRead: 0.3, cacheCreate: 3.75)
    }

    private static func cost(
        input: Int,
        output: Int,
        cacheCreation: Int,
        cacheRead: Int,
        pricing: ModelPricing
    ) -> Double {
        (Double(input) * pricing.input
            + Double(output) * pricing.output
            + Double(cacheCreation) * pricing.cacheCreate
            + Double(cacheRead) * pricing.cacheRead) / 1_000_000
    }

    // MARK: Aggregation

    /// Dedup by messageId, bucket into today/week/month, and aggregate per model.
    /// A "today" entry (same calendar day as `now`) also counts in week + month.
    static func aggregate(entries: [ClaudeUsageEntry], now: Date) -> ClaudeUsageSnapshot {
        let calendar = Calendar.current
        let weekCutoff = now.addingTimeInterval(-7 * 86_400)
        let monthCutoff = now.addingTimeInterval(-31 * 86_400)

        var seen = Set<String>()
        var todayEntries: [ClaudeUsageEntry] = []
        var weekEntries: [ClaudeUsageEntry] = []
        var monthEntries: [ClaudeUsageEntry] = []

        for entry in entries {
            guard !seen.contains(entry.messageId) else { continue }
            seen.insert(entry.messageId)

            // Anything older than the month window is irrelevant to every bucket.
            guard entry.timestamp >= monthCutoff else { continue }
            monthEntries.append(entry)

            if entry.timestamp >= weekCutoff {
                weekEntries.append(entry)
            }
            if calendar.isDate(entry.timestamp, inSameDayAs: now) {
                todayEntries.append(entry)
            }
        }

        return ClaudeUsageSnapshot(
            today: window(from: todayEntries),
            week: window(from: weekEntries),
            month: window(from: monthEntries)
        )
    }

    private static func window(from entries: [ClaudeUsageEntry]) -> ClaudeUsageWindow {
        guard !entries.isEmpty else { return ClaudeUsageWindow() }

        struct Accumulator {
            var input = 0
            var output = 0
            var cacheCreation = 0
            var cacheRead = 0
        }

        var byModel: [String: Accumulator] = [:]
        for entry in entries {
            var acc = byModel[entry.model] ?? Accumulator()
            acc.input += entry.input
            acc.output += entry.output
            acc.cacheCreation += entry.cacheCreation
            acc.cacheRead += entry.cacheRead
            byModel[entry.model] = acc
        }

        let models = byModel.map { model, acc -> ClaudeModelUsage in
            let price = pricing(for: model)
            let costUSD = cost(
                input: acc.input,
                output: acc.output,
                cacheCreation: acc.cacheCreation,
                cacheRead: acc.cacheRead,
                pricing: price
            )
            return ClaudeModelUsage(
                model: model,
                inputTokens: acc.input,
                outputTokens: acc.output,
                cacheCreationTokens: acc.cacheCreation,
                cacheReadTokens: acc.cacheRead,
                costUSD: costUSD
            )
        }
        .sorted { $0.costUSD > $1.costUSD }

        let totalCost = models.reduce(0.0) { $0 + $1.costUSD }
        let totalTokens = models.reduce(0) { $0 + $1.totalTokens }
        return ClaudeUsageWindow(costUSD: totalCost, totalTokens: totalTokens, models: models)
    }

    // MARK: Scanning

    /// Enumerate *.jsonl under `projectsDir` recursively, skipping files not
    /// modified within the last 31 days, and extract usage entries. Malformed
    /// lines/files are ignored silently.
    static func scan(projectsDir: String, now: Date) -> [ClaudeUsageEntry] {
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: projectsDir, isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let monthCutoff = now.addingTimeInterval(-31 * 86_400)
        var entries: [ClaudeUsageEntry] = []

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }

            // Perf: skip transcripts untouched for more than a month.
            if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let modified = values.contentModificationDate,
               modified < monthCutoff {
                continue
            }

            entries.append(contentsOf: parseFile(at: url))
        }

        return entries
    }

    static func snapshot(
        projectsDir: String = NSHomeDirectory() + "/.claude/projects",
        now: Date = Date()
    ) -> ClaudeUsageSnapshot {
        aggregate(entries: scan(projectsDir: projectsDir, now: now), now: now)
    }

    private static func parseFile(at url: URL) -> [ClaudeUsageEntry] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        var entries: [ClaudeUsageEntry] = []
        content.enumerateLines { line, _ in
            // Cheap pre-filter before paying for JSON parsing.
            guard line.contains("\"assistant\"") else { return }
            if let entry = parseLine(line) {
                entries.append(entry)
            }
        }
        return entries
    }

    static func parseLine(_ line: String) -> ClaudeUsageEntry? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["type"] as? String) == "assistant",
              let message = json["message"] as? [String: Any],
              let messageId = message["id"] as? String,
              let timestamp = parseTimestamp(json["timestamp"] as? String)
        else { return nil }

        let model = (message["model"] as? String) ?? "unknown"
        let usage = message["usage"] as? [String: Any] ?? [:]

        return ClaudeUsageEntry(
            messageId: messageId,
            model: model,
            timestamp: timestamp,
            input: intValue(usage["input_tokens"]),
            output: intValue(usage["output_tokens"]),
            cacheCreation: intValue(usage["cache_creation_input_tokens"]),
            cacheRead: intValue(usage["cache_read_input_tokens"])
        )
    }

    private static func intValue(_ raw: Any?) -> Int {
        if let value = raw as? Int { return value }
        if let value = raw as? Double { return Int(value) }
        if let value = raw as? NSNumber { return value.intValue }
        return 0
    }

    private static func parseTimestamp(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return isoFractionalFormatter.date(from: raw) ?? isoFormatter.date(from: raw)
    }

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

// MARK: - Monitor (60s poll, off-main compute, main-thread delivery)

final class ClaudeUsageMonitor: @unchecked Sendable {
    private let projectsDir: String
    private let interval: TimeInterval
    private let queue = DispatchQueue(label: "claude.usage.monitor", qos: .utility)
    private var timer: DispatchSourceTimer?

    var onUpdate: ((ClaudeUsageSnapshot) -> Void)?

    init(
        projectsDir: String = NSHomeDirectory() + "/.claude/projects",
        interval: TimeInterval = 60
    ) {
        self.projectsDir = projectsDir
        self.interval = interval
    }

    func start() {
        // Initial read.
        refresh()

        // Poll periodically — transcripts change often; a 60s cadence is plenty.
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.refresh()
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            let snapshot = ClaudeUsageAggregator.snapshot(projectsDir: self.projectsDir)
            DispatchQueue.main.async { [weak self] in
                self?.onUpdate?(snapshot)
            }
        }
    }
}
