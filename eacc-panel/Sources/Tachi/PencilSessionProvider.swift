import Foundation

struct PencilSessionProvider: CodingSessionProvider {
    let id = "pencil"
    let displayName = "Pencil"
    let tool = CodingTool.pencil

    private let processRunner: any ProcessListingRunning

    init(processRunner: any ProcessListingRunning = ShellProcessListingRunner()) {
        self.processRunner = processRunner
    }

    func scanSessions(now: Date) -> SessionProviderResult {
        let lines = processRunner.processLines()
        let pencilLines = lines.filter { $0.contains("/Applications/Pencil.app/") }
        guard pencilLines.contains(where: { $0.contains("/Contents/MacOS/Pencil") }) else {
            return SessionProviderResult(sessions: [])
        }

        let agents = pencilLines
            .compactMap(agentName)
            .removingDuplicates()
            .sorted()
        let summary = agents.isEmpty
            ? "Pencil desktop is running"
            : "Connected agents: \(agents.joined(separator: ", "))"

        return SessionProviderResult(sessions: [
            CodingSession(
                id: "pencil-desktop",
                tool: .pencil,
                projectPath: "Pencil",
                slug: agents.joined(separator: ","),
                taskTitle: "Pencil Desktop",
                taskSummary: summary,
                status: .idle,
                lastActivity: now,
                signal: .quiet,
                pulse: .drowsy
            )
        ])
    }

    private func agentName(from line: String) -> String? {
        guard let range = line.range(of: "--agent ") else { return nil }
        let tail = line[range.upperBound...]
        return tail
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
