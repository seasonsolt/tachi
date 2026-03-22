import Foundation
import SwiftUI

enum CompanionPersona: Equatable {
    case defaultOrb
    case laughingMan

    var petAccent: Color? {
        switch self {
        case .defaultOrb:
            return nil
        case .laughingMan:
            return ghostAccent
        }
    }

    static func detect(from session: CodingSession?) -> CompanionPersona {
        guard let session else { return .defaultOrb }

        let haystacks = [
            session.projectPath,
            session.projectName,
            session.slug,
        ].map { $0.lowercased() }

        if haystacks.contains(where: {
            $0.contains("ritual-screen")
                || $0.contains("laughing-man")
                || $0.contains("laughingman")
                || $0.contains("ghost-in-the-shell")
                || $0.contains("standalonecomplex")
                || $0.contains("stand-alone-complex")
        }) {
            return .laughingMan
        }

        return .defaultOrb
    }
}

enum CompanionPersonaMode: String, CaseIterable, Equatable {
    case automatic
    case defaultOrb
    case laughingMan

    var label: String {
        switch self {
        case .automatic:
            return "Auto"
        case .defaultOrb:
            return "Orb"
        case .laughingMan:
            return "Laughing Man"
        }
    }

    var badge: String {
        switch self {
        case .automatic:
            return "PET AUTO"
        case .defaultOrb:
            return "PET ORB"
        case .laughingMan:
            return "PET LM"
        }
    }

    var personaOverride: CompanionPersona? {
        switch self {
        case .automatic:
            return nil
        case .defaultOrb:
            return .defaultOrb
        case .laughingMan:
            return .laughingMan
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

    var accent: Color {
        switch self {
        case .feasting: return cyanAccent
        case .alert: return goldAccent
        case .expecting: return goldAccent
        case .dozing: return purpleAccent
        case .sleeping: return textTertiary
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
        companionPersonaMode.personaOverride ?? CompanionPersona.detect(from: dominantSession)
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
        companionMood.accent
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

    private static func loadCompanionPersonaMode() -> CompanionPersonaMode {
        let raw = UserDefaults.standard.string(forKey: companionPersonaModeKey)
        return raw.flatMap(CompanionPersonaMode.init(rawValue:)) ?? .automatic
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
