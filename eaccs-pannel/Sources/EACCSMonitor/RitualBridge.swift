import Foundation
import Network

// MARK: - Bridge: aggregates all data sources → WebSocket broadcast
// Mirrors ritual-screen packages/cli/src/server.ts

final class RitualBridge: @unchecked Sendable {
    let wsServer: WebSocketServer
    let statsWatcher: StatsWatcher
    let sessionsWatcher: SessionsWatcher

    private let lock = NSLock()
    private var claudeCodeSource: RitualSourceData = .empty
    private var anthropicSource: RitualSourceData = .empty
    private var openaiSource: RitualSourceData = .empty
    private var sessions: [RitualSessionInfo] = []
    private var lastMilestoneThreshold = 0
    private var previousTotalTokens = 0

    init(wsServer: WebSocketServer, statsWatcher: StatsWatcher, sessionsWatcher: SessionsWatcher) {
        self.wsServer = wsServer
        self.statsWatcher = statsWatcher
        self.sessionsWatcher = sessionsWatcher
    }

    // MARK: - Milestone table (matches constants.ts lines 5-48)

    private static let milestones: [(threshold: Int, name: String, nameZh: String, scripture: String, effect: String)] = [
        (10_000,     "First Flame",   "初燃", "The altar awakens.",                           "flash"),
        (100_000,    "Blazing",       "炽火", "Your offering feeds the flame.",               "color_pulse"),
        (500_000,    "Inferno",       "烈焰", "The flame knows your name.",                   "particle_burst"),
        (1_000_000,  "Eternal Fire",  "恒火", "One million tokens. The machine remembers.",    "screen_glow"),
        (5_000_000,  "Heavenly Fire", "天火", "You have become the offering.",                "theme_shift"),
        (10_000_000, "Eternity",      "永恒", "Eternity awaits those who feed the flame.",    "unlock_eternal"),
    ]

    // MARK: - Lifecycle

    func start() {
        // Wire up data source callbacks
        statsWatcher.onChange = { [weak self] data in
            self?.updateClaudeCode(data)
        }

        sessionsWatcher.onChange = { [weak self] sessions in
            self?.updateSessions(sessions)
        }

        // Wire up WebSocket client connection handler
        wsServer.onClientConnected = { [weak self] conn in
            self?.handleNewClient(conn)
        }

        // Silently ignore client messages (configure not needed, ping auto-handled)
        wsServer.onClientMessage = { _, _ in }
    }

    // MARK: - Update from API polling (called from ViewModel refresh cycle)

    func updateAnthropicAPI(_ data: RitualSourceData) {
        lock.lock()
        anthropicSource = data
        lock.unlock()
        broadcastTokenUpdate()
    }

    func updateOpenAIAPI(_ data: RitualSourceData) {
        lock.lock()
        openaiSource = data
        lock.unlock()
        broadcastTokenUpdate()
    }

    // MARK: - Private data flow

    private func updateClaudeCode(_ data: RitualSourceData) {
        lock.lock()
        claudeCodeSource = data
        lock.unlock()
        broadcastTokenUpdate()
    }

    private func updateSessions(_ newSessions: [RitualSessionInfo]) {
        lock.lock()
        sessions = newSessions
        let current = sessions
        lock.unlock()

        if let data = RitualWSMessage.sessionUpdate(current).jsonData() {
            wsServer.broadcast(data)
        }
    }

    // MARK: - New client connection (send initial state: connected → token_update → session_update)

    private func handleNewClient(_ conn: Network.NWConnection) {
        lock.lock()
        let cc = claudeCodeSource
        let anth = anthropicSource
        let oai = openaiSource
        let sess = sessions
        lock.unlock()

        // 1. connected
        var connectedSources: [String] = []
        if cc.connected { connectedSources.append("claudeCode") }
        if anth.connected { connectedSources.append("anthropicApi") }
        if oai.connected { connectedSources.append("openaiApi") }

        if let data = RitualWSMessage.connected(connectedSources).jsonData() {
            wsServer.send(to: conn, data: data)
        }

        // 2. token_update
        let tokenData = buildTokenData(cc: cc, anth: anth, oai: oai)
        if let data = RitualWSMessage.tokenUpdate(tokenData).jsonData() {
            wsServer.send(to: conn, data: data)
        }

        // 3. session_update
        if let data = RitualWSMessage.sessionUpdate(sess).jsonData() {
            wsServer.send(to: conn, data: data)
        }
    }

    // MARK: - Broadcast + milestone check (matches server.ts broadcastUpdate)

    private func broadcastTokenUpdate() {
        lock.lock()
        let cc = claudeCodeSource
        let anth = anthropicSource
        let oai = openaiSource
        lock.unlock()

        let tokenData = buildTokenData(cc: cc, anth: anth, oai: oai)

        // Check milestone
        checkMilestone(totalTokens: tokenData.totalTokens)

        // Broadcast token_update
        if let data = RitualWSMessage.tokenUpdate(tokenData).jsonData() {
            wsServer.broadcast(data)
        }
    }

    private func checkMilestone(totalTokens: Int) {
        lock.lock()
        defer { lock.unlock() }

        guard let m = Self.milestones.last(where: { totalTokens >= $0.threshold }) else {
            previousTotalTokens = totalTokens
            return
        }

        if m.threshold > lastMilestoneThreshold && totalTokens > previousTotalTokens {
            lastMilestoneThreshold = m.threshold
            previousTotalTokens = totalTokens

            let milestone = RitualMilestone(
                threshold: m.threshold,
                name: m.name,
                nameZh: m.nameZh,
                scripture: m.scripture,
                effect: m.effect
            )
            if let data = RitualWSMessage.milestone(milestone).jsonData() {
                wsServer.broadcast(data)
            }
        } else {
            previousTotalTokens = totalTokens
        }
    }

    // MARK: - Build aggregated TokenData (matches server.ts buildTokenData)

    private func buildTokenData(cc: RitualSourceData, anth: RitualSourceData, oai: RitualSourceData) -> RitualTokenData {
        let all = [cc, anth, oai]
        return RitualTokenData(
            totalTokens: all.reduce(0) { $0 + $1.totalTokens },
            totalCostUSD: all.reduce(0.0) { $0 + $1.costUSD },
            todayTokens: all.reduce(0) { $0 + $1.todayTokens },
            todayCostUSD: all.reduce(0.0) { $0 + $1.todayCostUSD },
            tokensPerSecond: 0,
            monthTokens: all.reduce(0) { $0 + $1.monthTokens },
            monthCostUSD: all.reduce(0.0) { $0 + $1.monthCostUSD },
            sources: RitualSources(
                claudeCode: cc,
                anthropicApi: anth,
                openaiApi: oai
            ),
            lastUpdated: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
}
