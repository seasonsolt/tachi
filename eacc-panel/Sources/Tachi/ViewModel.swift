import Foundation
import SwiftUI

enum CompanionPersona: Equatable {
    case defaultOrb
    case cyberSignal
    case matrixAgent
    case amberEye
    case voidMonolith

    var petAccent: Color? {
        switch self {
        case .defaultOrb:
            return nil
        case .cyberSignal:
            return Color(red: 0.0, green: 0.84, blue: 1.0)
        case .matrixAgent:
            return Color(red: 0, green: 1.0, blue: 0.25)
        case .amberEye:
            return Color(red: 0.80, green: 0.82, blue: 0.86)
        case .voidMonolith:
            return Color(red: 0.24, green: 0.24, blue: 0.26)
        }
    }

    // The menu bar face is the pet's second face. Frames may animate, but
    // every frame of a persona must render at the same width — width jitter,
    // not motion, is what steals attention. Braille and ASCII frames satisfy
    // this by construction; anything needing font fallback (kana) does not.
    func menuFace(mood: CompanionMood, frame: Int) -> String {
        switch self {
        case .matrixAgent:
            let table = Self.rainFrames(for: mood)
            return table[frame % table.count]
        case .voidMonolith:
            return Self.monolithFace(for: mood)
        case .defaultOrb, .cyberSignal, .amberEye:
            return mood.menuFace(frame: frame)
        }
    }

    /// Widest face this persona can show — used to reserve menu bar width.
    var menuFaceWidthSample: String {
        switch self {
        case .matrixAgent: return "⣿⣿"
        case .voidMonolith: return "▮"
        case .defaultOrb, .cyberSignal, .amberEye: return "O_O"
        }
    }

    // Braille rain: dots fall one row per tick, the two cells phase-offset.
    // Density follows mood; asleep, the rain settles on the ground.
    private static func rainFrames(for mood: CompanionMood) -> [String] {
        switch mood {
        case .feasting:
            return ["⠡⢂", "⢂⠌", "⠌⡐", "⡐⠡"]
        case .alert:
            return ["⠁⠄", "⠂⡀", "⠄⠁", "⡀⠂"]
        case .expecting:
            return ["⠐⠂", "⠂⠐"]
        case .dozing:
            return ["⡀⢀", "⢀⡀"]
        case .sleeping:
            return ["⢀⡀"]
        }
    }

    // Awake the monolith is solid stone; drowsy and asleep it hollows out.
    private static func monolithFace(for mood: CompanionMood) -> String {
        switch mood {
        case .feasting, .alert, .expecting: return "▮"
        case .dozing, .sleeping: return "▯"
        }
    }
}

enum CompanionPersonaMode: String, CaseIterable, Equatable {
    case automatic
    case defaultOrb
    case cyberSignal
    case matrixAgent
    case amberEye
    case voidMonolith

    static var allCases: [CompanionPersonaMode] {
        [
            .cyberSignal,
            .matrixAgent,
            .voidMonolith
        ]
    }

    var label: String {
        switch self {
        case .automatic: return "自动 Auto (follows theme)"
        case .defaultOrb: return "光球 Orb"
        // Source homages keep their original names, unstyled.
        case .cyberSignal: return "Laughing Man"
        case .matrixAgent: return "Digital Rain"
        case .amberEye: return "折纸 Folded Signal"
        case .voidMonolith: return "Monolith"
        }
    }

    var badge: String {
        switch self {
        case .automatic: return "PET AUTO"
        case .defaultOrb: return "PET ORB"
        case .cyberSignal: return "PET LAUGHING MAN"
        case .matrixAgent: return "PET DIGITAL RAIN"
        case .amberEye: return "PET UN"
        case .voidMonolith: return "PET MONOLITH"
        }
    }

    var personaOverride: CompanionPersona? {
        switch self {
        case .automatic: return nil
        case .defaultOrb: return .defaultOrb
        case .cyberSignal: return .cyberSignal
        case .matrixAgent: return .matrixAgent
        case .amberEye: return .amberEye
        case .voidMonolith: return .voidMonolith
        }
    }

    var linkedTheme: EACCThemeName {
        switch self {
        case .matrixAgent:
            return .matrix
        case .amberEye:
            return .amber
        case .voidMonolith:
            return .voidTheme
        case .automatic, .defaultOrb, .cyberSignal:
            return .cyber
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
    var codexRateLimits: CodexRateLimitSnapshot?
    var claudeUsage: ClaudeUsageSnapshot?
    var claudeStats: ClaudeStats?
    var isLoading = true
    var lastUpdated: Date?
    var testStates: [Int: TestState] = [:]
    var menuAnimationFrame = 0
    var companionPersonaMode: CompanionPersonaMode = ViewModel.loadCompanionPersonaMode()
    var selectedTheme: EACCThemeName = ViewModel.loadTheme()
    var companionCelebrationSequence = 0
    var companionCelebrationTitle = ""

    var recipeRuntime: RecipeRuntime? {
        didSet { wireRecipeUpdates() }
    }

    // Recipe source data — updated by RecipeRuntime callbacks
    var recipeSources: [RecipeSourceInfo] = []

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
        case .cyberSignal:
            return EACCThemeColors(
                bg: Color(red: 8.0 / 255.0, green: 13.0 / 255.0, blue: 20.0 / 255.0),
                cardBg: Color(red: 11.0 / 255.0, green: 19.0 / 255.0, blue: 28.0 / 255.0),
                cardBorder: Color(red: 56.0 / 255.0, green: 189.0 / 255.0, blue: 248.0 / 255.0).opacity(0.15),
                accent: Color(red: 56.0 / 255.0, green: 189.0 / 255.0, blue: 248.0 / 255.0),
                accentEdge: Color(red: 45.0 / 255.0, green: 212.0 / 255.0, blue: 191.0 / 255.0),
                textPrimary: Color(red: 241.0 / 255.0, green: 245.0 / 255.0, blue: 249.0 / 255.0),
                textSecondary: Color(red: 148.0 / 255.0, green: 163.0 / 255.0, blue: 184.0 / 255.0),
                textMuted: Color(red: 90.0 / 255.0, green: 107.0 / 255.0, blue: 126.0 / 255.0)
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
        sessions.filter {
            $0.status == .working
                || $0.status == .waitingForInput
                || ($0.processAlive && $0.status != .completed)
        }
    }

    var sessionRefreshInterval: TimeInterval { 15 }

    var workingSessionCount: Int {
        sessions.filter { $0.status == .working }.count
    }

    var waitingSessionCount: Int {
        sessions.filter { $0.status == .waitingForInput }.count
    }

    var codexSessionCount: Int {
        sessions.filter { $0.tool == .codex }.count
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

    // All active sessions are shown; the bubble scrolls past the first few
    // rather than truncating to a "+N more" footer.
    var companionTaskVisibleSessions: [CodingSession] {
        companionTaskPreviewSessions
    }

    // Rows visible in the bubble before it starts scrolling.
    static let companionTaskVisibleRowCap = 3

    var companionTaskOverflowCount: Int {
        max(0, companionTaskPreviewSessions.count - Self.companionTaskVisibleRowCap)
    }

    var shouldShowCompanionTaskPreview: Bool {
        companionTaskSession != nil
    }

    var companionTaskHeader: String {
        let activeCount = activeSessions.count
        if activeCount > 1 {
            return "\(activeCount) active sessions"
        }
        if activeCount == 1 {
            return "Current task"
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
        // The list scrolls; hint that there is more below the fold.
        companionTaskOverflowCount > 0 ? "↓ \(companionTaskOverflowCount) more — scroll" : ""
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
        let detail = session.status == .completed ? "done" : "watching"
        return "\(session.tool.rawValue) · \(detail)"
    }

    private func compactTaskPreviewText(_ raw: String?) -> String? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        if looksLikeAttachmentPrelude(text) {
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
        if normalized == "codex"
            || normalized == "claude code"
            || normalized == "claude design"
            || normalized == "opencode"
        {
            return false
        }
        if looksLikeAttachmentPrelude(text) {
            return false
        }
        return !looksLikeOnlyAPath(text)
    }

    private func looksLikeAttachmentPrelude(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("# files mentioned by the user")
            || normalized.hasPrefix("files mentioned by the user")
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
        if sessions.contains(where: { $0.status == .working }) { return .alert }
        if waitingSessionCount > 0 { return .expecting }
        if !sessions.isEmpty { return .dozing }
        return .sleeping
    }

    var companionPersona: CompanionPersona {
        companionPersonaMode.personaOverride ?? selectedTheme.defaultPersona
    }

    var companionHasMotion: Bool {
        sessions.contains(where: { $0.status == .working })
    }

    // Concurrent working sessions accelerate the companion's motion (e.g. the
    // Cyber Signal outer ring spins faster). 1.0 = calm baseline; capped so a
    // busy machine reads as energetic, not a blur.
    var companionMotionTempo: Double {
        let count = workingSessionCount
        guard count > 0 else { return 1.0 }
        return min(1.0 + 0.55 * Double(count), 4.0)
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
            return "watching in \(session.projectName)"
        }
        return "watching every \(Int(sessionRefreshInterval))s"
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

    // The face lives in its own fixed-width slot (see TachiApp), so animated
    // frames can never push the numbers around.
    var menuBarFace: String {
        let faceFrame = companionHasMotion ? menuAnimationFrame : 0
        return companionPersona.menuFace(mood: companionMood, frame: faceFrame)
    }

    // Progressive disclosure: idle shows only the face; utilization and the
    // session count join in only when they carry information, so the menu
    // bar never parks on a permanent "0%".
    var menuBarSuffix: String {
        var parts: [String] = []
        if weightedUtil > 0 {
            parts.append("\(weightedUtil)%")
        }
        let activeCount = activeSessions.count
        if activeCount > 0 {
            parts.append("·\(activeCount)")
        }
        return parts.joined(separator: " ")
    }

    var menuBarText: String {
        let suffix = menuBarSuffix
        return suffix.isEmpty ? menuBarFace : "\(menuBarFace) \(suffix)"
    }

    var menuBarWidthTemplate: String {
        "\(companionPersona.menuFaceWidthSample) 100% ·88"
    }

    @MainActor
    func refresh() async {
        lastUpdated = Date()
        isLoading = false
    }

    @MainActor
    func refreshSessionPulse() async {
        await refreshSessionsAndCodexQuota()
    }

    @MainActor
    func advanceMenuAnimation() {
        menuAnimationFrame = (menuAnimationFrame + 1) % 240
    }

    @MainActor
    func setCompanionPersonaMode(_ mode: CompanionPersonaMode) {
        companionPersonaMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.companionPersonaModeKey)
        setTheme(mode.linkedTheme)
    }

    /// Bridge reference for cross-process theme sync
    var bridge: EACCBridge?

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
        let linkedMode = Self.defaultCompanionPersonaMode(for: theme)
        if companionPersonaMode != linkedMode {
            companionPersonaMode = linkedMode
            UserDefaults.standard.set(linkedMode.rawValue, forKey: Self.companionPersonaModeKey)
        }
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
    private func refreshSessionsAndCodexQuota() async {
        let previousSessions = sessions
        async let updatedSessionsTask = Task.detached {
            SessionMonitor.shared.scanSessions()
        }.value
        async let rateLimitsTask = Task.detached {
            CodexAppServerRateLimitClient.shared.fetchCached()
        }.value
        async let resetCreditsTask = CodexResetCreditsClient.shared.fetch()

        let updatedSessions = await updatedSessionsTask
        let updatedRateLimits = await rateLimitsTask
        let resetCredits = await resetCreditsTask
        sessions = updatedSessions
        codexRateLimits = updatedRateLimits?.withResetCredits(resetCredits)
            ?? resetCredits.map(CodexRateLimitSnapshot.fromResetCredits)
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
            case "laughingMan":
                return .cyberSignal
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
            return .cyberSignal
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
