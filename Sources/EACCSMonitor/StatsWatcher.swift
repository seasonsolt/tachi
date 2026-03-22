import Foundation

// MARK: - Claude Code stats-cache.json parser and file watcher

final class StatsWatcher: @unchecked Sendable {
    private let statsPath: String
    private let queue = DispatchQueue(label: "stats.watcher", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    var onChange: ((RitualSourceData) -> Void)?

    init() {
        self.statsPath = NSHomeDirectory() + "/.claude/stats-cache.json"
    }

    // MARK: - Per-token pricing (USD) matching claude-code.ts lines 10-21

    private struct ModelPricing {
        let input: Double
        let output: Double
        let cacheRead: Double
        let cacheCreate: Double
    }

    private static let pricing: [(prefix: String, price: ModelPricing)] = [
        ("claude-opus-4-6",   ModelPricing(input: 15.0 / 1e6, output: 75.0 / 1e6, cacheRead: 1.5 / 1e6, cacheCreate: 18.75 / 1e6)),
        ("claude-opus-4-5",   ModelPricing(input: 15.0 / 1e6, output: 75.0 / 1e6, cacheRead: 1.5 / 1e6, cacheCreate: 18.75 / 1e6)),
        ("claude-sonnet-4-6", ModelPricing(input: 3.0 / 1e6,  output: 15.0 / 1e6, cacheRead: 0.3 / 1e6, cacheCreate: 3.75 / 1e6)),
        ("claude-sonnet-4-5", ModelPricing(input: 3.0 / 1e6,  output: 15.0 / 1e6, cacheRead: 0.3 / 1e6, cacheCreate: 3.75 / 1e6)),
        ("claude-haiku-4-5",  ModelPricing(input: 0.8 / 1e6,  output: 4.0 / 1e6,  cacheRead: 0.08 / 1e6, cacheCreate: 1.0 / 1e6)),
        ("claude-3-5-sonnet", ModelPricing(input: 3.0 / 1e6,  output: 15.0 / 1e6, cacheRead: 0.3 / 1e6, cacheCreate: 3.75 / 1e6)),
        ("claude-3-opus",     ModelPricing(input: 15.0 / 1e6, output: 75.0 / 1e6, cacheRead: 1.5 / 1e6, cacheCreate: 18.75 / 1e6)),
        ("claude-3-haiku",    ModelPricing(input: 0.25 / 1e6, output: 1.25 / 1e6, cacheRead: 0.03 / 1e6, cacheCreate: 0.3 / 1e6)),
    ]

    private static let defaultPricing = ModelPricing(input: 3.0 / 1e6, output: 15.0 / 1e6, cacheRead: 0.3 / 1e6, cacheCreate: 3.75 / 1e6)

    private static func getPricing(for model: String) -> ModelPricing {
        for entry in pricing {
            if model.hasPrefix(entry.prefix) { return entry.price }
        }
        return defaultPricing
    }

    // MARK: - Lifecycle

    func start() {
        // Initial read
        readAndNotify()

        // Watch for changes
        startWatching()
    }

    func stop() {
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    // MARK: - File watching

    private func startWatching() {
        let fd = Darwin.open(statsPath, O_EVTONLY)
        guard fd >= 0 else {
            // File doesn't exist yet, poll periodically
            queue.asyncAfter(deadline: .now() + 5) { [weak self] in
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
                // File was replaced — re-open watcher
                self.stop()
                self.queue.asyncAfter(deadline: .now() + 1) { [weak self] in
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
        guard let data = FileManager.default.contents(atPath: statsPath),
              let parsed = Self.parseStats(data: data)
        else { return }
        onChange?(parsed)
    }

    // MARK: - Stats parsing (matches claude-code.ts parseStats, lines 46-108)

    static func parseStats(data: Data) -> RitualSourceData? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.current
        let todayStr = df.string(from: now)
        let yearMonth = String(todayStr.prefix(7)) // "yyyy-MM"

        // Step A: Aggregate from modelUsage for totals
        let modelUsage = json["modelUsage"] as? [String: [String: Any]] ?? [:]
        var totalInput = 0
        var totalOutput = 0
        var totalCost = 0.0

        for (model, usage) in modelUsage {
            let inputTokens = usage["inputTokens"] as? Int ?? 0
            let outputTokens = usage["outputTokens"] as? Int ?? 0
            let cacheRead = usage["cacheReadInputTokens"] as? Int ?? 0
            let cacheCreate = usage["cacheCreationInputTokens"] as? Int ?? 0

            totalInput += inputTokens + cacheRead + cacheCreate
            totalOutput += outputTokens

            let price = getPricing(for: model)
            totalCost += Double(inputTokens) * price.input
                + Double(outputTokens) * price.output
                + Double(cacheRead) * price.cacheRead
                + Double(cacheCreate) * price.cacheCreate
        }

        // Step B: dailyModelTokens aggregation for today/month
        let dailyModelTokens = json["dailyModelTokens"] as? [[String: Any]] ?? []
        var todayTokens = 0
        var todayCost = 0.0
        var monthTokens = 0
        var monthCost = 0.0

        for day in dailyModelTokens {
            guard let date = day["date"] as? String,
                  let tokensByModel = day["tokensByModel"] as? [String: Any]
            else { continue }

            let isToday = date == todayStr
            let isMonth = date.hasPrefix(yearMonth)

            if isToday || isMonth {
                for (model, countAny) in tokensByModel {
                    let count: Int
                    if let c = countAny as? Int {
                        count = c
                    } else if let c = countAny as? Double {
                        count = Int(c)
                    } else {
                        continue
                    }

                    let price = getPricing(for: model)
                    let blendedRate = (price.input + price.output) / 2.0

                    if isToday {
                        todayTokens += count
                        todayCost += Double(count) * blendedRate
                    }
                    if isMonth {
                        monthTokens += count
                        monthCost += Double(count) * blendedRate
                    }
                }
            }
        }

        let totalTokens = totalInput + totalOutput

        return RitualSourceData(
            connected: true,
            totalTokens: totalTokens,
            todayTokens: todayTokens,
            monthTokens: monthTokens,
            costUSD: totalCost,
            todayCostUSD: todayCost,
            monthCostUSD: monthCost,
            inputTokens: totalInput,
            outputTokens: totalOutput,
            lastUpdated: Int(now.timeIntervalSince1970 * 1000)
        )
    }
}
