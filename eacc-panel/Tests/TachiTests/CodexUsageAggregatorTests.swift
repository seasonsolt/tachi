import XCTest
@testable import Tachi

final class CodexUsageAggregatorTests: XCTestCase {
    func testParseLinesAttributesTokenDeltasToCurrentModel() throws {
        let timestamp = "2026-07-13T02:00:00.123Z"
        let lines = [
            turnContext(model: "gpt-5.3-codex", timestamp: timestamp),
            tokenCount(input: 1_000, cached: 600, output: 100, timestamp: timestamp),
            turnContext(model: "gpt-5.4", timestamp: timestamp),
            tokenCount(input: 1_500, cached: 800, output: 140, timestamp: timestamp),
        ]

        let entries = CodexUsageAggregator.parseLines(lines, fallbackDate: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].model, "gpt-5.3-codex")
        XCTAssertEqual(entries[0].inputTokens, 1_000)
        XCTAssertEqual(entries[0].cachedInputTokens, 600)
        XCTAssertEqual(entries[0].outputTokens, 100)
        XCTAssertEqual(entries[1].model, "gpt-5.4")
        XCTAssertEqual(entries[1].inputTokens, 500)
        XCTAssertEqual(entries[1].cachedInputTokens, 200)
        XCTAssertEqual(entries[1].outputTokens, 40)
    }

    func testAggregatePricesCachedInputSeparatelyAndGroupsModels() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-13T03:00:00Z"))
        let entries = [
            CodexUsageEntry(
                model: "gpt-5.3-codex",
                timestamp: now,
                inputTokens: 1_000_000,
                cachedInputTokens: 800_000,
                outputTokens: 100_000
            ),
            CodexUsageEntry(
                model: "gpt-5.4",
                timestamp: now,
                inputTokens: 500_000,
                cachedInputTokens: 0,
                outputTokens: 50_000
            ),
        ]

        let snapshot = CodexUsageAggregator.aggregate(entries: entries, now: now)

        XCTAssertEqual(snapshot.today.models.count, 2)
        XCTAssertEqual(snapshot.today.totalTokens, 1_650_000)
        XCTAssertEqual(snapshot.today.costUSD, 3.89, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.month, snapshot.today)
        XCTAssertEqual(snapshot.recent, snapshot.today)
    }

    func testParseLinesUsesUnknownWhenModelIsMissing() {
        let lines = [tokenCount(
            input: 100,
            cached: 0,
            output: 10,
            timestamp: "2026-07-13T02:00:00Z"
        )]

        let entries = CodexUsageAggregator.parseLines(lines, fallbackDate: Date())

        XCTAssertEqual(entries.first?.model, "Unknown")
    }

    func testTruncatedTailAttributesBaselineToInitialSessionContext() throws {
        let sessionStart = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-07-01T01:00:00Z")
        )
        let lines = [
            turnContext(model: "gpt-5.4", timestamp: "2026-07-13T02:00:00Z"),
            tokenCount(input: 10_000, cached: 8_000, output: 500, timestamp: "2026-07-13T02:00:01Z"),
            tokenCount(input: 11_000, cached: 8_500, output: 600, timestamp: "2026-07-13T02:00:02Z"),
        ]

        let entries = CodexUsageAggregator.parseLines(
            lines,
            fallbackDate: Date(),
            initialModel: "gpt-5.3-codex",
            initialTimestamp: sessionStart
        )

        XCTAssertEqual(entries[0].model, "gpt-5.3-codex")
        XCTAssertEqual(entries[0].timestamp, sessionStart)
        XCTAssertEqual(entries[0].inputTokens, 10_000)
        XCTAssertEqual(entries[1].model, "gpt-5.4")
        XCTAssertEqual(entries[1].inputTokens, 1_000)
    }

    private func turnContext(model: String, timestamp: String) -> String {
        """
        {"timestamp":"\(timestamp)","type":"turn_context","payload":{"model":"\(model)"}}
        """
    }

    private func tokenCount(input: Int, cached: Int, output: Int, timestamp: String) -> String {
        """
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\(input),"cached_input_tokens":\(cached),"output_tokens":\(output)}}}}
        """
    }
}
