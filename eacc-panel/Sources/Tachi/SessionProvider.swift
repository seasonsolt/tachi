import Foundation

struct SessionProviderResult {
    let sessions: [CodingSession]
    let cacheHits: [String: Int]

    init(sessions: [CodingSession], cacheHits: [String: Int] = [:]) {
        self.sessions = sessions
        self.cacheHits = cacheHits
    }
}

protocol CodingSessionProvider {
    var id: String { get }
    var displayName: String { get }
    var tool: CodingTool { get }

    func scanSessions(now: Date) -> SessionProviderResult
}

struct SessionProviderScan {
    let provider: any CodingSessionProvider
    let result: SessionProviderResult
    let duration: TimeInterval
}

struct SessionProviderRegistry {
    let providers: [any CodingSessionProvider]

    func scanAll(now: Date = Date()) -> [SessionProviderScan] {
        providers.map { provider in
            let start = Date()
            let result = provider.scanSessions(now: now)
            return SessionProviderScan(
                provider: provider,
                result: result,
                duration: Date().timeIntervalSince(start)
            )
        }
    }
}

struct ClosureSessionProvider: CodingSessionProvider {
    let id: String
    let displayName: String
    let tool: CodingTool
    private let scan: (Date) -> SessionProviderResult

    init(
        id: String,
        displayName: String,
        tool: CodingTool,
        scan: @escaping (Date) -> SessionProviderResult
    ) {
        self.id = id
        self.displayName = displayName
        self.tool = tool
        self.scan = scan
    }

    func scanSessions(now: Date) -> SessionProviderResult {
        scan(now)
    }
}

protocol ProcessListingRunning {
    func processLines() -> [String]
}

struct ShellProcessListingRunner: ProcessListingRunning {
    func processLines() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["ax", "-o", "pid=,args="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8)
        else { return [] }

        return output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }
}
