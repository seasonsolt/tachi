import Foundation
import Network

// MARK: - Bridge: aggregates all data sources → WebSocket broadcast
// Mirrors eacc-screen/packages/cli/src/server.ts

final class EACCBridge: @unchecked Sendable {
    let wsServer: WebSocketServer
    let statsWatcher: StatsWatcher
    let sessionsWatcher: SessionsWatcher
    let themeWatcher: ThemeWatcher

    private let lock = NSLock()
    private var claudeCodeSource: EACCSourceData = .empty
    private var anthropicSource: EACCSourceData = .empty
    private var openaiSource: EACCSourceData = .empty
    private var dynamicSources: [String: EACCSourceData] = [:]  // from RecipeRuntime
    private var sessions: [EACCSessionInfo] = []
    private var lastMilestoneThreshold = 0
    private var previousTotalTokens = 0
    private var currentTheme: String = "cyber"

    /// RecipeRuntime integration — dynamic sources feed into token aggregation
    var recipeRuntime: RecipeRuntime? {
        didSet {
            recipeRuntime?.addSourceUpdateHandler { [weak self] id, data in
                self?.updateDynamicSource(id: id, data: data)
            }
        }
    }

    /// Called on main thread when theme changes (from file watcher or WebSocket client)
    var onThemeChanged: ((String) -> Void)?

    init(wsServer: WebSocketServer, statsWatcher: StatsWatcher, sessionsWatcher: SessionsWatcher, themeWatcher: ThemeWatcher) {
        self.wsServer = wsServer
        self.statsWatcher = statsWatcher
        self.sessionsWatcher = sessionsWatcher
        self.themeWatcher = themeWatcher
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

        // Wire up theme watcher — file changes → broadcast to WebSocket clients + notify ViewModel
        themeWatcher.onChange = { [weak self] theme in
            self?.handleThemeFileChanged(theme)
        }

        // Wire up WebSocket client connection handler
        wsServer.onClientConnected = { [weak self] conn in
            self?.handleNewClient(conn)
        }

        // Handle client messages (theme_change)
        wsServer.onClientMessage = { [weak self] _, message in
            self?.handleClientMessage(message)
        }

        // Read initial theme from file
        if let theme = themeWatcher.readTheme() {
            lock.lock()
            currentTheme = theme
            lock.unlock()
        }
    }

    // MARK: - Theme sync

    /// Called when macOS UI changes theme — write file + broadcast to WS clients
    func setTheme(_ theme: String) {
        lock.lock()
        let changed = currentTheme != theme
        currentTheme = theme
        lock.unlock()

        if changed {
            themeWatcher.writeTheme(theme)
            broadcastTheme(theme)
        }
    }

    private func handleThemeFileChanged(_ theme: String) {
        lock.lock()
        let changed = currentTheme != theme
        currentTheme = theme
        lock.unlock()

        if changed {
            // Broadcast to WebSocket clients
            broadcastTheme(theme)
            // Notify ViewModel on main thread
            DispatchQueue.main.async { [weak self] in
                self?.onThemeChanged?(theme)
            }
        }
    }

    private func handleClientMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else { return }

        if type == "theme_change", let theme = json["theme"] as? String {
            lock.lock()
            let changed = currentTheme != theme
            currentTheme = theme
            lock.unlock()

            if changed {
                // Write to file so CLI/web picks it up
                themeWatcher.writeTheme(theme)
                // Broadcast to all other WS clients
                broadcastTheme(theme)
                // Notify ViewModel on main thread
                DispatchQueue.main.async { [weak self] in
                    self?.onThemeChanged?(theme)
                }
            }
        }
    }

    private func broadcastTheme(_ theme: String) {
        if let data = EACCWSMessage.themeChange(theme).jsonData() {
            wsServer.broadcast(data)
        }
    }

    // MARK: - Update from API polling (called from ViewModel refresh cycle)

    func updateAnthropicAPI(_ data: EACCSourceData) {
        lock.lock()
        anthropicSource = data
        lock.unlock()
        broadcastTokenUpdate()
    }

    func updateOpenAIAPI(_ data: EACCSourceData) {
        lock.lock()
        openaiSource = data
        lock.unlock()
        broadcastTokenUpdate()
    }

    // MARK: - Dynamic source update (from RecipeRuntime)

    private func updateDynamicSource(id: String, data: EACCSourceData) {
        lock.lock()
        dynamicSources[id] = data
        lock.unlock()
        broadcastTokenUpdate()
    }

    // MARK: - Private data flow

    private func updateClaudeCode(_ data: EACCSourceData) {
        lock.lock()
        claudeCodeSource = data
        lock.unlock()
        broadcastTokenUpdate()
    }

    private func updateSessions(_ newSessions: [EACCSessionInfo]) {
        lock.lock()
        sessions = newSessions
        let current = sessions
        lock.unlock()

        if let data = EACCWSMessage.sessionUpdate(current).jsonData() {
            wsServer.broadcast(data)
        }
    }

    // MARK: - New client connection (send initial state: connected → token_update → session_update)

    private func handleNewClient(_ conn: Network.NWConnection) {
        lock.lock()
        let cc = claudeCodeSource
        let anth = anthropicSource
        let oai = openaiSource
        let dynamic = dynamicSources
        let sess = sessions
        let theme = currentTheme
        lock.unlock()

        // 1. connected
        var connectedSources: [String] = []
        if cc.connected { connectedSources.append("claudeCode") }
        if anth.connected { connectedSources.append("anthropicApi") }
        if oai.connected { connectedSources.append("openaiApi") }
        for (id, src) in dynamic where src.connected {
            connectedSources.append(id)
        }

        if let data = EACCWSMessage.connected(connectedSources).jsonData() {
            wsServer.send(to: conn, data: data)
        }

        // 2. token_update
        let tokenData = buildTokenData(cc: cc, anth: anth, oai: oai, dynamic: dynamic)
        if let data = EACCWSMessage.tokenUpdate(tokenData).jsonData() {
            wsServer.send(to: conn, data: data)
        }

        // 3. session_update
        if let data = EACCWSMessage.sessionUpdate(sess).jsonData() {
            wsServer.send(to: conn, data: data)
        }

        // 4. theme_change (send current theme to new client)
        if let data = EACCWSMessage.themeChange(theme).jsonData() {
            wsServer.send(to: conn, data: data)
        }
    }

    // MARK: - Broadcast + milestone check (matches server.ts broadcastUpdate)

    private func broadcastTokenUpdate() {
        lock.lock()
        let cc = claudeCodeSource
        let anth = anthropicSource
        let oai = openaiSource
        let dynamic = dynamicSources
        lock.unlock()

        let tokenData = buildTokenData(cc: cc, anth: anth, oai: oai, dynamic: dynamic)

        // Check milestone
        checkMilestone(totalTokens: tokenData.totalTokens)

        // Broadcast token_update
        if let data = EACCWSMessage.tokenUpdate(tokenData).jsonData() {
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

            let milestone = EACCMilestone(
                threshold: m.threshold,
                name: m.name,
                nameZh: m.nameZh,
                scripture: m.scripture,
                effect: m.effect
            )
            if let data = EACCWSMessage.milestone(milestone).jsonData() {
                wsServer.broadcast(data)
            }
        } else {
            previousTotalTokens = totalTokens
        }
    }

    // MARK: - Build aggregated TokenData (matches server.ts buildTokenData)

    private func buildTokenData(cc: EACCSourceData, anth: EACCSourceData, oai: EACCSourceData, dynamic: [String: EACCSourceData] = [:]) -> EACCTokenData {
        let all = [cc, anth, oai] + Array(dynamic.values)
        return EACCTokenData(
            totalTokens: all.reduce(0) { $0 + $1.totalTokens },
            totalCostUSD: all.reduce(0.0) { $0 + $1.costUSD },
            todayTokens: all.reduce(0) { $0 + $1.todayTokens },
            todayCostUSD: all.reduce(0.0) { $0 + $1.todayCostUSD },
            tokensPerSecond: 0,
            monthTokens: all.reduce(0) { $0 + $1.monthTokens },
            monthCostUSD: all.reduce(0.0) { $0 + $1.monthCostUSD },
            sources: EACCSources(
                claudeCode: cc,
                anthropicApi: anth,
                openaiApi: oai
            ),
            lastUpdated: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
}
