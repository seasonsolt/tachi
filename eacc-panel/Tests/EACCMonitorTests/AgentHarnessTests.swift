import XCTest
@testable import EACCMonitor

final class AgentHarnessTests: XCTestCase {
    func testSetupRequestsPreferProbeBeforeRecipeMutation() {
        let context = AgentContext(
            recipes: [],
            sources: [:],
            totalTokens: 0,
            totalCost: 0,
            todayTokens: 0,
            todayCost: 0
        )

        let plan = AgentCore.buildHarnessPlan(
            for: "请帮我接入 https://example.com 的 API 用量追踪",
            context: context
        )

        XCTAssertEqual(
            plan.suggestedTools,
            ["http_probe", "list_recipes", "create_recipe", "update_recipe", "query_data"]
        )
        XCTAssertTrue(plan.notes.contains(where: { $0.contains("no active recipes") }))
        XCTAssertTrue(plan.successCriteria.contains(where: { $0.contains("verified") }))
    }

    func testUsageQuestionsPreferQueryingExistingData() {
        let context = AgentContext(
            recipes: ["openai-api"],
            sources: ["openai-api": true],
            totalTokens: 3200,
            totalCost: 1.8,
            todayTokens: 450,
            todayCost: 0.22
        )

        let plan = AgentCore.buildHarnessPlan(
            for: "今天用了多少 token？",
            context: context
        )

        XCTAssertEqual(plan.suggestedTools, ["query_data", "list_recipes"])
        XCTAssertTrue(plan.notes.contains(where: { $0.contains("connected sources") }))
    }

    func testHistoryCompactionAddsCheckpointAndKeepsRecentTail() {
        var history: [[String: Any]] = []

        for index in 0..<14 {
            history.append(["role": "user", "content": "request \(index)"])
            history.append(["role": "assistant", "content": "response \(index)"])
        }

        let compacted = AgentCore.compactConversationHistory(history, keepRecent: 6, threshold: 8)

        XCTAssertEqual(compacted.count, 7)
        XCTAssertEqual(compacted.first?["role"] as? String, "assistant")

        let checkpoint = compacted.first?["content"] as? String
        XCTAssertTrue(checkpoint?.contains("Checkpoint summary for prior context:") == true)
        XCTAssertTrue(checkpoint?.contains("Earlier user requests:") == true)
        XCTAssertEqual(compacted.last?["content"] as? String, "response 13")
    }
}
