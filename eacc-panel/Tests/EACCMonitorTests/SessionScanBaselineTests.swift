import XCTest
@testable import EACCMonitor

final class SessionScanBaselineTests: XCTestCase {
    func testSessionMonitorScanSessionsBaseline() throws {
        guard ProcessInfo.processInfo.environment["EACC_RUN_PERF_BASELINE"] == "1" else {
            throw XCTSkip("Set EACC_RUN_PERF_BASELINE=1 to run the local session scan baseline.")
        }

        let iterations = max(1, Int(ProcessInfo.processInfo.environment["EACC_PERF_ITERATIONS"] ?? "5") ?? 5)
        let warmup = SessionMonitor.shared.scanSessionBreakdown()
        var totalDurations: [TimeInterval] = []
        var claudeDurations: [TimeInterval] = []
        var codexDurations: [TimeInterval] = []
        var openCodeDurations: [TimeInterval] = []
        var codexCacheHits = 0
        var codexFileListCacheHits = 0
        var openCodeCacheHits = 0

        for _ in 0..<iterations {
            let breakdown = SessionMonitor.shared.scanSessionBreakdown()
            totalDurations.append(breakdown.totalDuration)
            claudeDurations.append(breakdown.claudeDuration)
            codexDurations.append(breakdown.codexDuration)
            openCodeDurations.append(breakdown.openCodeDuration)
            codexCacheHits += breakdown.codexCacheHits
            codexFileListCacheHits += breakdown.codexFileListCacheHits
            openCodeCacheHits += breakdown.openCodeCacheHits
        }

        print(
            """
            [session-scan-baseline] iterations=\(iterations) sessions=\(warmup.sessions.count) \
            claude_sessions=\(warmup.claudeCount) codex_sessions=\(warmup.codexCount) \
            opencode_sessions=\(warmup.openCodeCount) codex_cache_hits=\(codexCacheHits) \
            codex_file_list_cache_hits=\(codexFileListCacheHits) opencode_cache_hits=\(openCodeCacheHits)
            [session-scan-baseline] total \(Self.summary(totalDurations))
            [session-scan-baseline] claude \(Self.summary(claudeDurations))
            [session-scan-baseline] codex \(Self.summary(codexDurations))
            [session-scan-baseline] opencode \(Self.summary(openCodeDurations))
            """
        )
    }

    func testSessionMonitorReusesUnchangedCodexSessionFiles() throws {
        guard ProcessInfo.processInfo.environment["EACC_RUN_PERF_BASELINE"] == "1" else {
            throw XCTSkip("Set EACC_RUN_PERF_BASELINE=1 to run the local Codex scan cache check.")
        }

        let first = SessionMonitor.shared.scanSessionBreakdown()
        let second = SessionMonitor.shared.scanSessionBreakdown()

        guard first.codexCount > 0 else {
            throw XCTSkip("No recent Codex sessions available for cache verification.")
        }

        XCTAssertGreaterThan(second.codexCacheHits, 0)
        XCTAssertGreaterThan(second.codexFileListCacheHits, 0)
    }

    func testSessionMonitorReusesUnchangedOpenCodeDatabase() throws {
        guard ProcessInfo.processInfo.environment["EACC_RUN_PERF_BASELINE"] == "1" else {
            throw XCTSkip("Set EACC_RUN_PERF_BASELINE=1 to run the local OpenCode scan cache check.")
        }

        let dbPath = NSHomeDirectory() + "/.local/share/opencode/opencode.db"
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw XCTSkip("No OpenCode database available for cache verification.")
        }

        _ = SessionMonitor.shared.scanSessionBreakdown()
        let second = SessionMonitor.shared.scanSessionBreakdown()

        XCTAssertGreaterThan(second.openCodeCacheHits, 0)
    }

    private static func summary(_ values: [TimeInterval]) -> String {
        let total = values.reduce(0, +)
        let average = values.isEmpty ? 0 : total / Double(values.count)
        let minDuration = values.min() ?? 0
        let maxDuration = values.max() ?? 0
        return "avg_ms=\(formatMilliseconds(average)) min_ms=\(formatMilliseconds(minDuration)) max_ms=\(formatMilliseconds(maxDuration))"
    }

    private static func formatMilliseconds(_ value: TimeInterval) -> String {
        String(format: "%.2f", value * 1_000)
    }
}
