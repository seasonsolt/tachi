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

struct AgentHarnessPlan: Equatable {
    let goal: String
    let suggestedTools: [String]
    let successCriteria: [String]
    let notes: [String]

    var promptBlock: String {
        var lines = [
            "Current harness brief:",
            "- Goal: \(goal)",
        ]

        if !suggestedTools.isEmpty {
            lines.append("- Suggested tool path: \(suggestedTools.joined(separator: " -> "))")
        }
        if !successCriteria.isEmpty {
            lines.append("- Success criteria: \(successCriteria.joined(separator: "; "))")
        }
        if !notes.isEmpty {
            lines.append("- Harness notes: \(notes.joined(separator: "; "))")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - AgentCore

final class AgentCore: @unchecked Sendable {
    private let model: String = "claude-sonnet-4-20250514"
    private var conversationHistory: [[String: Any]] = []
    private let tools: [AgentTool]
    private let queue = DispatchQueue(label: "agent.core")
    private static let maxToolLoopIterations = 8
    private static let historyCompactionThreshold = 24
    private static let historyMessagesToKeep = 10

    /// API key (sk-ant-... or cr_... token)
    private(set) var apiKey: String?
    /// Base URL for Anthropic API (default: https://api.anthropic.com)
    private(set) var apiBaseURL: String
    /// Auth style: "x-api-key" (standard) or "bearer" (proxy/custom)
    private(set) var authStyle: AuthStyle

    enum AuthStyle {
        case xApiKey   // x-api-key header (standard Anthropic)
        case bearer    // Authorization: Bearer (proxy like claude.benwk.io)
    }

    var onMessage: ((AgentMessage) -> Void)?
    var onToolCall: ((String, [String: Any]) -> Void)?

    // MARK: - Init

    init() {
        self.tools = AgentTools.allTools()

        // Load saved config first, then override with env vars if present
        let saved = Self.loadConfig()
        let env = Self.detectEnvironment()

        // Priority: env vars > saved config > defaults
        self.apiKey = env.apiKey ?? saved.apiKey
        self.apiBaseURL = env.baseURL != "https://api.anthropic.com" ? env.baseURL : (saved.baseURL ?? env.baseURL)
        self.authStyle = env.apiKey != nil ? env.authStyle : (saved.authStyle ?? env.authStyle)
        self.conversationHistory = Self.loadHistory()

        // Detect all provider keys from environment
        self.detectedProviders = Self.detectAllProviders()

        if apiKey != nil {
            NSLog("[AgentCore] Agent credentials: \(authStyle == .bearer ? "Bearer" : "x-api-key") → \(apiBaseURL)")
        }
        if !detectedProviders.isEmpty {
            NSLog("[AgentCore] Detected providers: \(detectedProviders.map(\.name).joined(separator: ", "))")
        }
    }

    func setAPIKey(_ key: String) {
        apiKey = key
        // Detect auth style from key format
        if key.hasPrefix("cr_") || key.hasPrefix("Bearer ") {
            authStyle = .bearer
        } else {
            authStyle = .xApiKey
        }
        saveAPIKey(key)
    }

    // MARK: - Environment Detection

    private struct EnvCredentials {
        let apiKey: String?
        let baseURL: String
        let authStyle: AuthStyle
    }

    /// Detected third-party provider credentials from environment
    struct DetectedProvider {
        let name: String
        let apiKey: String
        let baseURL: String?
    }

    /// All detected providers from env vars (available to AgentTools for auto-setup)
    private(set) var detectedProviders: [DetectedProvider] = []

    private static func detectEnvironment() -> EnvCredentials {
        let baseURL = ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"]
            ?? "https://api.anthropic.com"

        // Try ANTHROPIC_AUTH_TOKEN (bearer proxy), then ANTHROPIC_API_KEY (standard)
        if let token = ProcessInfo.processInfo.environment["ANTHROPIC_AUTH_TOKEN"], !token.isEmpty {
            return EnvCredentials(apiKey: token, baseURL: baseURL, authStyle: .bearer)
        }
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
            return EnvCredentials(apiKey: key, baseURL: baseURL, authStyle: .xApiKey)
        }

        return EnvCredentials(apiKey: nil, baseURL: baseURL, authStyle: .xApiKey)
    }

    /// Scan environment for all known AI provider credentials
    static func detectAllProviders() -> [DetectedProvider] {
        let env = ProcessInfo.processInfo.environment
        var providers: [DetectedProvider] = []

        // Anthropic
        if let key = env["ANTHROPIC_API_KEY"], !key.isEmpty {
            providers.append(DetectedProvider(name: "Anthropic", apiKey: key, baseURL: env["ANTHROPIC_BASE_URL"]))
        }
        if let token = env["ANTHROPIC_AUTH_TOKEN"], !token.isEmpty {
            providers.append(DetectedProvider(name: "Anthropic (proxy)", apiKey: token, baseURL: env["ANTHROPIC_BASE_URL"]))
        }

        // OpenAI
        if let key = env["OPENAI_API_KEY"], !key.isEmpty {
            providers.append(DetectedProvider(name: "OpenAI", apiKey: key, baseURL: env["OPENAI_BASE_URL"]))
        }

        // OpenRouter
        if let key = env["OPENROUTER_API_KEY"], !key.isEmpty {
            providers.append(DetectedProvider(name: "OpenRouter", apiKey: key, baseURL: nil))
        }

        // Together
        if let key = env["TOGETHER_API_KEY"], !key.isEmpty {
            providers.append(DetectedProvider(name: "Together", apiKey: key, baseURL: nil))
        }

        // Groq
        if let key = env["GROQ_API_KEY"], !key.isEmpty {
            providers.append(DetectedProvider(name: "Groq", apiKey: key, baseURL: nil))
        }

        // Fireworks
        if let key = env["FIREWORKS_API_KEY"], !key.isEmpty {
            providers.append(DetectedProvider(name: "Fireworks", apiKey: key, baseURL: nil))
        }

        // Mistral
        if let key = env["MISTRAL_API_KEY"], !key.isEmpty {
            providers.append(DetectedProvider(name: "Mistral", apiKey: key, baseURL: nil))
        }

        // Google / Gemini
        if let key = env["GOOGLE_API_KEY"] ?? env["GEMINI_API_KEY"], !key.isEmpty {
            providers.append(DetectedProvider(name: "Google AI", apiKey: key, baseURL: nil))
        }

        // Deepseek
        if let key = env["DEEPSEEK_API_KEY"], !key.isEmpty {
            providers.append(DetectedProvider(name: "DeepSeek", apiKey: key, baseURL: nil))
        }

        // Perplexity
        if let key = env["PERPLEXITY_API_KEY"] ?? env["PPLX_API_KEY"], !key.isEmpty {
            providers.append(DetectedProvider(name: "Perplexity", apiKey: key, baseURL: nil))
        }

        // Cohere
        if let key = env["COHERE_API_KEY"] ?? env["CO_API_KEY"], !key.isEmpty {
            providers.append(DetectedProvider(name: "Cohere", apiKey: key, baseURL: nil))
        }

        return providers
    }

    // MARK: - Send message (full tool-use loop)

    func sendMessage(_ text: String, context: AgentContext? = nil) async -> AgentMessage {
        // Build user message
        let userEntry: [String: Any] = ["role": "user", "content": text]
        let plan = Self.buildHarnessPlan(for: text, context: context)
        let startedAt = Date()

        queue.sync {
            conversationHistory.append(userEntry)
            conversationHistory = Self.compactConversationHistory(conversationHistory)
        }

        // Build system prompt
        let systemPrompt = buildSystemPrompt(context: context, plan: plan)

        // Tool-use loop
        var allToolCalls: [ToolCallInfo] = []
        var stepCount = 0

        while stepCount < Self.maxToolLoopIterations {
            stepCount += 1
            let messages: [[String: Any]] = queue.sync { conversationHistory }

            guard let responseContent = await callAPI(system: systemPrompt, messages: messages) else {
                let errorText = "Failed to reach the API. Check your API key and connection."
                let errorMsg = AgentMessage(
                    id: UUID(), role: .assistant,
                    content: errorText,
                    timestamp: Date(), toolCalls: nil
                )
                saveHistory()
                appendRunLog(
                    input: text,
                    plan: plan,
                    toolCalls: allToolCalls,
                    status: "api_error",
                    finalText: errorText,
                    startedAt: startedAt,
                    stepCount: stepCount
                )
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
                appendRunLog(
                    input: text,
                    plan: plan,
                    toolCalls: allToolCalls,
                    status: "completed",
                    finalText: finalText,
                    startedAt: startedAt,
                    stepCount: stepCount
                )
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

        let limitText = "I hit the current harness step limit before finishing. Please retry with a narrower request or continue from the latest state."
        let msg = AgentMessage(
            id: UUID(),
            role: .assistant,
            content: limitText,
            timestamp: Date(),
            toolCalls: allToolCalls.isEmpty ? nil : allToolCalls
        )
        saveHistory()
        appendRunLog(
            input: text,
            plan: plan,
            toolCalls: allToolCalls,
            status: "step_limit",
            finalText: limitText,
            startedAt: startedAt,
            stepCount: stepCount
        )
        return msg
    }

    // MARK: - Anthropic API Call

    private func callAPI(system: String, messages: [[String: Any]]) async -> [[String: Any]]? {
        guard let key = apiKey, !key.isEmpty else {
            NSLog("[AgentCore] No API key available")
            return nil
        }

        // Build URL from base (supports custom proxies like claude.benwk.io)
        let base = apiBaseURL.hasSuffix("/") ? String(apiBaseURL.dropLast()) : apiBaseURL
        guard let url = URL(string: "\(base)/v1/messages") else {
            NSLog("[AgentCore] Invalid URL: \(base)/v1/messages")
            return nil
        }

        NSLog("[AgentCore] Calling \(url) with \(authStyle == .bearer ? "Bearer" : "x-api-key") auth")

        // Build tool definitions
        let toolDefs = tools.map { $0.definition }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": system,
            "tools": toolDefs,
            "messages": messages,
        ]

        guard JSONSerialization.isValidJSONObject(body),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            NSLog("[AgentCore] Failed to serialize request body")
            return nil
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        // Auth: Bearer for proxy tokens (cr_...), x-api-key for standard Anthropic keys
        switch authStyle {
        case .bearer:
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .xApiKey:
            req.setValue(key, forHTTPHeaderField: "x-api-key")
        }

        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.timeoutInterval = 60
        req.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard status == 200 else {
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

    private func buildSystemPrompt(context: AgentContext?, plan: AgentHarnessPlan) -> String {
        var parts = [
            "You are the Tachi agent, embedded in a macOS menu bar app that tracks AI token consumption as a sacred \"offering\" ritual.",
            "You help users set up data collectors (recipes) to track their AI API usage across providers.",
            "You can probe APIs, create/update collector recipes, query collected data, and inspect the system for AI tools.",
            "",
            "Execution harness:",
            "- Separate planning, tool execution, and final response.",
            "- Prefer read-only discovery before mutating recipes.",
            "- Be explicit about what is verified versus inferred.",
            "- If you create or update a recipe, say exactly what changed and what still needs verification.",
            plan.promptBlock,
            "",
            "When the user asks you to set up tracking for a new API, use http_probe first to understand the API format, then create_recipe to configure the collector.",
            "Always be concise and direct. Respond in the same language as the user.",
            "",
            "IMPORTANT: When a user gives you a URL that returns HTML (a SPA/web app), the real data is behind an API endpoint, not in the HTML.",
            "Use http_probe to fetch the page's JavaScript bundle, then look for API routes in the JS code.",
            "Common pattern: SPA URLs like /admin-next/api-stats?apiId=X have backing APIs like POST /apiStats/api/user-stats with body {\"apiId\":\"X\"}.",
            "When you find the API, probe it to get the actual JSON data, then report the usage to the user.",
        ]

        // Detected providers from environment
        if !detectedProviders.isEmpty {
            parts.append("")
            parts.append("Detected API keys in environment (auto-discovered, ready to use):")
            for p in detectedProviders {
                let base = p.baseURL.map { " (base: \($0))" } ?? ""
                parts.append("- \(p.name): key available\(base)")
            }
            parts.append("Use these keys directly when creating recipes — no need to ask the user for them.")
        }

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

    // MARK: - Harness helpers

    static func buildHarnessPlan(for text: String, context: AgentContext? = nil) -> AgentHarnessPlan {
        let normalized = text.lowercased()
        let containsURL = normalized.contains("http://") || normalized.contains("https://")
        let isOnboarding = normalized.contains("first time")
            || normalized.contains("just launched")
            || normalized.contains("set up token tracking")
            || normalized.contains("help me set up")
            || text.contains("第一次")
            || text.contains("初次")
            || text.contains("帮我设置")
        let isSetup = containsURL
            || normalized.contains("track")
            || normalized.contains("setup")
            || normalized.contains("recipe")
            || normalized.contains("collector")
            || normalized.contains("api")
            || text.contains("接入")
            || text.contains("配置")
            || text.contains("采集")
        let isQuery = normalized.contains("usage")
            || normalized.contains("today")
            || normalized.contains("cost")
            || normalized.contains("how many")
            || normalized.contains("total")
            || text.contains("今天")
            || text.contains("总共")
            || text.contains("花费")
            || text.contains("多少")
            || text.contains("用量")

        var goal = "Help the user with their Tachi tracking workflow."
        var suggestedTools = ["list_recipes", "query_data", "get_system_info"]
        var successCriteria = ["answer the user's request clearly"]
        var notes = ["keep the reply concise and in the user's language"]

        if isOnboarding {
            goal = "Inspect the local machine, discover available AI tools, and bootstrap token tracking."
            suggestedTools = ["get_system_info", "list_recipes", "http_probe", "create_recipe", "query_data"]
            successCriteria = [
                "installed tools or providers are identified",
                "missing collectors are either created or clearly described",
                "the user knows what is tracked now versus what still needs setup",
            ]
            notes.append("favor discovery before creation")
        } else if isSetup {
            goal = "Verify the target API shape and configure or update tracking safely."
            suggestedTools = ["http_probe", "list_recipes", "create_recipe", "update_recipe", "query_data"]
            successCriteria = [
                "the endpoint or API response has been verified",
                "a collector change is only made after probe results support it",
                "the final reply states the recipe status and next verification step",
            ]
            notes.append("do not create or update a recipe until the probe result is understood")
        } else if isQuery {
            goal = "Answer the user's usage question from collected data and mention any data gaps."
            suggestedTools = ["query_data", "list_recipes"]
            successCriteria = [
                "usage numbers are reported for the requested period",
                "data gaps or disconnected sources are called out",
            ]
            notes.append("prefer existing collected data over speculative setup")
        }

        if let context {
            if context.recipes.isEmpty {
                notes.append("no active recipes are currently loaded")
            } else {
                notes.append("active recipes: \(context.recipes.joined(separator: ", "))")
            }

            let connected = context.sources.filter(\.value).map(\.key).sorted()
            if !connected.isEmpty {
                notes.append("connected sources right now: \(connected.joined(separator: ", "))")
            }
        }

        return AgentHarnessPlan(
            goal: goal,
            suggestedTools: suggestedTools,
            successCriteria: successCriteria,
            notes: notes
        )
    }

    static func compactConversationHistory(
        _ history: [[String: Any]],
        keepRecent: Int = AgentCore.historyMessagesToKeep,
        threshold: Int = AgentCore.historyCompactionThreshold
    ) -> [[String: Any]] {
        guard history.count > threshold, history.count > keepRecent else { return history }

        let summarySource = Array(history.dropLast(keepRecent))
        let recent = Array(history.suffix(keepRecent))
        let checkpoint: [String: Any] = [
            "role": "assistant",
            "content": historyCheckpointSummary(from: summarySource),
        ]
        return [checkpoint] + recent
    }

    static func historyCheckpointSummary(from history: [[String: Any]]) -> String {
        let userGoals = history.compactMap { message -> String? in
            guard (message["role"] as? String) == "user",
                  let text = plainText(from: message["content"]),
                  !text.isEmpty
            else { return nil }
            return shortened(text, limit: 120)
        }

        let assistantNotes = history.compactMap { message -> String? in
            guard (message["role"] as? String) == "assistant",
                  let text = plainText(from: message["content"]),
                  !text.isEmpty
            else { return nil }
            return shortened(text, limit: 120)
        }

        let toolNames = Array(history.flatMap(extractToolNames(from:)).prefix(8))
        var lines = ["Checkpoint summary for prior context:"]

        if !userGoals.isEmpty {
            lines.append("- Earlier user requests: \(userGoals.prefix(3).joined(separator: " | "))")
        }
        if !assistantNotes.isEmpty {
            lines.append("- Prior assistant notes: \(assistantNotes.prefix(3).joined(separator: " | "))")
        }
        if !toolNames.isEmpty {
            lines.append("- Tools already used: \(toolNames.joined(separator: ", "))")
        }

        lines.append("- Continue from the recent messages and avoid repeating completed work.")
        return lines.joined(separator: "\n")
    }

    private static func plainText(from content: Any?) -> String? {
        if let text = content as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let blocks = content as? [[String: Any]] {
            let text = blocks.compactMap { block -> String? in
                guard let type = block["type"] as? String else { return nil }
                switch type {
                case "text":
                    return block["text"] as? String
                case "tool_result":
                    return block["content"] as? String
                default:
                    return nil
                }
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

            return text.isEmpty ? nil : text
        }

        return nil
    }

    private static func extractToolNames(from message: [String: Any]) -> [String] {
        guard let blocks = message["content"] as? [[String: Any]] else { return [] }
        return blocks.compactMap { block in
            guard (block["type"] as? String) == "tool_use" else { return nil }
            return block["name"] as? String
        }
    }

    private static func shortened(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }

    private func appendRunLog(
        input: String,
        plan: AgentHarnessPlan,
        toolCalls: [ToolCallInfo],
        status: String,
        finalText: String,
        startedAt: Date,
        stepCount: Int
    ) {
        try? FileManager.default.createDirectory(at: Self.agentDir, withIntermediateDirectories: true)

        let iso = ISO8601DateFormatter()
        let record: [String: Any] = [
            "timestamp": iso.string(from: Date()),
            "status": status,
            "input": Self.shortened(input, limit: 300),
            "goal": plan.goal,
            "suggested_tools": plan.suggestedTools,
            "success_criteria": plan.successCriteria,
            "notes": plan.notes,
            "step_count": stepCount,
            "duration_ms": Int(Date().timeIntervalSince(startedAt) * 1000),
            "tool_calls": toolCalls.map { tool in
                [
                    "name": tool.toolName,
                    "input": Self.shortened(Self.jsonString(from: tool.input) ?? "{}", limit: 300),
                    "output_preview": Self.shortened(tool.output, limit: 300),
                ] as [String: Any]
            },
            "final_response": Self.shortened(finalText, limit: 400),
        ]

        guard JSONSerialization.isValidJSONObject(record),
              let data = try? JSONSerialization.data(withJSONObject: record),
              var line = String(data: data, encoding: .utf8)
        else { return }

        line.append("\n")
        guard let lineData = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: Self.runsPath.path) {
            guard let handle = try? FileHandle(forWritingTo: Self.runsPath) else { return }
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: lineData)
            } catch {
                return
            }
        } else {
            try? lineData.write(to: Self.runsPath)
        }
    }

    private static func jsonString(from object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return text
    }

    // MARK: - API Key persistence (~/.eacc/agent/config.json)

    private static let agentDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".eacc/agent")
    }()

    private static let configPath: URL = {
        agentDir.appendingPathComponent("config.json")
    }()

    private struct SavedConfig {
        let apiKey: String?
        let baseURL: String?
        let authStyle: AuthStyle?
    }

    private static func loadConfig() -> SavedConfig {
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return SavedConfig(apiKey: nil, baseURL: nil, authStyle: nil) }

        let key = json["apiKey"] as? String
        let base = json["baseURL"] as? String
        let style: AuthStyle? = (json["authStyle"] as? String) == "bearer" ? .bearer : (key != nil ? .xApiKey : nil)

        return SavedConfig(apiKey: key?.isEmpty == true ? nil : key, baseURL: base, authStyle: style)
    }

    private static func loadAPIKey() -> String? {
        return loadConfig().apiKey
    }

    private func saveConfig() {
        try? FileManager.default.createDirectory(at: Self.agentDir, withIntermediateDirectories: true)
        var json: [String: Any] = [:]
        if let key = apiKey { json["apiKey"] = key }
        json["baseURL"] = apiBaseURL
        json["authStyle"] = authStyle == .bearer ? "bearer" : "x-api-key"
        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? data.write(to: Self.configPath)
        }
    }

    private func saveAPIKey(_ key: String) {
        saveConfig()
    }

    // MARK: - Conversation history persistence (~/.eacc/agent/history.json)

    private static let historyPath: URL = {
        agentDir.appendingPathComponent("history.json")
    }()

    private static let runsPath: URL = {
        agentDir.appendingPathComponent("runs.jsonl")
    }()

    private static let maxHistoryMessages = 50

    private static func loadHistory() -> [[String: Any]] {
        guard let data = try? Data(contentsOf: historyPath),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }

        // Strip invalid fields and restore content blocks
        let cleaned = arr.compactMap { msg -> [String: Any]? in
            var entry = msg
            // Remove content_type (legacy bug — Anthropic API rejects extra fields)
            entry.removeValue(forKey: "content_type")
            // If content was serialized as a JSON string of blocks, restore it
            if let contentStr = entry["content"] as? String,
               contentStr.hasPrefix("["),
               let blockData = contentStr.data(using: .utf8),
               let blocks = try? JSONSerialization.jsonObject(with: blockData) as? [[String: Any]] {
                entry["content"] = blocks
            }
            return entry
        }

        if cleaned.count > maxHistoryMessages {
            return Array(cleaned.suffix(maxHistoryMessages))
        }
        return cleaned
    }

    private func saveHistory() {
        let history: [[String: Any]] = queue.sync {
            if conversationHistory.count > Self.maxHistoryMessages {
                conversationHistory = Array(conversationHistory.suffix(Self.maxHistoryMessages))
            }
            return conversationHistory
        }

        try? FileManager.default.createDirectory(at: Self.agentDir, withIntermediateDirectories: true)

        // Ensure all entries are JSON-serializable (content blocks are already valid)
        let serializable = history.filter { msg in
            JSONSerialization.isValidJSONObject(msg)
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
