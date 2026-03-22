import Foundation

// MARK: - Wire-compatible types matching ritual-screen packages/shared/src/types.ts

struct RitualTokenData: Codable {
    let totalTokens: Int
    let totalCostUSD: Double
    let todayTokens: Int
    let todayCostUSD: Double
    let tokensPerSecond: Double
    let monthTokens: Int
    let monthCostUSD: Double
    let sources: RitualSources
    let lastUpdated: Int
}

struct RitualSourceData: Codable {
    let connected: Bool
    let totalTokens: Int
    let todayTokens: Int
    let monthTokens: Int
    let costUSD: Double
    let todayCostUSD: Double
    let monthCostUSD: Double
    let inputTokens: Int
    let outputTokens: Int
    let lastUpdated: Int

    static let empty = RitualSourceData(
        connected: false, totalTokens: 0, todayTokens: 0, monthTokens: 0,
        costUSD: 0, todayCostUSD: 0, monthCostUSD: 0,
        inputTokens: 0, outputTokens: 0, lastUpdated: 0
    )
}

struct RitualSources: Codable {
    let claudeCode: RitualSourceData
    let anthropicApi: RitualSourceData
    let openaiApi: RitualSourceData
}

struct RitualSessionInfo: Codable {
    let pid: Int
    let sessionId: String
    let cwd: String
    let startedAt: Int
    let alive: Bool
}

struct RitualMilestone: Codable {
    let threshold: Int
    let name: String
    let nameZh: String
    let scripture: String
    let effect: String
}

// MARK: - WSMessage (server → client)

enum RitualWSMessage {
    case tokenUpdate(RitualTokenData)
    case sessionUpdate([RitualSessionInfo])
    case connected([String])
    case milestone(RitualMilestone)
    case error(source: String, message: String)

    func jsonData() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
}

extension RitualWSMessage: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .tokenUpdate(let data):
            try container.encode("token_update", forKey: .type)
            try container.encode(data, forKey: .data)
        case .sessionUpdate(let sessions):
            try container.encode("session_update", forKey: .type)
            try container.encode(sessions, forKey: .sessions)
        case .connected(let sources):
            try container.encode("connected", forKey: .type)
            try container.encode(sources, forKey: .sources)
        case .milestone(let m):
            try container.encode("milestone", forKey: .type)
            try container.encode(m, forKey: .milestone)
        case .error(let source, let message):
            try container.encode("error", forKey: .type)
            try container.encode(source, forKey: .source)
            try container.encode(message, forKey: .message)
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, data, sessions, sources, milestone, source, message
    }
}
