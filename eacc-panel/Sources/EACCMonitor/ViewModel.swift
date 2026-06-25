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
            return Color(red: 0.80, green: 0.82, blue: 0.86)
        case .voidMonolith:
            return Color(red: 0.24, green: 0.24, blue: 0.26)
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

    static var allCases: [CompanionPersonaMode] {
        [
            .laughingMan,
            .matrixAgent,
            .voidMonolith
        ]
    }

    var label: String {
        switch self {
        case .automatic: return "Auto (follows theme)"
        case .defaultOrb: return "Orb"
        case .laughingMan: return "笑い男 Laughing Man"
        case .matrixAgent: return "母体代码 Matrix Code"
        case .amberEye: return "折り紙ユニコーン Origami Unicorn"
        case .voidMonolith: return "石碑 Monolith"
        }
    }

    var badge: String {
        switch self {
        case .automatic: return "PET AUTO"
        case .defaultOrb: return "PET ORB"
        case .laughingMan: return "PET LM"
        case .matrixAgent: return "PET MX"
        case .amberEye: return "PET UN"
        case .voidMonolith: return "PET MO"
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
    var companionCelebrationSequence = 0
    var companionCelebrationTitle = ""
    var onboardingClaudePath: String = ViewModel.loadClaudeRecipePath()
    var onboardingOpenAIKey: String = ""
    var onboardingSub2APIBaseURL: String = UserDefaults.standard.string(forKey: AppConfigKeys.sub2APIBaseURL) ?? Config.claudeApiBase
    var onboardingSub2APIRefreshToken: String = ""
    var onboardingSaveMessage: String = ""

    var recipeRuntime: RecipeRuntime? {
        didSet { wireRecipeUpdates() }
    }

    // Recipe source data — updated by RecipeRuntime callbacks
    var recipeSources: [RecipeSourceInfo] = []

    var onboardingClaudeConfigured: Bool {
        RecipeStore.loadAll().contains { recipe in
            recipe.id == "claude-code" && recipe.enabled && !(recipe.watchPath ?? "").isEmpty
        }
    }

    var onboardingOpenAIConfigured: Bool {
        RecipeStore.loadAll().contains { recipe in
            recipe.id == "openai-api" && recipe.enabled && !(recipe.authKeyValue ?? "").isEmpty
        }
    }

    var onboardingSub2APIConfigured: Bool {
        let base = UserDefaults.standard.string(forKey: AppConfigKeys.sub2APIBaseURL)
        let token = UserDefaults.standard.string(forKey: AppConfigKeys.sub2APIRefreshToken)
        return !(base ?? "").isEmpty && !(token ?? "").isEmpty
    }

    struct RecipeSourceInfo: Identifiable {
        let id: String
        let name: String
        var data: EACCSourceData
    }

    private func wireRecipeUpdates() {
        recipeRuntime?.addSourceUpdateHandler { [weak self] id, data in
            DispatchQueue.main.async {
                guard let self else { return }
                let recipes = RecipeStore.loadAll()
                let name = recipes.first(where: { $0.id == id })?.name ?? id
                self.upsertSource(id: id, name: name, data: data)
            }
        }
    }

    @MainActor
    func upsertSource(id: String, name: String, data: EACCSourceData) {
        if let idx = recipeSources.firstIndex(where: { $0.id == id }) {
            recipeSources[idx].data = data
            return
        }

        recipeSources.append(RecipeSourceInfo(id: id, name: name, data: data))
    }

    var themeColors: EACCThemeColors {
        EACCThemeColors.forTheme(selectedTheme)
    }

    var panelThemeColors: EACCThemeColors {
        switch companionPersona {
        case .defaultOrb:
            return themeColors
        case .laughingMan:
            return EACCThemeColors(
                bg: Color(red: 0.03, green: 0.06, blue: 0.09),
                cardBg: Color(red: 0.05, green: 0.09, blue: 0.12),
                cardBorder: Color(red: 0.0, green: 0.84, blue: 1.0).opacity(0.18),
                accent: Color(red: 0.0, green: 0.84, blue: 1.0),
                accentEdge: Color(red: 0.09, green: 0.43, blue: 0.79),
                textPrimary: Color(red: 0.93, green: 0.98, blue: 1.0),
                textSecondary: Color(red: 0.69, green: 0.84, blue: 0.91),
                textMuted: Color(red: 0.45, green: 0.62, blue: 0.70)
            )
        case .matrixAgent:
            return EACCThemeColors.forTheme(.matrix)
        case .amberEye:
            return EACCThemeColors.forTheme(.amber)
        case .voidMonolith:
            return EACCThemeColors.forTheme(.voidTheme)
        }
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

    var sessionRefreshInterval: TimeInterval { 15 }

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

    var companionTaskPreviewSessions: [CodingSession] {
        activeSessions.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return sessionPriority(lhs.status) < sessionPriority(rhs.status)
            }
            if lhs.pulse != rhs.pulse { return lhs.pulse.rawValue > rhs.pulse.rawValue }
            return lhs.lastActivity > rhs.lastActivity
        }
    }

    var companionTaskSession: CodingSession? {
        companionTaskPreviewSessions.first
    }

    var companionTaskVisibleSessions: [CodingSession] {
        Array(companionTaskPreviewSessions.prefix(3))
    }

    var companionTaskOverflowCount: Int {
        max(0, companionTaskPreviewSessions.count - companionTaskVisibleSessions.count)
    }

    var shouldShowCompanionTaskPreview: Bool {
        companionTaskSession != nil
    }

    var companionTaskHeader: String {
        let activeCount = activeSessions.count
        if activeCount > 0 {
            return activeCount == 1 ? "Current task" : "\(activeCount) active tasks"
        }
        return "No active task"
    }

    var companionTaskSummary: String {
        if let session = companionTaskSession {
            if let summary = session.primaryTaskText {
                return summary
            }
            return session.projectName
        }
        return "Hover again after a live coding session wakes up."
    }

    var companionTaskContext: String {
        if activeSessions.count > 1 {
            return companionTaskOverflowCount > 0
                ? "+\(companionTaskOverflowCount) more active tasks"
                : ""
        }
        return ""
    }

    var companionTaskFooter: String? {
        let footer = companionTaskContext.trimmingCharacters(in: .whitespacesAndNewlines)
        return footer.isEmpty ? nil : footer
    }

    @MainActor
    func openCompanionTask(_ session: CodingSession) {
        SessionLauncher.open(session)
    }

    func companionTaskLine(for session: CodingSession) -> String {
        let candidates = [
            compactTaskPreviewText(session.taskTitle),
            compactTaskPreviewText(session.taskSummary),
            compactTaskPreviewText(session.slug)
        ].compactMap { $0 }

        if let candidate = candidates.first(where: {
            isMeaningfulTaskPreview($0, projectName: session.projectName)
        }) {
            return candidate
        }
        return session.projectName
    }

    func companionTaskProject(for session: CodingSession) -> String {
        session.projectName
    }

    func companionTaskShowsProjectBadge(for session: CodingSession) -> Bool {
        companionTaskLine(for: session).caseInsensitiveCompare(session.projectName) != .orderedSame
    }

    func companionTaskMeta(for session: CodingSession) -> String {
        "\(session.tool.rawValue) · \(session.signal.compactLabel)"
    }

    private func compactTaskPreviewText(_ raw: String?) -> String? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        text = text.replacingOccurrences(
            of: #"^\s*[=\-:#>\[\]\(\)]+\s*"#,
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\s*[=\-:#>\[\]\(\)]+\s*$"#,
            with: "",
            options: .regularExpression
        )

        for delimiter in ["。", "！", "？", ". ", "! ", "? ", "\n"] {
            if let range = text.range(of: delimiter) {
                let head = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if head.count >= 10 {
                    text = head
                    break
                }
            }
        }

        if let range = text.range(of: ": "),
            text.distance(from: text.startIndex, to: range.lowerBound) < 18
        {
            let tail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if tail.count >= 10 {
                text = tail
            }
        }

        guard !looksLikeOnlyAPath(text) else { return nil }

        if text.count > 84 {
            return String(text.prefix(81)) + "..."
        }
        return text
    }

    private func isMeaningfulTaskPreview(_ text: String, projectName: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return false }
        if normalized == projectName.lowercased() { return false }
        if normalized == "codex" || normalized == "claude code" || normalized == "opencode" {
            return false
        }
        return !looksLikeOnlyAPath(text)
    }

    private func looksLikeOnlyAPath(_ text: String) -> Bool {
        let slashCount = text.filter { $0 == "/" }.count
        if text.hasPrefix("/") && slashCount >= 2 {
            return true
        }
        if text.contains("/Users/") || text.contains("/src/") || text.contains("/main/") {
            return true
        }
        return false
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

    var companionHasMotion: Bool {
        !activeSessions.isEmpty
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

    var menuBarWidthTemplate: String {
        "O_O 100% [88]"
    }

    @MainActor
    func refresh() async {
        async let usageTask: () = refreshUsage()
        async let claudeTask = APIClient.shared.fetchClaudeStats()
        _ = await usageTask
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

    // MARK: - Onboarding

    @MainActor
    func saveClaudeOnboarding() {
        let path = onboardingClaudePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            onboardingSaveMessage = "Claude path is required."
            return
        }

        let recipe = CollectorRecipe(
            id: "claude-code",
            name: "Claude Code",
            type: .fileWatch,
            enabled: true,
            watchPath: path,
            parseScript: "claude-code-stats"
        )
        recipeRuntime?.addRecipe(recipe)
        RecipeStore.save(recipe)
        onboardingSaveMessage = "Claude Code collector configured."
    }

    @MainActor
    func saveOpenAIOnboarding() {
        let key = onboardingOpenAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            onboardingSaveMessage = "OpenAI key is required."
            return
        }

        var recipe = CollectorRecipe.openaiAPI
        recipe.authKeyValue = key
        recipe.enabled = true
        recipeRuntime?.addRecipe(recipe)
        RecipeStore.save(recipe)
        onboardingOpenAIKey = ""
        onboardingSaveMessage = "OpenAI usage collector configured."
    }

    @MainActor
    func saveSub2APIOnboarding() {
        let baseURL = onboardingSub2APIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let refreshToken = onboardingSub2APIRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty, !refreshToken.isEmpty else {
            onboardingSaveMessage = "sub2api base URL and refresh token are required."
            return
        }

        APIClient.shared.configureClaudeChannel(baseURL: baseURL, refreshToken: refreshToken)
        onboardingSub2APIRefreshToken = ""
        onboardingSaveMessage = "sub2api Claude channel configured."
        Task { await refresh() }
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
        let previousSessions = sessions
        let updatedSessions = await Task.detached {
            SessionMonitor.shared.scanSessions()
        }.value
        sessions = updatedSessions
        handleCompletedTasks(previous: previousSessions, current: updatedSessions)
    }

    private func platformOrder(_ platform: String) -> Int {
        switch platform {
        case "openai": return 0
        case "antigravity": return 1
        default: return 2
        }
    }

    private func sessionPriority(_ status: SessionStatus) -> Int {
        switch status {
        case .working: return 0
        case .waitingForInput: return 1
        case .idle: return 2
        case .completed: return 3
        }
    }

    private var seenCompletedSessionKeys: Set<String> = []

    @MainActor
    private func handleCompletedTasks(previous: [CodingSession], current: [CodingSession]) {
        let currentCompletedKeys = Set(
            current
                .filter { $0.status == .completed }
                .map(completionKey(for:))
        )

        if previous.isEmpty && seenCompletedSessionKeys.isEmpty {
            seenCompletedSessionKeys = currentCompletedKeys
            return
        }

        let previousByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        let newlyCompleted = current.filter { session in
            guard session.status == .completed else { return false }
            let key = completionKey(for: session)
            guard !seenCompletedSessionKeys.contains(key) else { return false }
            guard let old = previousByID[session.id] else { return false }
            return old.status != .completed
        }

        seenCompletedSessionKeys.formUnion(currentCompletedKeys)
        if seenCompletedSessionKeys.count > 256 {
            seenCompletedSessionKeys = Set(seenCompletedSessionKeys.suffix(128))
        }

        guard let latestCompletion = newlyCompleted.max(by: { $0.lastActivity < $1.lastActivity }) else {
            return
        }
        triggerCompanionCelebration(for: latestCompletion, totalCount: newlyCompleted.count)
    }

    private func completionKey(for session: CodingSession) -> String {
        "\(session.id)-\(session.status.label)-\(session.lastActivity.timeIntervalSince1970)"
    }

    @MainActor
    private func triggerCompanionCelebration(for session: CodingSession, totalCount: Int) {
        companionCelebrationTitle = totalCount > 1
            ? "\(totalCount) tasks completed"
            : (session.primaryTaskText ?? session.projectName)
        companionCelebrationSequence += 1
        NotificationManager.shared.playTaskCompletionCue()
    }

    private static let companionPersonaModeKey = "companionPersonaMode"
    private static let themeKey = "ritualTheme"

    private static func loadClaudeRecipePath() -> String {
        RecipeStore.loadAll().first(where: { $0.id == "claude-code" })?.watchPath ?? "~/.claude/stats-cache.json"
    }

    private static func loadCompanionPersonaMode() -> CompanionPersonaMode {
        let raw = UserDefaults.standard.string(forKey: companionPersonaModeKey)
        if let raw,
           let mode = CompanionPersonaMode(rawValue: raw),
           mode != .automatic,
           mode != .defaultOrb,
           mode != .amberEye {
            return mode
        }
        // Migrate removed persona modes
        if let raw {
            switch raw {
            case "automatic", "defaultOrb", "amberEye", "bladeRunnerEye", "nervHex":
                return defaultCompanionPersonaMode(for: loadTheme())
            case "singularityVoid": return .voidMonolith
            default: break
            }
        }
        return defaultCompanionPersonaMode(for: loadTheme())
    }

    private static func defaultCompanionPersonaMode(for theme: EACCThemeName) -> CompanionPersonaMode {
        switch theme {
        case .cyber, .amber:
            return .laughingMan
        case .matrix:
            return .matrixAgent
        case .voidTheme:
            return .voidMonolith
        }
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
