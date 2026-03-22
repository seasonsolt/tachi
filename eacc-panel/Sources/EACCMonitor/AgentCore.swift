import Foundation

// MARK: - Agent Data Models

struct AgentMessage: Identifiable {
    let id: UUID
    let role: AgentRole
    let content: String
    let timestamp: Date
    let toolCalls: [ToolCallInfo]?
}

enum AgentRole: String, Codable {
    case user, assistant, system
}

struct ToolCallInfo {
    let toolName: String
    let input: [String: Any]
    let output: String
}

struct AgentContext {
    let recipes: [String]
    let sources: [String: Bool]
    let totalTokens: Int
    let totalCost: Double
    let todayTokens: Int
    let todayCost: Double
}

// MARK: - AgentCore

final class AgentCore: @unchecked Sendable {
    private let model: String = "claude-sonnet-4-20250514"
    private var conversationHistory: [[String: Any]] = []
    private let tools: [AgentTool]
    private let queue = DispatchQueue(label: "agent.core")

    private(set) var apiKey: String?

    var onMessage: ((AgentMessage) -> Void)?
    var onToolCall: ((String, [String: Any]) -> Void)?

    // MARK: - Init

    init() {
        self.tools = AgentTools.allTools()
        self.apiKey = Self.loadAPIKey()
        self.conversationHistory = Self.loadHistory()
    }

    func setAPIKey(_ key: String) {
        apiKey = key
        saveAPIKey(key)
    }

    // MARK: - Send message (full tool-use loop)

    func sendMessage(_ text: String, context: AgentContext? = nil) async -> AgentMessage {
        // Build user message
        let userEntry: [String: Any] = ["role": "user", "content": text]
        queue.sync { conversationHistory.append(userEntry) }

        // Build system prompt
        let systemPrompt = buildSystemPrompt(context: context)

        // Tool-use loop
        var allToolCalls: [ToolCallInfo] = []

        while true {
            let messages: [[String: Any]] = queue.sync { conversationHistory }

            guard let responseContent = await callAPI(system: systemPrompt, messages: messages) else {
                let errorMsg = AgentMessage(
                    id: UUID(), role: .assistant,
                    content: "Failed to reach the API. Check your API key and connection.",
                    timestamp: Date(), toolCalls: nil
                )
                saveHistory()
                return errorMsg
            }

            // Check for text response vs tool_use
            var textParts: [String] = []
            var toolUseBlocks: [[String: Any]] = []

            for block in responseContent {
                guard let type = block["type"] as? String else { continue }
                if type == "text", let t = block["text"] as? String {
                    textParts.append(t)
                } else if type == "tool_use" {
                    toolUseBlocks.append(block)
                }
            }

            // Append assistant response to history
            let assistantEntry: [String: Any] = ["role": "assistant", "content": responseContent]
            queue.sync { conversationHistory.append(assistantEntry) }

            if toolUseBlocks.isEmpty {
                // Final text response — done
                let finalText = textParts.joined()
                let msg = AgentMessage(
                    id: UUID(), role: .assistant, content: finalText,
                    timestamp: Date(),
                    toolCalls: allToolCalls.isEmpty ? nil : allToolCalls
                )
                saveHistory()
                return msg
            }

            // Execute each tool and build tool_result messages
            var toolResults: [[String: Any]] = []

            for toolBlock in toolUseBlocks {
                guard let toolId = toolBlock["id"] as? String,
                      let toolName = toolBlock["name"] as? String,
                      let toolInput = toolBlock["input"] as? [String: Any]
                else { continue }

                onToolCall?(toolName, toolInput)

                // Find and execute the tool
                let output: String
                if let tool = tools.first(where: { ($0.definition["name"] as? String) == toolName }) {
                    output = await tool.execute(toolInput)
                } else {
                    output = "{\"error\": \"Unknown tool: \(toolName)\"}"
                }

                allToolCalls.append(ToolCallInfo(toolName: toolName, input: toolInput, output: output))

                toolResults.append([
                    "type": "tool_result",
                    "tool_use_id": toolId,
                    "content": output,
                ])
            }

            // Append tool results as a user message and loop
            let toolResultEntry: [String: Any] = ["role": "user", "content": toolResults]
            queue.sync { conversationHistory.append(toolResultEntry) }
        }
    }

    // MARK: - Anthropic API Call

    private func callAPI(system: String, messages: [[String: Any]]) async -> [[String: Any]]? {
        guard let key = apiKey, !key.isEmpty else { return nil }
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return nil }

        // Build tool definitions
        let toolDefs = tools.map { $0.definition }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": system,
            "tools": toolDefs,
            "messages": messages,
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.timeoutInterval = 60
        req.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard status == 200 else {
                let errBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                NSLog("[AgentCore] API error \(status): \(errBody)")
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]]
            else { return nil }

            return content
        } catch {
            NSLog("[AgentCore] API call failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(context: AgentContext?) -> String {
        var parts = [
            "You are the EACC agent, embedded in a macOS menu bar app that tracks AI token consumption as a sacred \"offering\" ritual.",
            "You help users set up data collectors (recipes) to track their AI API usage across providers.",
            "You can probe APIs, create/update collector recipes, query collected data, and inspect the system for AI tools.",
            "",
            "When the user asks you to set up tracking for a new API, use http_probe first to understand the API format, then create_recipe to configure the collector.",
            "Always be concise and direct.",
        ]

        if let ctx = context {
            parts.append("")
            parts.append("Current state:")
            parts.append("- Total tokens: \(ctx.totalTokens)")
            parts.append("- Total cost: $\(String(format: "%.2f", ctx.totalCost))")
            parts.append("- Today tokens: \(ctx.todayTokens)")
            parts.append("- Today cost: $\(String(format: "%.2f", ctx.todayCost))")

            if !ctx.sources.isEmpty {
                let sourceList = ctx.sources.map { "\($0.key): \($0.value ? "connected" : "disconnected")" }.joined(separator: ", ")
                parts.append("- Sources: \(sourceList)")
            }

            if !ctx.recipes.isEmpty {
                parts.append("- Active recipes: \(ctx.recipes.joined(separator: ", "))")
            }
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - API Key persistence (~/.eacc/agent/config.json)

    private static let agentDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".eacc/agent")
    }()

    private static let configPath: URL = {
        agentDir.appendingPathComponent("config.json")
    }()

    private static func loadAPIKey() -> String? {
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let key = json["apiKey"] as? String, !key.isEmpty
        else { return nil }
        return key
    }

    private func saveAPIKey(_ key: String) {
        try? FileManager.default.createDirectory(at: Self.agentDir, withIntermediateDirectories: true)
        let json: [String: Any] = ["apiKey": key]
        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? data.write(to: Self.configPath)
        }
    }

    // MARK: - Conversation history persistence (~/.eacc/agent/history.json)

    private static let historyPath: URL = {
        agentDir.appendingPathComponent("history.json")
    }()

    private static let maxHistoryMessages = 50

    private static func loadHistory() -> [[String: Any]] {
        guard let data = try? Data(contentsOf: historyPath),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        // Keep only last N messages
        if arr.count > maxHistoryMessages {
            return Array(arr.suffix(maxHistoryMessages))
        }
        return arr
    }

    private func saveHistory() {
        let history: [[String: Any]] = queue.sync {
            if conversationHistory.count > Self.maxHistoryMessages {
                conversationHistory = Array(conversationHistory.suffix(Self.maxHistoryMessages))
            }
            return conversationHistory
        }

        try? FileManager.default.createDirectory(at: Self.agentDir, withIntermediateDirectories: true)

        // Filter to only serializable entries (flatten tool_use content blocks to strings)
        let serializable = history.map { msg -> [String: Any] in
            var entry = msg
            if let content = msg["content"] {
                if content is String {
                    // Already a string — fine
                } else if let blocks = content as? [[String: Any]] {
                    // Convert content blocks to a JSON string for storage
                    if let data = try? JSONSerialization.data(withJSONObject: blocks),
                       let str = String(data: data, encoding: .utf8) {
                        entry["content"] = str
                        entry["content_type"] = "blocks"
                    }
                }
            }
            return entry
        }

        if let data = try? JSONSerialization.data(withJSONObject: serializable, options: .prettyPrinted) {
            try? data.write(to: Self.historyPath)
        }
    }

    func clearHistory() {
        queue.sync { conversationHistory = [] }
        try? FileManager.default.removeItem(at: Self.historyPath)
    }
}
