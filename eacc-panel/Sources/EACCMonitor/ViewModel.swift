import Foundation
import SwiftUI

enum CompanionPersona: Equatable {
    case defaultOrb
    case laughingMan
    case matrixAgent
    case amberEye
    case voidMonolith

    var petAccent: Color? {
        switch self {
        case .defaultOrb:
            return nil
        case .laughingMan:
            return Color(red: 0.0, green: 0.84, blue: 1.0)
        case .matrixAgent:
            return Color(red: 0, green: 1.0, blue: 0.25)
        case .amberEye:
            return Color(red: 0.91, green: 0.57, blue: 0.16)
        case .voidMonolith:
            return Color(red: 0.1, green: 0.1, blue: 0.1)
        }
    }
}

enum CompanionPersonaMode: String, CaseIterable, Equatable {
    case automatic
    case defaultOrb
    case laughingMan
    case matrixAgent
    case amberEye
    case voidMonolith

    var label: String {
        switch self {
        case .automatic: return "Auto (follows theme)"
        case .defaultOrb: return "Orb"
        case .laughingMan: return "笑い男 Laughing Man"
        case .matrixAgent: return "Matrix Agent"
        case .amberEye: return "Amber Eye"
        case .voidMonolith: return "Void Monolith"
        }
    }

    var badge: String {
        switch self {
        case .automatic: return "PET AUTO"
        case .defaultOrb: return "PET ORB"
        case .laughingMan: return "PET LM"
        case .matrixAgent: return "PET MX"
        case .amberEye: return "PET AM"
        case .voidMonolith: return "PET VD"
        }
    }

    var personaOverride: CompanionPersona? {
        switch self {
        case .automatic: return nil
        case .defaultOrb: return .defaultOrb
        case .laughingMan: return .laughingMan
        case .matrixAgent: return .matrixAgent
        case .amberEye: return .amberEye
        case .voidMonolith: return .voidMonolith
        }
    }
}

enum CompanionMood: Equatable {
    case feasting
    case alert
    case expecting
    case dozing
    case sleeping

    func menuFace(frame: Int) -> String {
        let frames: [String]
        switch self {
        case .feasting:
            frames = ["^_^", "^o^", "^_^", ">_<"]
        case .alert:
            frames = ["o_o", "O_O", "o_o", "o.o"]
        case .expecting:
            frames = ["._.", "o_o", "._.", "o.o"]
        case .dozing:
            frames = ["-_-", "-.-", "-_-", "u_u"]
        case .sleeping:
            frames = ["z_z", "-_-", "z_z", "-.-"]
        }
        return frames[frame % frames.count]
    }

    func accent(for theme: EACCThemeColors) -> Color {
        switch self {
        case .feasting: return theme.accent
        case .alert: return theme.accent.opacity(0.8)
        case .expecting: return theme.accent.opacity(0.7)
        case .dozing: return purpleAccent
        case .sleeping: return theme.textMuted
        }
    }

    var badge: String {
        switch self {
        case .feasting: return "LIVE FEED"
        case .alert: return "SNIFFING"
        case .expecting: return "AWAITING HOST"
        case .dozing: return "LIGHT DOZE"
        case .sleeping: return "HIBERNATING"
        }
    }
}

@Observable
final class ViewModel {
    var items: [AccountWithUsage] = []
    var sessions: [CodingSession] = []
    var claudeStats: ClaudeStats?
    var isLoading = true
    var lastUpdated: Date?
    var testStates: [Int: TestState] = [:]
    var menuAnimationFrame = 0
    var companionPersonaMode: CompanionPersonaMode = ViewModel.loadCompanionPersonaMode()
    var selectedTheme: EACCThemeName = ViewModel.loadTheme()

    // Agent
    var agentMessages: [AgentMessage] = []
    var agentInput: String = ""
    var agentIsThinking = false
    var agentNeedsAPIKey: Bool { agent?.apiKey == nil }
    var agent: AgentCore?
    var recipeRuntime: RecipeRuntime?

    var themeColors: EACCThemeColors {
        EACCThemeColors.forTheme(selectedTheme)
    }

    var refreshInterval: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: "refreshInterval")
            return stored > 0 ? stored : 30
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "refreshInterval")
        }
    }

    var providers: [ProviderSummary] {
        var result: [ProviderSummary] = []

        // Claude personal stats (ai.benwk.io) — standalone card, no admin capacity
        if let stats = claudeStats {
            result.append(ProviderSummary(
                id: "claude-personal",
                name: stats.name,
                platform: "anthropic",
                icon: "brain.head.profile",
                personalStats: stats,
                capacityData: nil
            ))
        }

        // Admin accounts (anthropic already filtered out in fetchAccounts)
        for item in items {
            result.append(ProviderSummary(
                id: "admin-\(item.id)",
                name: item.account.name,
                platform: item.account.platform,
                icon: item.account.icon,
                personalStats: nil,
                capacityData: item
            ))
        }

        return result
    }

    var activeSessions: [CodingSession] {
        sessions.filter { $0.status == .working || $0.status == .waitingForInput }
    }

    var sessionRefreshInterval: TimeInterval { 5 }

    var workingSessionCount: Int {
        sessions.filter { $0.status == .working }.count
    }

    var waitingSessionCount: Int {
        sessions.filter { $0.status == .waitingForInput }.count
    }

    var warmSessionCount: Int {
        sessions.filter { $0.pulse == .hot || $0.pulse == .warm }.count
    }

    var dominantSession: CodingSession? {
        sessions.sorted { lhs, rhs in
            if lhs.pulse != rhs.pulse { return lhs.pulse.rawValue > rhs.pulse.rawValue }
            return lhs.lastActivity > rhs.lastActivity
        }.first
    }

    var companionMood: CompanionMood {
        if sessions.contains(where: { $0.pulse == .hot }) { return .feasting }
        if sessions.contains(where: { $0.status == .working || $0.pulse == .warm }) { return .alert }
        if waitingSessionCount > 0 { return .expecting }
        if !sessions.isEmpty { return .dozing }
        return .sleeping
    }

    var companionPersona: CompanionPersona {
        companionPersonaMode.personaOverride ?? selectedTheme.defaultPersona
    }

    var companionHeadline: String {
        switch companionMood {
        case .feasting:
            let count = max(1, workingSessionCount)
            return count == 1 ? "Nibbling on a live session" : "Nibbling on \(count) live sessions"
        case .alert:
            return "Fresh session motion detected"
        case .expecting:
            return "Waiting for your next poke"
        case .dozing:
            return "Keeping one eye on warm threads"
        case .sleeping:
            return "No fresh session scent"
        }
    }

    var companionSubtitle: String {
        if let session = dominantSession {
            return "\(session.signal.label) in \(session.projectName)"
        }
        return "Fast session sensing runs every \(Int(sessionRefreshInterval))s"
    }

    var companionAccent: Color {
        companionMood.accent(for: themeColors)
    }

    var companionPetAccent: Color {
        companionPersona.petAccent ?? companionAccent
    }

    var weightedUtil: Int {
        let valid = items.filter { $0.usage != nil }
        guard !valid.isEmpty else { return 0 }
        let totalWeight = valid.reduce(0.0) { $0 + $1.activityWeight }
        guard totalWeight > 0 else { return 0 }
        let weightedSum = valid.reduce(0.0) {
            $0 + Double($1.maxUtilization) * $1.activityWeight
        }
        return Int((weightedSum / totalWeight).rounded())
    }

    var menuBarText: String {
        let activeCount = activeSessions.count
        let face = companionMood.menuFace(frame: menuAnimationFrame)
        if activeCount > 0 {
            return "\(face) \(weightedUtil)% [\(activeCount)]"
        }
        return "\(face) \(weightedUtil)%"
    }

    @MainActor
    func refresh() async {
        async let usageTask: () = refreshUsage()
        async let sessionsTask: () = refreshSessions()
        async let claudeTask = APIClient.shared.fetchClaudeStats()
        _ = await (usageTask, sessionsTask)
        claudeStats = await claudeTask
        lastUpdated = Date()
        isLoading = false
    }

    @MainActor
    func refreshSessionPulse() async {
        await refreshSessions()
    }

    @MainActor
    func advanceMenuAnimation() {
        menuAnimationFrame = (menuAnimationFrame + 1) % 240
    }

    @MainActor
    func setCompanionPersonaMode(_ mode: CompanionPersonaMode) {
        companionPersonaMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.companionPersonaModeKey)
    }

    /// Bridge reference for cross-process theme sync
    var bridge: EACCBridge?

    // MARK: - Agent

    @MainActor
    func sendAgentMessage() {
        let text = agentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let agent else { return }
        agentInput = ""

        let userMsg = AgentMessage(id: UUID(), role: .user, content: text, timestamp: Date(), toolCalls: nil)
        agentMessages.append(userMsg)
        agentIsThinking = true

        Task {
            let context = buildAgentContext()
            let response = await agent.sendMessage(text, context: context)
            await MainActor.run {
                agentMessages.append(response)
                agentIsThinking = false
            }
        }
    }

    @MainActor
    func setAgentAPIKey(_ key: String) {
        agent?.setAPIKey(key)
        // Trigger onboarding after key is set
        if agentMessages.isEmpty {
            triggerOnboarding()
        }
    }

    @MainActor
    func triggerOnboarding() {
        guard let agent, agent.apiKey != nil else { return }
        agentIsThinking = true
        Task {
            let context = buildAgentContext()
            let response = await agent.sendMessage(
                "I just launched the app for the first time. Please check what AI tools I have installed and help me set up token tracking.",
                context: context
            )
            await MainActor.run {
                agentMessages.append(response)
                agentIsThinking = false
            }
        }
    }

    private func buildAgentContext() -> AgentContext {
        let recipes = recipeRuntime?.getAllData().keys.map { $0 } ?? []
        let sources = recipeRuntime?.getAllData().reduce(into: [String: Bool]()) { $0[$1.key] = $1.value.connected } ?? [:]
        let allData: [EACCSourceData] = recipeRuntime.map { Array($0.getAllData().values) } ?? []
        let totalTokens = allData.reduce(0) { $0 + $1.totalTokens }
        let totalCost = allData.reduce(0.0) { $0 + $1.costUSD }
        let todayTokens = allData.reduce(0) { $0 + $1.todayTokens }
        let todayCost = allData.reduce(0.0) { $0 + $1.todayCostUSD }
        return AgentContext(recipes: recipes, sources: sources, totalTokens: totalTokens, totalCost: totalCost, todayTokens: todayTokens, todayCost: todayCost)
    }

    @MainActor
    func setTheme(_ theme: EACCThemeName) {
        selectedTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey)
        // Sync to file + WebSocket clients
        bridge?.setTheme(theme.rawValue)
    }

    /// Called by EACCBridge when theme changes externally (file watcher or WebSocket client)
    @MainActor
    func handleExternalThemeChange(_ themeName: String) {
        guard let theme = EACCThemeName(rawValue: themeName),
              theme != selectedTheme
        else { return }
        selectedTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey)
    }

    @MainActor
    private func refreshUsage() async {
        let api = APIClient.shared
        let accounts = await api.fetchAccounts()
        guard !accounts.isEmpty else { return }

        let results: [AccountWithUsage] = await withTaskGroup(
            of: AccountWithUsage.self
        ) { group in
            for acc in accounts {
                group.addTask {
                    let usage = await api.fetchUsage(accountId: acc.id)
                    return AccountWithUsage(id: acc.id, account: acc, usage: usage)
                }
            }
            var collected: [AccountWithUsage] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        items = results.sorted { a, b in
            let orderA = platformOrder(a.account.platform)
            let orderB = platformOrder(b.account.platform)
            if orderA != orderB { return orderA < orderB }
            return a.maxUtilization > b.maxUtilization
        }
        NotificationManager.shared.evaluate(items: items)
    }

    @MainActor
    private func refreshSessions() async {
        sessions = await Task.detached {
            SessionMonitor.shared.scanSessions()
        }.value
    }

    private func platformOrder(_ platform: String) -> Int {
        switch platform {
        case "openai": return 0
        case "antigravity": return 1
        default: return 2
        }
    }

    private static let companionPersonaModeKey = "companionPersonaMode"
    private static let themeKey = "ritualTheme"

    private static func loadCompanionPersonaMode() -> CompanionPersonaMode {
        let raw = UserDefaults.standard.string(forKey: companionPersonaModeKey)
        if let raw, let mode = CompanionPersonaMode(rawValue: raw) {
            return mode
        }
        // Migrate removed persona modes
        if let raw {
            switch raw {
            case "bladeRunnerEye", "nervHex": return .amberEye
            case "singularityVoid": return .voidMonolith
            default: break
            }
        }
        return .automatic
    }

    private static func loadTheme() -> EACCThemeName {
        let raw = UserDefaults.standard.string(forKey: themeKey)
        if let raw, let theme = EACCThemeName(rawValue: raw) {
            return theme
        }
        // Migrate removed theme names
        if let raw {
            switch raw {
            case "bladerunner", "blood": return .amber
            case "singularity": return .voidTheme
            default: break
            }
        }
        return .cyber
    }

    @MainActor
    func runTest(accountId: Int) async {
        testStates[accountId] = .testing
        let result = await APIClient.shared.testAccount(id: accountId)
        testStates[accountId] = result
        try? await Task.sleep(for: .seconds(8))
        if testStates[accountId] != .idle {
            testStates[accountId] = .idle
        }
    }
}
