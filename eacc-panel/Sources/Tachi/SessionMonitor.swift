import Foundation

// MARK: - Session Models

struct CodingSession: Identifiable, Sendable {
    let id: String
    let tool: CodingTool
    let projectPath: String
    let slug: String
    let taskTitle: String?
    let taskSummary: String?
    let status: SessionStatus
    let lastActivity: Date
    let signal: SessionSignal
    let pulse: SessionPulse
    // True when a local process registration (~/.claude/sessions) confirms the
    // session is still attached, even if the transcript has gone quiet.
    var processAlive: Bool = false
    // Pid from that registration; lets the launcher activate the exact app
    // (Claude desktop, iTerm, ...) that owns the session.
    var ownerPid: Int32? = nil

    var projectName: String {
        let name = (projectPath as NSString).lastPathComponent
        return name.isEmpty ? projectPath : name
    }

    var primaryTaskText: String? {
        let candidates = [taskTitle, taskSummary, slug]
        return candidates.first(where: { isMeaningfulTaskText($0) }) ?? nil
    }

    var displayTitle: String {
        primaryTaskText ?? projectName
    }

    private func isMeaningfulTaskText(_ raw: String?) -> Bool {
        guard let raw else { return false }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let normalized = text.lowercased()
        if normalized == projectName.lowercased() { return false }
        if normalized == "codex"
            || normalized == "claude code"
            || normalized == "claude design"
            || normalized == "opencode"
        {
            return false
        }
        if normalized.hasPrefix("# files mentioned by the user")
            || normalized.hasPrefix("files mentioned by the user")
        {
            return false
        }
        return true
    }
}

struct SessionScanBreakdown: Sendable {
    let sessions: [CodingSession]
    let providerDurations: [String: TimeInterval]
    let codexCacheHits: Int
    let codexFileListCacheHits: Int
    let openCodeCacheHits: Int

    var claudeDuration: TimeInterval {
        providerDurations["claude-code"] ?? 0
    }

    var claudeDesignDuration: TimeInterval {
        providerDurations["claude-design"] ?? 0
    }

    var codexDuration: TimeInterval {
        providerDurations["codex"] ?? 0
    }

    var openCodeDuration: TimeInterval {
        providerDurations["opencode"] ?? 0
    }

    var totalDuration: TimeInterval {
        providerDurations.values.reduce(0, +)
    }

    var claudeCount: Int {
        sessions.filter { $0.tool == .claudeCode }.count
    }

    var claudeDesignCount: Int {
        sessions.filter { $0.tool == .claudeDesign }.count
    }

    var codexCount: Int {
        sessions.filter { $0.tool == .codex }.count
    }

    var openCodeCount: Int {
        sessions.filter { $0.tool == .openCode }.count
    }

    var pencilCount: Int {
        sessions.filter { $0.tool == .pencil }.count
    }
}

enum CodingTool: String, Sendable, Equatable {
    case claudeCode = "Claude Code"
    case claudeDesign = "Claude Design"
    case codex = "Codex"
    case openCode = "OpenCode"
    case pencil = "Pencil"

    var icon: String {
        switch self {
        case .claudeCode: return "brain.head.profile"
        case .claudeDesign: return "paintpalette"
        case .codex: return "cube.transparent"
        case .openCode: return "terminal"
        case .pencil: return "pencil.and.outline"
        }
    }

    var wireName: String {
        switch self {
        case .claudeCode: return "claude_code"
        case .claudeDesign: return "claude_design"
        case .codex: return "codex"
        case .openCode: return "open_code"
        case .pencil: return "pencil"
        }
    }
}

enum SessionStatus: Sendable, Equatable {
    case working
    case waitingForInput
    case idle
    case completed

    var label: String {
        switch self {
        case .working: return "Working"
        case .waitingForInput: return "Waiting"
        case .idle: return "Idle"
        case .completed: return "Done"
        }
    }
}

enum SessionSignal: Sendable, Equatable {
    case booting
    case reasoning
    case tooling
    case responding
    case awaitingUser
    case quiet
    case completed

    var label: String {
        switch self {
        case .booting: return "Fresh prompt scent"
        case .reasoning: return "Thinking"
        case .tooling: return "Tool clatter"
        case .responding: return "Reply streaming"
        case .awaitingUser: return "Watching for you"
        case .quiet: return "Thread warmth"
        case .completed: return "Curled up"
        }
    }

    var compactLabel: String {
        switch self {
        case .booting: return "starting"
        case .reasoning: return "thinking"
        case .tooling: return "tooling"
        case .responding: return "replying"
        case .awaitingUser: return "waiting"
        case .quiet: return "warm"
        case .completed: return "done"
        }
    }
}

enum SessionPulse: Int, Sendable, Equatable {
    case sleeping = 0
    case drowsy = 1
    case listening = 2
    case warm = 3
    case hot = 4
}

struct SessionTrace {
    let status: SessionStatus
    let signal: SessionSignal
    let pulse: SessionPulse
    let lastActivity: Date
}

// MARK: - Session Monitor

final class SessionMonitor {
    static let shared = SessionMonitor()

    private let registry: SessionProviderRegistry
    private let scanLock = NSLock()

    init(registry: SessionProviderRegistry = SessionProviderRegistry(providers: [
        ClaudeCodeSessionProvider(),
        ClaudeDesignSessionProvider(),
        CodexSessionProvider(),
        OpenCodeSessionProvider(),
        PencilSessionProvider()
    ])) {
        self.registry = registry
    }

    func scanSessions() -> [CodingSession] {
        scanSessionBreakdown().sessions
    }

    func scanSessionBreakdown() -> SessionScanBreakdown {
        scanLock.lock()
        defer { scanLock.unlock() }

        let scans = registry.scanAll()

        var sessions = scans.flatMap(\.result.sessions)
        sessions.sort { lhs, rhs in
            if lhs.pulse != rhs.pulse { return lhs.pulse.rawValue > rhs.pulse.rawValue }
            return lhs.lastActivity > rhs.lastActivity
        }

        return SessionScanBreakdown(
            sessions: sessions,
            providerDurations: Dictionary(uniqueKeysWithValues: scans.map { ($0.provider.id, $0.duration) }),
            codexCacheHits: scans.reduce(0) { $0 + ($1.result.cacheHits["codex"] ?? 0) },
            codexFileListCacheHits: scans.reduce(0) { $0 + ($1.result.cacheHits["codex-file-list"] ?? 0) },
            openCodeCacheHits: scans.reduce(0) { $0 + ($1.result.cacheHits["opencode"] ?? 0) }
        )
    }

}
