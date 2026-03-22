import Foundation

// MARK: - Agent Tool Definition + Execution

struct AgentTool {
    let definition: [String: Any]  // Anthropic tool schema
    let execute: ([String: Any]) async -> String
}

final class AgentTools {

    // MARK: - All tools (Anthropic function calling format)

    static func allTools() -> [AgentTool] {
        [httpProbeTool(), createRecipeTool(), updateRecipeTool(), listRecipesTool(), queryDataTool(), getSystemInfoTool()]
    }

    // MARK: - Tool definitions + handlers

    private static func httpProbeTool() -> AgentTool {
        AgentTool(
            definition: [
                "name": "http_probe",
                "description": "Make an HTTP request to probe an API endpoint. Use this to discover API response formats, test API keys, and verify connectivity.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "url": ["type": "string", "description": "The URL to request"],
                        "method": ["type": "string", "enum": ["GET", "POST"], "default": "GET"],
                        "headers": ["type": "object", "description": "Request headers as key-value pairs"],
                        "body": ["type": "string", "description": "Request body (for POST)"],
                    ] as [String: Any],
                    "required": ["url"],
                ] as [String: Any],
            ],
            execute: httpProbe
        )
    }

    private static func createRecipeTool() -> AgentTool {
        AgentTool(
            definition: [
                "name": "create_recipe",
                "description": "Create a new collector recipe to track token usage from an API. The recipe will be saved and the collector will start automatically.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "id": ["type": "string"],
                        "name": ["type": "string"],
                        "type": ["type": "string", "enum": ["api_poll", "file_watch"]],
                        "endpoint": ["type": "string"],
                        "method": ["type": "string", "enum": ["GET", "POST"], "default": "GET"],
                        "auth_type": ["type": "string", "enum": ["bearer", "header", "none"]],
                        "auth_key_name": ["type": "string", "description": "Config key name for the API key"],
                        "auth_key_value": ["type": "string", "description": "The actual API key value"],
                        "headers": ["type": "object"],
                        "poll_interval_ms": ["type": "integer", "default": 60000],
                        "extract_total_tokens": ["type": "string", "description": "JSONPath to extract total tokens"],
                        "extract_cost": ["type": "string", "description": "JSONPath to extract cost in USD"],
                        "extract_input_tokens": ["type": "string"],
                        "extract_output_tokens": ["type": "string"],
                    ] as [String: Any],
                    "required": ["id", "name", "type", "endpoint"],
                ] as [String: Any],
            ],
            execute: createRecipe
        )
    }

    private static func updateRecipeTool() -> AgentTool {
        AgentTool(
            definition: [
                "name": "update_recipe",
                "description": "Update an existing collector recipe. Merges provided fields into the existing recipe.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "id": ["type": "string"],
                        "name": ["type": "string"],
                        "type": ["type": "string", "enum": ["api_poll", "file_watch"]],
                        "endpoint": ["type": "string"],
                        "method": ["type": "string", "enum": ["GET", "POST"]],
                        "auth_type": ["type": "string", "enum": ["bearer", "header", "none"]],
                        "auth_key_name": ["type": "string"],
                        "auth_key_value": ["type": "string"],
                        "headers": ["type": "object"],
                        "poll_interval_ms": ["type": "integer"],
                        "extract_total_tokens": ["type": "string"],
                        "extract_cost": ["type": "string"],
                        "extract_input_tokens": ["type": "string"],
                        "extract_output_tokens": ["type": "string"],
                    ] as [String: Any],
                    "required": ["id"],
                ] as [String: Any],
            ],
            execute: updateRecipe
        )
    }

    private static func listRecipesTool() -> AgentTool {
        AgentTool(
            definition: [
                "name": "list_recipes",
                "description": "List all configured collector recipes and their current status.",
                "input_schema": [
                    "type": "object",
                    "properties": [:] as [String: Any],
                ] as [String: Any],
            ],
            execute: listRecipes
        )
    }

    private static func queryDataTool() -> AgentTool {
        AgentTool(
            definition: [
                "name": "query_data",
                "description": "Query collected token usage data. Returns current totals, today's usage, and monthly usage across all sources.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "source": ["type": "string", "description": "Filter by source name, or omit for all sources"],
                        "period": ["type": "string", "enum": ["today", "week", "month", "total"], "default": "total"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            execute: queryData
        )
    }

    private static func getSystemInfoTool() -> AgentTool {
        AgentTool(
            definition: [
                "name": "get_system_info",
                "description": "Check what AI tools are installed on this system. Looks for Claude Code stats, Codex sessions, and other AI tool artifacts.",
                "input_schema": [
                    "type": "object",
                    "properties": [:] as [String: Any],
                ] as [String: Any],
            ],
            execute: getSystemInfo
        )
    }

    // MARK: - Tool implementations

    static func httpProbe(input: [String: Any]) async -> String {
        guard let urlString = input["url"] as? String,
              let url = URL(string: urlString)
        else {
            return "{\"error\": \"Invalid or missing URL\"}"
        }

        let method = (input["method"] as? String) ?? "GET"

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15

        if let headers = input["headers"] as? [String: String] {
            for (key, value) in headers {
                req.setValue(value, forHTTPHeaderField: key)
            }
        }
        if let body = input["body"] as? String {
            req.httpBody = body.data(using: .utf8)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            var bodyString = String(data: data, encoding: .utf8) ?? "<binary data>"
            if bodyString.count > 2000 {
                bodyString = String(bodyString.prefix(2000)) + "\n... (truncated)"
            }
            return "{\"status\": \(status), \"body\": \(escapeJSON(bodyString))}"
        } catch {
            return "{\"error\": \(escapeJSON(error.localizedDescription))}"
        }
    }

    static func createRecipe(input: [String: Any]) async -> String {
        guard let id = input["id"] as? String else {
            return "{\"error\": \"Missing recipe id\"}"
        }

        let recipesDir = recipesDirectory()
        let filePath = recipesDir.appendingPathComponent("\(id).json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: recipesDir, withIntermediateDirectories: true)

        // Check if already exists
        if FileManager.default.fileExists(atPath: filePath.path) {
            return "{\"error\": \"Recipe '\(id)' already exists. Use update_recipe to modify it.\"}"
        }

        // Write recipe JSON
        do {
            let data = try JSONSerialization.data(withJSONObject: input, options: .prettyPrinted)
            try data.write(to: filePath)
            return "{\"success\": true, \"message\": \"Recipe '\(id)' created at \(filePath.path)\"}"
        } catch {
            return "{\"error\": \(escapeJSON(error.localizedDescription))}"
        }
    }

    static func updateRecipe(input: [String: Any]) async -> String {
        guard let id = input["id"] as? String else {
            return "{\"error\": \"Missing recipe id\"}"
        }

        let filePath = recipesDirectory().appendingPathComponent("\(id).json")

        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return "{\"error\": \"Recipe '\(id)' not found\"}"
        }

        do {
            let existingData = try Data(contentsOf: filePath)
            guard var existing = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] else {
                return "{\"error\": \"Failed to parse existing recipe\"}"
            }

            // Merge new fields into existing
            for (key, value) in input {
                existing[key] = value
            }

            let merged = try JSONSerialization.data(withJSONObject: existing, options: .prettyPrinted)
            try merged.write(to: filePath)
            return "{\"success\": true, \"message\": \"Recipe '\(id)' updated\"}"
        } catch {
            return "{\"error\": \(escapeJSON(error.localizedDescription))}"
        }
    }

    static func listRecipes(input: [String: Any]) async -> String {
        let recipesDir = recipesDirectory()

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: recipesDir.path) else {
            return "{\"recipes\": []}"
        }

        var recipes: [[String: Any]] = []
        for file in files where file.hasSuffix(".json") {
            let filePath = recipesDir.appendingPathComponent(file)
            if let data = try? Data(contentsOf: filePath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                recipes.append([
                    "id": json["id"] ?? file.replacingOccurrences(of: ".json", with: ""),
                    "name": json["name"] ?? "Unknown",
                    "type": json["type"] ?? "unknown",
                    "endpoint": json["endpoint"] ?? "",
                ])
            }
        }

        if let data = try? JSONSerialization.data(withJSONObject: ["recipes": recipes]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"recipes\": []}"
    }

    static func queryData(input: [String: Any]) async -> String {
        // Read from StatsWatcher cache if available
        let statsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/stats-cache.json")

        var result: [String: Any] = [
            "source": input["source"] ?? "all",
            "period": input["period"] ?? "total",
        ]

        if FileManager.default.fileExists(atPath: statsPath.path),
           let data = try? Data(contentsOf: statsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            result["claude_code_stats"] = json
        } else {
            result["claude_code_stats"] = "not available"
        }

        // Check for recipe data
        let recipesDir = recipesDirectory()
        if let files = try? FileManager.default.contentsOfDirectory(atPath: recipesDir.path) {
            result["configured_recipes"] = files.filter { $0.hasSuffix(".json") }.count
        }

        if let data = try? JSONSerialization.data(withJSONObject: result),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"error\": \"Failed to build query result\"}"
    }

    static func getSystemInfo(input: [String: Any]) async -> String {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        var info: [String: Any] = [:]

        // Claude Code
        let claudeStatsPath = home.appendingPathComponent(".claude/stats-cache.json").path
        info["claude_code"] = [
            "installed": fm.fileExists(atPath: home.appendingPathComponent(".claude").path),
            "stats_available": fm.fileExists(atPath: claudeStatsPath),
        ]

        // Claude sessions
        let sessionsPath = home.appendingPathComponent(".claude/sessions").path
        if fm.fileExists(atPath: sessionsPath),
           let sessions = try? fm.contentsOfDirectory(atPath: sessionsPath) {
            info["claude_sessions"] = ["count": sessions.count]
        }

        // Codex
        info["codex"] = ["installed": fm.fileExists(atPath: home.appendingPathComponent(".codex").path)]

        // OpenAI config
        info["openai"] = ["configured": fm.fileExists(atPath: home.appendingPathComponent(".config/openai").path)]

        // EACC config
        let eaccDir = home.appendingPathComponent(".eacc").path
        info["eacc"] = [
            "configured": fm.fileExists(atPath: eaccDir),
            "config_exists": fm.fileExists(atPath: home.appendingPathComponent(".eacc/config.json").path),
            "theme_exists": fm.fileExists(atPath: home.appendingPathComponent(".eacc/theme.json").path),
        ]

        // Recipes
        let recipesDir = recipesDirectory()
        if let files = try? fm.contentsOfDirectory(atPath: recipesDir.path) {
            info["recipes"] = ["count": files.filter { $0.hasSuffix(".json") }.count]
        } else {
            info["recipes"] = ["count": 0]
        }

        if let data = try? JSONSerialization.data(withJSONObject: info),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"error\": \"Failed to gather system info\"}"
    }

    // MARK: - Helpers

    private static func recipesDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".eacc/recipes")
    }

    private static func escapeJSON(_ str: String) -> String {
        let escaped = str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }
}
