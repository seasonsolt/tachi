import Foundation

// MARK: - Declarative collector recipe model
// A recipe describes how to collect token usage data from a source.

struct CollectorRecipe: Codable, Identifiable {
    let id: String
    let name: String
    let type: RecipeType
    var enabled: Bool

    // For api_poll type
    var endpoint: String?
    var method: String?       // GET or POST, default GET
    var authType: AuthType?   // bearer, header, or none
    var authKeyName: String?  // config key name (e.g., "openrouterKey")
    var authKeyValue: String? // actual API key value
    var headers: [String: String]?
    var pollIntervalMs: Int?  // default 60000

    // For file_watch type
    var watchPath: String?    // e.g., "~/.claude/stats-cache.json"
    var parseScript: String?  // identifier for built-in parser

    // Data extraction (for api_poll) — JSONPath-like expressions
    var extractTotalTokens: String?
    var extractCostUSD: String?
    var extractInputTokens: String?
    var extractOutputTokens: String?
    var extractTodayTokens: String?
    var extractMonthTokens: String?

    enum RecipeType: String, Codable {
        case apiPoll = "api_poll"
        case fileWatch = "file_watch"
    }

    enum AuthType: String, Codable {
        case bearer, header, none
    }
}

// MARK: - Built-in recipe definitions

extension CollectorRecipe {
    static let claudeCode = CollectorRecipe(
        id: "claude-code",
        name: "Claude Code",
        type: .fileWatch,
        enabled: true,
        watchPath: "~/.claude/stats-cache.json",
        parseScript: "claude-code-stats"
    )

    static let anthropicAPI = CollectorRecipe(
        id: "anthropic-api",
        name: "Anthropic API",
        type: .apiPoll,
        enabled: true,
        endpoint: "https://api.anthropic.com/v1/organizations/usage_report/messages",
        method: "GET",
        authType: .header,
        authKeyName: "anthropicAdminKey",
        pollIntervalMs: 60000,
        extractTotalTokens: "$.data[*].input_tokens + $.data[*].output_tokens"
    )

    static let openaiAPI = CollectorRecipe(
        id: "openai-api",
        name: "OpenAI",
        type: .apiPoll,
        enabled: true,
        endpoint: "https://api.openai.com/v1/organization/usage/completions",
        method: "GET",
        authType: .bearer,
        authKeyName: "openaiKey",
        pollIntervalMs: 60000
    )

    static let builtins: [CollectorRecipe] = [.claudeCode, .anthropicAPI, .openaiAPI]
}

// MARK: - Recipe persistence (~/.eacc/recipes/)

struct RecipeStore {
    static let recipesDir = NSHomeDirectory() + "/.eacc/recipes"

    static func ensureDir() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: recipesDir) {
            try? fm.createDirectory(atPath: recipesDir, withIntermediateDirectories: true)
        }
    }

    static func loadAll() -> [CollectorRecipe] {
        ensureDir()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: recipesDir) else { return [] }

        let decoder = JSONDecoder()
        var recipes: [CollectorRecipe] = []

        for file in files where file.hasSuffix(".json") {
            let path = recipesDir + "/" + file
            guard let data = fm.contents(atPath: path),
                  let recipe = try? decoder.decode(CollectorRecipe.self, from: data)
            else { continue }
            recipes.append(recipe)
        }

        return recipes
    }

    static func save(_ recipe: CollectorRecipe) {
        ensureDir()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(recipe) else { return }
        let path = recipesDir + "/\(recipe.id).json"
        FileManager.default.createFile(atPath: path, contents: data)
    }

    static func delete(id: String) {
        let path = recipesDir + "/\(id).json"
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Install built-in recipes if the recipes directory is empty
    static func installDefaults() {
        ensureDir()
        let existing = loadAll()
        if existing.isEmpty {
            for recipe in CollectorRecipe.builtins {
                save(recipe)
            }
        }
    }
}
