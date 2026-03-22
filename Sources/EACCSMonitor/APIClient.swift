import Foundation

// MARK: - Config

enum Config {
    static let apiBase = "http://seasonsolt.myds.me:8888/api/v1"
    static let loginEmail = "thin@sub2api.local"
    static let loginPassword = "season2026"

    // Claude channel — ai.benwk.io (sub2api, refresh token auth)
    static let claudeApiBase = "https://ai.benwk.io/api/v1"
    static let claudeRefreshToken = "rt_bd9cbfa51fdd42bf2b0ac51fb4fc3b9d167f852e4d5d6ffb99d2f760e480bd1e"
}

// MARK: - Models

struct Account: Identifiable, Sendable {
    let id: Int
    let name: String
    let platform: String
    let type: String

    var icon: String {
        switch platform {
        case "openai": return "cube.transparent"
        case "antigravity": return "arrow.up.right.circle"
        default: return "server.rack"
        }
    }

    var platformColor: String {
        switch platform {
        case "openai": return "openai"
        case "antigravity": return "antigravity"
        default: return "gray"
        }
    }
}

struct WindowUsage: Sendable {
    let utilization: Int
    let remainingSeconds: Int
    let requests: Int
    let tokens: Int
}

struct ModelQuota: Identifiable, Sendable {
    let id: String
    let displayName: String
    let utilization: Int
    let resetTime: String
}

enum UsageData: Sendable {
    case openai(fiveHour: WindowUsage, sevenDay: WindowUsage)
    case antigravity(fiveHour: WindowUsage, models: [ModelQuota], tier: String, credits: Int)
}

struct AccountWithUsage: Identifiable, Sendable {
    let id: Int
    let account: Account
    let usage: UsageData?

    var maxUtilization: Int {
        guard let usage else { return 0 }
        switch usage {
        case .openai(let fh, let sd):
            return max(fh.utilization, sd.utilization)
        case .antigravity(let fh, let models, _, _):
            let modelMax = models.map(\.utilization).max() ?? 0
            return max(fh.utilization, modelMax)
        }
    }

    /// Activity weight: requests for OpenAI, active model count for Antigravity
    var activityWeight: Double {
        guard let usage else { return 0 }
        switch usage {
        case .openai(let fh, _):
            // Use 5h tokens as primary weight, fallback to requests, minimum 1
            if fh.tokens > 0 { return Double(fh.tokens) }
            return max(1, Double(fh.requests))
        case .antigravity(_, let models, _, _):
            let active = models.filter { $0.utilization > 0 }.count
            return max(1, Double(active))
        }
    }
}

struct ClaudeStats: Sendable {
    let name: String
    let dailyCost: Double
    let weeklyOpusCost: Double
    let totalCost: Double
    let formattedTotalCost: String
    let totalRequests: Int
    let totalTokens: Int
    let dailyCostLimit: Double
    let weeklyOpusCostLimit: Double
}

struct ProviderSummary: Identifiable {
    let id: String
    let name: String
    let platform: String
    let icon: String
    let personalStats: ClaudeStats?
    let capacityData: AccountWithUsage?
}

enum TestState: Equatable {
    case idle
    case testing
    case success(model: String, text: String)
    case failure(error: String)
}

// MARK: - API Client

final class APIClient: NSObject, URLSessionDelegate, @unchecked Sendable {
    static let shared = APIClient()
    private var accessToken: String?
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async
        -> (URLSession.AuthChallengeDisposition, URLCredential?)
    {
        if let trust = challenge.protectionSpace.serverTrust {
            return (.useCredential, URLCredential(trust: trust))
        }
        return (.performDefaultHandling, nil)
    }

    private func login() async -> Bool {
        guard let url = URL(string: Config.apiBase + "/auth/login") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "email": Config.loginEmail,
            "password": Config.loginPassword,
        ])

        guard let (data, _) = try? await session.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["code"] as? Int == 0,
              let inner = json["data"] as? [String: Any],
              let token = inner["access_token"] as? String
        else { return false }

        accessToken = token
        return true
    }

    private func makeRequest(path: String) -> URLRequest {
        var req = URLRequest(url: URL(string: Config.apiBase + "/admin" + path)!)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        req.timeoutInterval = 15
        return req
    }

    private func fetchJSON(path: String) async -> [String: Any]? {
        let req = makeRequest(path: path)
        guard let (data, resp) = try? await session.data(for: req) else { return nil }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["code"] as? Int == 0,
              let inner = json["data"] as? [String: Any]
        else { return nil }
        return inner
    }

    private func fetchJSONWithRetry(
        path: String, maxRetries: Int = 1, baseDelay: TimeInterval = 2
    ) async -> [String: Any]? {
        // Ensure we have a token, login if needed
        if accessToken == nil {
            _ = await login()
        }

        for attempt in 0...maxRetries {
            if let result = await fetchJSON(path: path) {
                return result
            }
            // On first failure, try re-login then retry
            if attempt < maxRetries {
                _ = await login()
                try? await Task.sleep(for: .seconds(baseDelay))
            }
        }
        return nil
    }

    func fetchAccounts() async -> [Account] {
        guard let data = await fetchJSONWithRetry(path: "/accounts"),
            let items = data["items"] as? [[String: Any]]
        else { return [] }

        return items.compactMap { item in
            guard let id = item["id"] as? Int, let name = item["name"] as? String else {
                return nil
            }
            let platform = item["platform"] as? String ?? ""
            if platform == "anthropic" { return nil }
            return Account(
                id: id, name: name,
                platform: platform,
                type: item["type"] as? String ?? "")
        }
    }

    func fetchUsage(accountId: Int) async -> UsageData? {
        guard let data = await fetchJSONWithRetry(path: "/accounts/\(accountId)/usage?timezone=Asia%2FShanghai")
        else { return nil }

        if let quota = data["antigravity_quota"] as? [String: [String: Any]] {
            return parseAntigravity(data: data, quota: quota)
        }
        return parseOpenAI(data: data)
    }

    private func parseOpenAI(data: [String: Any]) -> UsageData {
        let fh = parseWindow(data["five_hour"] as? [String: Any] ?? [:])
        let sd = parseWindow(data["seven_day"] as? [String: Any] ?? [:])
        return .openai(fiveHour: fh, sevenDay: sd)
    }

    private func parseAntigravity(data: [String: Any], quota: [String: [String: Any]]) -> UsageData
    {
        let fh = parseWindow(data["five_hour"] as? [String: Any] ?? [:])
        let details = data["antigravity_quota_details"] as? [String: [String: Any]] ?? [:]
        let credits = (data["ai_credits"] as? [[String: Any]])?.first?["amount"] as? Int ?? 0
        let tier = data["subscription_tier"] as? String ?? ""

        var models: [ModelQuota] = []
        for (name, info) in quota {
            let display = details[name]?["display_name"] as? String ?? name
            models.append(
                ModelQuota(
                    id: name,
                    displayName: display,
                    utilization: info["utilization"] as? Int ?? 0,
                    resetTime: info["reset_time"] as? String ?? ""
                ))
        }
        models.sort { $0.utilization > $1.utilization }

        return .antigravity(fiveHour: fh, models: models, tier: tier, credits: credits)
    }

    private func parseWindow(_ dict: [String: Any]) -> WindowUsage {
        let stats = dict["window_stats"] as? [String: Any]
        return WindowUsage(
            utilization: dict["utilization"] as? Int ?? 0,
            remainingSeconds: dict["remaining_seconds"] as? Int ?? 0,
            requests: stats?["requests"] as? Int ?? 0,
            tokens: stats?["tokens"] as? Int ?? 0
        )
    }

    // MARK: - Claude Channel (ai.benwk.io)

    private var claudeAccessToken: String?
    private var claudeRefreshToken: String = Config.claudeRefreshToken

    private func claudeRefresh() async -> Bool {
        guard let url = URL(string: Config.claudeApiBase + "/auth/refresh") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "refresh_token": claudeRefreshToken,
        ])

        guard let (data, _) = try? await session.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int, code == 0,
              let inner = json["data"] as? [String: Any],
              let token = inner["access_token"] as? String
        else { return false }

        claudeAccessToken = token
        if let newRefresh = inner["refresh_token"] as? String {
            claudeRefreshToken = newRefresh
        }
        return true
    }

    func fetchClaudeStats() async -> ClaudeStats? {
        if claudeAccessToken == nil {
            _ = await claudeRefresh()
        }
        for attempt in 0...1 {
            if let result = await fetchClaudeStatsOnce() {
                return result
            }
            if attempt < 1 {
                _ = await claudeRefresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        return nil
    }

    private func fetchClaudeStatsOnce() async -> ClaudeStats? {
        guard let url = URL(string: Config.claudeApiBase + "/usage/dashboard/stats?timezone=Asia%2FShanghai"),
              let token = claudeAccessToken
        else { return nil }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        req.timeoutInterval = 15

        guard let (data, resp) = try? await session.data(for: req) else { return nil }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { claudeAccessToken = nil; return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["code"] as? Int == 0,
              let d = json["data"] as? [String: Any]
        else { return nil }

        let totalCost = d["total_cost"] as? Double ?? 0
        let todayCost = d["today_cost"] as? Double ?? 0
        let totalRequests = d["total_requests"] as? Int ?? 0
        let totalTokens = d["total_tokens"] as? Int ?? 0

        return ClaudeStats(
            name: "Bruce",
            dailyCost: todayCost,
            weeklyOpusCost: 0,
            totalCost: totalCost,
            formattedTotalCost: String(format: "$%.2f", totalCost),
            totalRequests: totalRequests,
            totalTokens: totalTokens,
            dailyCostLimit: 0,
            weeklyOpusCostLimit: 0
        )
    }

    func testAccount(id: Int) async -> TestState {
        var req = makeRequest(path: "/accounts/\(id)/test")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(
            withJSONObject: ["model_id": "", "prompt": ""])
        req.timeoutInterval = 30

        guard let (bytes, _) = try? await session.bytes(for: req) else {
            return .failure(error: "Connection failed")
        }

        var model = ""
        var textParts: [String] = []
        var success = false

        do {
            for try await line in bytes.lines {
                guard line.hasPrefix("data: "),
                    let eventData = line.dropFirst(6).data(using: .utf8),
                    let event = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any],
                    let type = event["type"] as? String
                else { continue }

                switch type {
                case "test_start":
                    model = event["model"] as? String ?? ""
                case "content":
                    textParts.append(event["text"] as? String ?? "")
                case "test_complete":
                    success = event["success"] as? Bool ?? false
                default:
                    break
                }
            }
        } catch {
            if !success && textParts.isEmpty {
                return .failure(error: error.localizedDescription)
            }
        }

        if success {
            return .success(model: model, text: textParts.joined())
        }
        return .failure(error: textParts.joined().isEmpty ? "No response" : textParts.joined())
    }
}

// MARK: - Helpers

func utilizationColor(_ value: Int) -> (r: Double, g: Double, b: Double) {
    if value <= 30 { return (0.2, 0.78, 0.35) }
    if value <= 70 { return (1.0, 0.58, 0.0) }
    return (1.0, 0.23, 0.19)
}

func formatRemaining(_ seconds: Int) -> String {
    if seconds <= 0 { return "now" }
    let d = seconds / 86400
    let h = (seconds % 86400) / 3600
    let m = (seconds % 3600) / 60
    if d > 0 { return "\(d)d \(h)h" }
    if h > 0 { return "\(h)h \(m)m" }
    return "\(m)m"
}

func formatResetTime(_ iso: String) -> String {
    guard !iso.isEmpty else { return "" }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = formatter.date(from: iso)
    if date == nil {
        formatter.formatOptions = [.withInternetDateTime]
        date = formatter.date(from: iso)
    }
    if date == nil {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        date = df.date(from: iso)
    }
    guard let d = date else { return "" }
    let delta = Int(d.timeIntervalSinceNow)
    if delta <= 0 { return "resetting..." }
    return formatRemaining(delta)
}

func formatTokens(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
    return "\(n)"
}
