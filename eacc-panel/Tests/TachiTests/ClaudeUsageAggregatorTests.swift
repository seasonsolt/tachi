import XCTest
@testable import Tachi

final class ClaudeUsageAggregatorTests: XCTestCase {

    // Fixed reference instant so bucketing is deterministic across runs.
    private let now = Date(timeIntervalSince1970: 1_752_000_000)

    private func entry(
        id: String,
        model: String = "claude-opus-4-8",
        timestamp: Date,
        input: Int = 0,
        output: Int = 0,
        cacheCreation: Int = 0,
        cacheRead: Int = 0
    ) -> ClaudeUsageEntry {
        ClaudeUsageEntry(
            messageId: id,
            model: model,
            timestamp: timestamp,
            input: input,
            output: output,
            cacheCreation: cacheCreation,
            cacheRead: cacheRead
        )
    }

    // 1. A single assistant message spans multiple transcript rows sharing one
    //    message.id — those must be counted once, never summed.
    func testDedupCountsMessageOnce() {
        let row = entry(id: "msg_dup", timestamp: now, input: 1_000_000)

        let snapshot = ClaudeUsageAggregator.aggregate(entries: [row, row, row], now: now)

        XCTAssertEqual(snapshot.today.models.count, 1)
        XCTAssertEqual(snapshot.today.models.first?.inputTokens, 1_000_000)
        XCTAssertEqual(snapshot.today.totalTokens, 1_000_000)
        // opus input rate 15/M → $15 for 1M input (counted once, not $45).
        XCTAssertEqual(snapshot.today.costUSD, 15.0, accuracy: 1e-6)
    }

    // 2. Cost mapping for opus, and a regression guard that cache_creation and
    //    cache_read map to their OWN rates (not swapped).
    func testOpusCostMappingDoesNotSwapCacheFields() throws {
        let row = entry(
            id: "msg_cost",
            timestamp: now,
            input: 1_000_000,        // * 15    = 15.0
            output: 1_000_000,       // * 75    = 75.0
            cacheCreation: 2_000_000, // * 18.75 = 37.5
            cacheRead: 4_000_000     // * 1.5   = 6.0
        )

        let snapshot = ClaudeUsageAggregator.aggregate(entries: [row], now: now)
        let model = try XCTUnwrap(snapshot.today.models.first)

        XCTAssertEqual(model.cacheCreationTokens, 2_000_000)
        XCTAssertEqual(model.cacheReadTokens, 4_000_000)
        XCTAssertEqual(model.totalTokens, 8_000_000)
        // 15 + 75 + 37.5 + 6.0 = 133.5. If cacheCreate/cacheRead were swapped
        // the total would be 15 + 75 + 3.0 + 75.0 = 168.0.
        XCTAssertEqual(model.costUSD, 133.5, accuracy: 1e-6)
        XCTAssertEqual(snapshot.today.costUSD, 133.5, accuracy: 1e-6)
    }

    // 3. Bucketing: a 10-day-old entry lands in month but not week/today; a
    //    same-day entry lands in today AND week AND month (nested).
    func testBucketingNestsTodayIntoWeekAndMonth() {
        let tenDaysAgo = now.addingTimeInterval(-10 * 86_400)
        let old = entry(id: "msg_old", timestamp: tenDaysAgo, input: 1_000_000)
        let today = entry(id: "msg_today", timestamp: now, input: 1_000_000)

        let snapshot = ClaudeUsageAggregator.aggregate(entries: [old, today], now: now)

        // Month sees both.
        XCTAssertEqual(snapshot.month.totalTokens, 2_000_000)
        // Week and today see only the same-day entry.
        XCTAssertEqual(snapshot.week.totalTokens, 1_000_000)
        XCTAssertEqual(snapshot.today.totalTokens, 1_000_000)
    }

    // 4. The "otherwise" pricing branch (sonnet / fable / default) — fable maps
    //    to input 3 / output 15.
    func testDefaultPricingForFableModel() {
        let row = entry(
            id: "msg_fable",
            model: "claude-fable-5",
            timestamp: now,
            input: 1_000_000,  // * 3  = 3.0
            output: 1_000_000  // * 15 = 15.0
        )

        let snapshot = ClaudeUsageAggregator.aggregate(entries: [row], now: now)

        XCTAssertEqual(snapshot.today.costUSD, 18.0, accuracy: 1e-6)
    }

    // 5. Per-model rows are sorted by cost descending; also guards haiku pricing.
    func testModelsSortedByCostDescending() {
        let haiku = entry(id: "msg_haiku", model: "claude-haiku-4-5", timestamp: now, input: 1_000_000) // $0.8
        let opus = entry(id: "msg_opus", model: "claude-opus-4-8", timestamp: now, input: 1_000_000)    // $15

        let snapshot = ClaudeUsageAggregator.aggregate(entries: [haiku, opus], now: now)

        XCTAssertEqual(snapshot.today.models.map(\.model), ["claude-opus-4-8", "claude-haiku-4-5"])
        XCTAssertEqual(snapshot.today.models.first?.costUSD ?? 0, 15.0, accuracy: 1e-6)
        XCTAssertEqual(snapshot.today.models.last?.costUSD ?? 0, 0.8, accuracy: 1e-6)
    }
}
