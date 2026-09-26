import Foundation

enum VideoDemoMode: String, Equatable {
    case overview
    case one
    case three

    static func parse(arguments: [String]) -> VideoDemoMode? {
#if DEBUG
        guard let flagIndex = arguments.firstIndex(of: "--video-demo") else {
            return nil
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }
        return VideoDemoMode(rawValue: arguments[valueIndex])
#else
        return nil
#endif
    }

    func sessions(now: Date) -> [CodingSession] {
        switch self {
        case .overview:
            return [
                makeSession(
                    id: "demo-claude",
                    tool: .claudeCode,
                    title: "Build launch sequence",
                    status: .working,
                    signal: .tooling,
                    pulse: .hot,
                    now: now
                ),
                makeSession(
                    id: "demo-codex",
                    tool: .codex,
                    title: "Approve release copy",
                    status: .waitingForInput,
                    signal: .awaitingUser,
                    pulse: .warm,
                    now: now.addingTimeInterval(-1)
                ),
                makeSession(
                    id: "demo-opencode",
                    tool: .openCode,
                    title: "Export product trailer",
                    status: .completed,
                    signal: .completed,
                    pulse: .sleeping,
                    now: now.addingTimeInterval(-2)
                )
            ]
        case .one:
            return [
                makeSession(
                    id: "demo-claude",
                    tool: .claudeCode,
                    title: "Build launch sequence",
                    status: .working,
                    signal: .tooling,
                    pulse: .hot,
                    now: now
                )
            ]
        case .three:
            return [
                makeSession(
                    id: "demo-claude",
                    tool: .claudeCode,
                    title: "Build launch sequence",
                    status: .working,
                    signal: .tooling,
                    pulse: .hot,
                    now: now
                ),
                makeSession(
                    id: "demo-codex",
                    tool: .codex,
                    title: "Review session routing",
                    status: .working,
                    signal: .reasoning,
                    pulse: .hot,
                    now: now.addingTimeInterval(-1)
                ),
                makeSession(
                    id: "demo-opencode",
                    tool: .openCode,
                    title: "Render final timeline",
                    status: .working,
                    signal: .responding,
                    pulse: .hot,
                    now: now.addingTimeInterval(-2)
                )
            ]
        }
    }

    private func makeSession(
        id: String,
        tool: CodingTool,
        title: String,
        status: SessionStatus,
        signal: SessionSignal,
        pulse: SessionPulse,
        now: Date
    ) -> CodingSession {
        CodingSession(
            id: id,
            tool: tool,
            projectPath: "/tmp/tachi-video-demo",
            slug: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            taskTitle: title,
            taskSummary: nil,
            status: status,
            lastActivity: now,
            signal: signal,
            pulse: pulse
        )
    }
}
