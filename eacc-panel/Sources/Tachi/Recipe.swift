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
    var body: String?         // POST request body (JSON string)
    var todayBody: String?    // POST body for today query (if different from body)
    var monthBody: String?    // POST body for month query (if different from body)
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

    // Support both snake_case (agent-generated) and camelCase (built-in)
    enum CodingKeys: String, CodingKey {
        case id, name, type, enabled, endpoint, method, headers, body
        case todayBody = "today_body"
        case monthBody = "month_body"
        case authType = "auth_type"
        case authKeyName = "auth_key_name"
        case authKeyValue = "auth_key_value"
        case pollIntervalMs = "poll_interval_ms"
        case watchPath = "watch_path"
        case parseScript = "parse_script"
        case extractTotalTokens = "extract_total_tokens"
        case extractCostUSD = "extract_cost"
        case extractInputTokens = "extract_input_tokens"
        case extractOutputTokens = "extract_output_tokens"
        case extractTodayTokens = "extract_today_tokens"
        case extractMonthTokens = "extract_month_tokens"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Also try camelCase keys for built-in recipes
        let alt = try decoder.container(keyedBy: AltKeys.self)

        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        type = try c.decode(RecipeType.self, forKey: .type)
        enabled = (try? c.decode(Bool.self, forKey: .enabled)) ?? true
        endpoint = try? c.decodeIfPresent(String.self, forKey: .endpoint)
        method = try? c.decodeIfPresent(String.self, forKey: .method)
        headers = try? c.decodeIfPresent([String: String].self, forKey: .headers)
        body = try? c.decodeIfPresent(String.self, forKey: .body)
        todayBody = (try? c.decodeIfPresent(String.self, forKey: .todayBody)) ?? (try? alt.decodeIfPresent(String.self, forKey: .todayBody))
        monthBody = (try? c.decodeIfPresent(String.self, forKey: .monthBody)) ?? (try? alt.decodeIfPresent(String.self, forKey: .monthBody))
        pollIntervalMs = (try? c.decodeIfPresent(Int.self, forKey: .pollIntervalMs)) ?? (try? alt.decodeIfPresent(Int.self, forKey: .pollIntervalMs))
        authType = (try? c.decodeIfPresent(AuthType.self, forKey: .authType)) ?? (try? alt.decodeIfPresent(AuthType.self, forKey: .authType))
        authKeyName = (try? c.decodeIfPresent(String.self, forKey: .authKeyName)) ?? (try? alt.decodeIfPresent(String.self, forKey: .authKeyName))
        authKeyValue = (try? c.decodeIfPresent(String.self, forKey: .authKeyValue)) ?? (try? alt.decodeIfPresent(String.self, forKey: .authKeyValue))
        watchPath = (try? c.decodeIfPresent(String.self, forKey: .watchPath)) ?? (try? alt.decodeIfPresent(String.self, forKey: .watchPath))
        parseScript = (try? c.decodeIfPresent(String.self, forKey: .parseScript)) ?? (try? alt.decodeIfPresent(String.self, forKey: .parseScript))
        extractTotalTokens = (try? c.decodeIfPresent(String.self, forKey: .extractTotalTokens)) ?? (try? alt.decodeIfPresent(String.self, forKey: .extractTotalTokens))
        extractCostUSD = (try? c.decodeIfPresent(String.self, forKey: .extractCostUSD)) ?? (try? alt.decodeIfPresent(String.self, forKey: .extractCostUSD))
        extractInputTokens = (try? c.decodeIfPresent(String.self, forKey: .extractInputTokens)) ?? (try? alt.decodeIfPresent(String.self, forKey: .extractInputTokens))
        extractOutputTokens = (try? c.decodeIfPresent(String.self, forKey: .extractOutputTokens)) ?? (try? alt.decodeIfPresent(String.self, forKey: .extractOutputTokens))
        extractTodayTokens = (try? c.decodeIfPresent(String.self, forKey: .extractTodayTokens)) ?? (try? alt.decodeIfPresent(String.self, forKey: .extractTodayTokens))
        extractMonthTokens = (try? c.decodeIfPresent(String.self, forKey: .extractMonthTokens)) ?? (try? alt.decodeIfPresent(String.self, forKey: .extractMonthTokens))
    }

    // camelCase keys for built-in recipes
    private enum AltKeys: String, CodingKey {
        case authType, authKeyName, authKeyValue, pollIntervalMs
        case todayBody, monthBody
        case watchPath, parseScript
        case extractTotalTokens, extractCostUSD, extractInputTokens, extractOutputTokens
        case extractTodayTokens, extractMonthTokens
    }

    // Direct init for built-in recipes
    init(id: String, name: String, type: RecipeType, enabled: Bool,
         endpoint: String? = nil, method: String? = nil, authType: AuthType? = nil,
         authKeyName: String? = nil, authKeyValue: String? = nil,
         headers: [String: String]? = nil, body: String? = nil,
         todayBody: String? = nil, monthBody: String? = nil, pollIntervalMs: Int? = nil,
         watchPath: String? = nil, parseScript: String? = nil,
         extractTotalTokens: String? = nil, extractCostUSD: String? = nil,
         extractInputTokens: String? = nil, extractOutputTokens: String? = nil,
         extractTodayTokens: String? = nil, extractMonthTokens: String? = nil) {
        self.id = id; self.name = name; self.type = type; self.enabled = enabled
        self.endpoint = endpoint; self.method = method; self.authType = authType
        self.authKeyName = authKeyName; self.authKeyValue = authKeyValue
        self.headers = headers; self.body = body
        self.todayBody = todayBody; self.monthBody = monthBody; self.pollIntervalMs = pollIntervalMs
        self.watchPath = watchPath; self.parseScript = parseScript
        self.extractTotalTokens = extractTotalTokens; self.extractCostUSD = extractCostUSD
        self.extractInputTokens = extractInputTokens; self.extractOutputTokens = extractOutputTokens
        self.extractTodayTokens = extractTodayTokens; self.extractMonthTokens = extractMonthTokens
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

    static let codexSessions = CollectorRecipe(
        id: "codex-sessions",
        name: "Codex",
        type: .fileWatch,
        enabled: true,
        pollIntervalMs: 60000,
        watchPath: "~/.codex/sessions",
        parseScript: "codex-sessions"
    )

    static let builtins: [CollectorRecipe] = [.claudeCode, .codexSessions]
}

// MARK: - Recipe persistence (~/.eacc/recipes/)

struct RecipeStore {
    static let recipesDir = NSHomeDirectory() + "/.eacc/recipes"
    private static let standardRecipeIds = Set(CollectorRecipe.builtins.map(\.id))

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

    /// Install standard local collectors and remove older/custom setup-driven recipes.
    static func installDefaults() {
        ensureDir()
        let existing = loadAll()

        for recipe in existing where !standardRecipeIds.contains(recipe.id) {
            delete(id: recipe.id)
        }

        for recipe in CollectorRecipe.builtins {
            save(recipe)
        }
    }
}
