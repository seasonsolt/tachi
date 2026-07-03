import XCTest
@testable import Tachi

final class SessionProviderTests: XCTestCase {
    func testRegistryScansAllProvidersWithTiming() {
        let now = Date(timeIntervalSince1970: 100)
        let providers: [CodingSessionProvider] = [
            StaticSessionProvider(
                id: "first",
                displayName: "First",
                tool: .codex,
                sessions: [
                    CodingSession(
                        id: "codex-1",
                        tool: .codex,
                        projectPath: "/tmp/project",
                        slug: "project",
                        taskTitle: "Build provider registry",
                        taskSummary: nil,
                        status: .working,
                        lastActivity: now,
                        signal: .booting,
                        pulse: .hot
                    )
                ]
            ),
            StaticSessionProvider(id: "second", displayName: "Second", tool: .openCode, sessions: [])
        ]

        let scans = SessionProviderRegistry(providers: providers).scanAll(now: now)

        XCTAssertEqual(scans.map(\.provider.id), ["first", "second"])
        XCTAssertEqual(scans.flatMap(\.result.sessions).map(\.id), ["codex-1"])
        XCTAssertEqual(scans.count, 2)
        XCTAssertTrue(scans.allSatisfy { $0.duration >= 0 })
    }

    func testSessionMonitorKeepsProviderInstancesAcrossScans() {
        let provider = StatefulCacheProvider()
        let monitor = SessionMonitor(registry: SessionProviderRegistry(providers: [provider]))

        _ = monitor.scanSessionBreakdown()
        let second = monitor.scanSessionBreakdown()

        XCTAssertEqual(second.codexCacheHits, 1)
        XCTAssertEqual(second.codexFileListCacheHits, 1)
    }

    func testCodingSessionMapsToWireSessionInfo() {
        let date = Date(timeIntervalSince1970: 200)
        let session = CodingSession(
            id: "pencil-desktop",
            tool: .pencil,
            projectPath: "Pencil",
            slug: "codexCLI",
            taskTitle: "Pencil Desktop",
            taskSummary: "Connected agents: codexCLI",
            status: .idle,
            lastActivity: date,
            signal: .quiet,
            pulse: .drowsy
        )

        let info = EACCSessionInfo(session: session)

        XCTAssertEqual(info.pid, 0)
        XCTAssertEqual(info.sessionId, "pencil-desktop")
        XCTAssertEqual(info.cwd, "Pencil")
        XCTAssertEqual(info.startedAt, 200000)
        XCTAssertTrue(info.alive)
        XCTAssertEqual(info.tool, "pencil")
        XCTAssertEqual(info.taskTitle, "Pencil Desktop")
        XCTAssertEqual(info.taskSummary, "Connected agents: codexCLI")
    }

    func testClaudeDesignSessionMapsToWireSessionInfo() {
        let session = CodingSession(
            id: "claude-design-1",
            tool: .claudeDesign,
            projectPath: "/tmp/tachi",
            slug: "design-popup",
            taskTitle: "Design taskbar popup",
            taskSummary: "Optimize smiling boy theme",
            status: .working,
            lastActivity: Date(timeIntervalSince1970: 220),
            signal: .booting,
            pulse: .warm
        )

        let info = EACCSessionInfo(session: session)

        XCTAssertEqual(info.tool, "claude_design")
    }

    func testWaitingCompanionRemainsVisibleButStopsMotion() {
        let vm = ViewModel()
        vm.sessions = [
            CodingSession(
                id: "paused-claude",
                tool: .claudeCode,
                projectPath: "/tmp/tachi",
                slug: "paused-task",
                taskTitle: "Paused task",
                taskSummary: nil,
                status: .waitingForInput,
                lastActivity: Date(timeIntervalSince1970: 200),
                signal: .awaitingUser,
                pulse: .warm
            )
        ]

        XCTAssertTrue(vm.shouldShowCompanionTaskPreview)
        XCTAssertEqual(vm.companionMood, .expecting)
        XCTAssertFalse(vm.companionHasMotion)

        vm.menuAnimationFrame = 0
        let calmMenuBarText = vm.menuBarText
        vm.menuAnimationFrame = 1
        XCTAssertEqual(vm.menuBarText, calmMenuBarText)
    }

    func testPencilProviderAggregatesMainProcessAndConnectedAgents() throws {
        let now = Date(timeIntervalSince1970: 200)
        let provider = PencilSessionProvider(processRunner: StubProcessListingRunner(lines: [
            "50268 /Applications/Pencil.app/Contents/MacOS/Pencil",
            "35281 /Applications/Pencil.app/Contents/Resources/app.asar.unpacked/out/mcp-server-darwin-arm64 --app desktop --agent codexCLI",
            "8437 /Applications/Pencil.app/Contents/Resources/app.asar.unpacked/out/mcp-server-darwin-arm64 --app desktop --agent openCodeCLI"
        ]))

        let result = provider.scanSessions(now: now)

        XCTAssertEqual(result.sessions.count, 1)
        let session = try XCTUnwrap(result.sessions.first)
        XCTAssertEqual(session.id, "pencil-desktop")
        XCTAssertEqual(session.tool, .pencil)
        XCTAssertEqual(session.projectPath, "Pencil")
        XCTAssertEqual(session.taskTitle, "Pencil Desktop")
        XCTAssertEqual(session.taskSummary, "Connected agents: codexCLI, openCodeCLI")
        XCTAssertEqual(session.status, .idle)
        XCTAssertEqual(session.lastActivity, now)
        XCTAssertEqual(session.signal, .quiet)
        XCTAssertEqual(session.pulse, .drowsy)
    }

    func testPencilProviderReturnsNoSessionsWhenPencilIsNotRunning() {
        let provider = PencilSessionProvider(processRunner: StubProcessListingRunner(lines: [
            "13393 /Applications/Codex.app/Contents/MacOS/Codex"
        ]))

        XCTAssertTrue(provider.scanSessions(now: Date()).sessions.isEmpty)
    }

    func testOpenCodeProviderReadsRecentSessionsFromSQLiteDatabase() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("opencode.db")
        try runSQLite(
            database: dbURL.path,
            sql: """
            create table session (
              id text,
              slug text,
              directory text,
              title text,
              time_created integer,
              time_updated integer,
              time_archived integer
            );
            create table message (
              session_id text,
              data text,
              time_updated integer
            );
            insert into session values (
              'oc-1',
              'build-provider-plugin',
              '/tmp/tachi',
              'Build provider plugin',
              200000,
              200000,
              null
            );
            insert into message values (
              'oc-1',
              '{"role":"user","content":"Monitor OpenCode through a provider","time":{"created":200000,"completed":200000}}',
              200000
            );
            """
        )

        let provider = OpenCodeSessionProvider(databasePath: dbURL.path)
        let result = provider.scanSessions(now: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(result.sessions.count, 1)
        let session = try XCTUnwrap(result.sessions.first)
        XCTAssertEqual(session.id, "oc-1")
        XCTAssertEqual(session.tool, .openCode)
        XCTAssertEqual(session.projectPath, "/tmp/tachi")
        XCTAssertEqual(session.taskTitle, "Build provider plugin")
        XCTAssertEqual(session.taskSummary, "Monitor OpenCode through a provider")
        XCTAssertEqual(session.signal, .booting)
        XCTAssertEqual(session.pulse, .hot)
    }

    func testOpenCodeProviderReusesUnchangedDatabaseSnapshot() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("opencode.db")
        try runSQLite(
            database: dbURL.path,
            sql: """
            create table session (
              id text,
              slug text,
              directory text,
              title text,
              time_created integer,
              time_updated integer,
              time_archived integer
            );
            create table message (
              session_id text,
              data text,
              time_updated integer
            );
            insert into session values ('oc-1', 'provider-cache', '/tmp/tachi', 'Provider cache', 200000, 200000, null);
            """
        )

        let provider = OpenCodeSessionProvider(databasePath: dbURL.path)
        _ = provider.scanSessions(now: Date(timeIntervalSince1970: 200))
        let cached = provider.scanSessions(now: Date(timeIntervalSince1970: 205))

        XCTAssertEqual(cached.cacheHits["opencode"], 1)
        XCTAssertEqual(cached.sessions.map(\.id), ["oc-1"])
    }

    func testCodexProviderReadsThreadNameWorkspaceAndPrompt() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionsDir = tempDir.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let indexURL = tempDir.appendingPathComponent("session_index.jsonl")
        try """
        {"id":"codex-1","thread_name":"重构 mac App 性能","updated_at":"1970-01-01T00:03:20Z"}
        """.write(to: indexURL, atomically: true, encoding: .utf8)

        let sessionURL = sessionsDir.appendingPathComponent("rollout-codex-1.jsonl")
        try """
        {"type":"session_meta","payload":{"id":"codex-1","cwd":"/tmp/tachi"}}
        {"timestamp":"1970-01-01T00:03:20Z","type":"turn_context","payload":{"cwd":"/tmp/tachi"}}
        {"timestamp":"1970-01-01T00:03:20Z","type":"event_msg","payload":{"type":"user_message","message":"## My request for Codex:\\nBuild plugin providers"}}
        """.write(to: sessionURL, atomically: true, encoding: .utf8)

        let provider = CodexSessionProvider(indexPath: indexURL.path, sessionsPath: sessionsDir.path)
        let result = provider.scanSessions(now: Date(timeIntervalSince1970: 220))

        XCTAssertEqual(result.sessions.count, 1)
        let session = try XCTUnwrap(result.sessions.first)
        XCTAssertEqual(session.id, "codex-1")
        XCTAssertEqual(session.tool, .codex)
        XCTAssertEqual(session.projectPath, "/tmp/tachi")
        XCTAssertEqual(session.taskTitle, "重构 mac App 性能")
        XCTAssertEqual(session.taskSummary, "Build plugin providers")
        XCTAssertEqual(session.signal, .booting)
        XCTAssertEqual(session.pulse, .warm)
    }

    func testCodexProviderReusesUnchangedSessionFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionsDir = tempDir.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let indexURL = tempDir.appendingPathComponent("session_index.jsonl")
        try """
        {"id":"codex-1","thread_name":"Provider cache","updated_at":"1970-01-01T00:03:20Z"}
        """.write(to: indexURL, atomically: true, encoding: .utf8)

        let sessionURL = sessionsDir.appendingPathComponent("rollout-codex-1.jsonl")
        try """
        {"type":"session_meta","payload":{"id":"codex-1","cwd":"/tmp/tachi"}}
        {"timestamp":"1970-01-01T00:03:20Z","type":"event_msg","payload":{"type":"user_message","message":"Cache Codex scans"}}
        """.write(to: sessionURL, atomically: true, encoding: .utf8)

        let provider = CodexSessionProvider(indexPath: indexURL.path, sessionsPath: sessionsDir.path)
        _ = provider.scanSessions(now: Date(timeIntervalSince1970: 220))
        let cached = provider.scanSessions(now: Date(timeIntervalSince1970: 225))

        XCTAssertEqual(cached.cacheHits["codex"], 1)
        XCTAssertEqual(cached.cacheHits["codex-file-list"], 1)
        XCTAssertEqual(cached.sessions.map(\.id), ["codex-1"])
    }

    func testClaudeCodeProviderReadsRecentProjectJsonl() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectDir = tempDir.appendingPathComponent("-tmp-tachi", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sessionURL = projectDir.appendingPathComponent("claude-1.jsonl")
        try """
        {"timestamp":"1970-01-01T00:03:20Z","type":"user","cwd":"/tmp/tachi","slug":"build-plugin-provider","message":"Build Claude provider"}
        """.write(to: sessionURL, atomically: true, encoding: .utf8)

        let provider = ClaudeCodeSessionProvider(projectsPath: tempDir.path)
        let result = provider.scanSessions(now: Date(timeIntervalSince1970: 220))

        XCTAssertEqual(result.sessions.count, 1)
        let session = try XCTUnwrap(result.sessions.first)
        XCTAssertEqual(session.id, "claude-1")
        XCTAssertEqual(session.tool, .claudeCode)
        XCTAssertEqual(session.projectPath, "/tmp/tachi")
        XCTAssertEqual(session.taskTitle, "build-plugin-provider")
        XCTAssertEqual(session.taskSummary, "Build Claude provider")
        XCTAssertEqual(session.signal, .booting)
        XCTAssertEqual(session.pulse, .warm)
    }

    func testClaudeCodeProviderKeepsNewestSessionPerProject() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectDir = tempDir.appendingPathComponent("-tmp-tachi", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try """
        {"timestamp":"1970-01-01T00:02:00Z","type":"assistant","cwd":"/tmp/tachi","slug":"older","message":"old"}
        """.write(to: projectDir.appendingPathComponent("older.jsonl"), atomically: true, encoding: .utf8)
        try """
        {"timestamp":"1970-01-01T00:03:20Z","type":"user","cwd":"/tmp/tachi","slug":"newer","message":"new"}
        """.write(to: projectDir.appendingPathComponent("newer.jsonl"), atomically: true, encoding: .utf8)

        let provider = ClaudeCodeSessionProvider(projectsPath: tempDir.path)
        let result = provider.scanSessions(now: Date(timeIntervalSince1970: 220))

        XCTAssertEqual(result.sessions.map(\.id), ["newer"])
    }

    func testClaudeDesignProviderReadsDesktopLaunchedProjectJsonl() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectDir = tempDir.appendingPathComponent("-tmp-tachi-design", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sessionURL = projectDir.appendingPathComponent("design-1.jsonl")
        try """
        {"timestamp":"1970-01-01T00:03:20Z","type":"user","entrypoint":"claude-desktop","cwd":"/tmp/tachi-design","slug":"design-taskbar-popup","message":{"role":"user","content":"Design the taskbar popup"}}
        """.write(to: sessionURL, atomically: true, encoding: .utf8)

        let provider = ClaudeDesignSessionProvider(projectsPath: tempDir.path)
        let result = provider.scanSessions(now: Date(timeIntervalSince1970: 220))

        XCTAssertEqual(result.sessions.count, 1)
        let session = try XCTUnwrap(result.sessions.first)
        XCTAssertEqual(session.id, "design-1")
        XCTAssertEqual(session.tool, .claudeDesign)
        XCTAssertEqual(session.projectPath, "/tmp/tachi-design")
        XCTAssertEqual(session.taskTitle, "design-taskbar-popup")
        XCTAssertEqual(session.taskSummary, "Design the taskbar popup")
        XCTAssertEqual(session.signal, .booting)
        XCTAssertEqual(session.pulse, .warm)
    }

    func testClaudeCodeProviderSkipsDesktopLaunchedProjectJsonl() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectDir = tempDir.appendingPathComponent("-tmp-tachi-design", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try """
        {"timestamp":"1970-01-01T00:03:20Z","type":"user","entrypoint":"claude-desktop","cwd":"/tmp/tachi-design","slug":"design-taskbar-popup","message":"Design the taskbar popup"}
        """.write(to: projectDir.appendingPathComponent("design-1.jsonl"), atomically: true, encoding: .utf8)

        let provider = ClaudeCodeSessionProvider(projectsPath: tempDir.path)
        let result = provider.scanSessions(now: Date(timeIntervalSince1970: 220))

        XCTAssertTrue(result.sessions.isEmpty)
    }
}

private struct StaticSessionProvider: CodingSessionProvider {
    let id: String
    let displayName: String
    let tool: CodingTool
    let sessions: [CodingSession]

    func scanSessions(now: Date) -> SessionProviderResult {
        SessionProviderResult(sessions: sessions)
    }
}

private struct StubProcessListingRunner: ProcessListingRunning {
    let lines: [String]

    func processLines() -> [String] {
        lines
    }
}

private final class StatefulCacheProvider: CodingSessionProvider {
    let id = "codex"
    let displayName = "Codex"
    let tool = CodingTool.codex
    private var scans = 0

    func scanSessions(now: Date) -> SessionProviderResult {
        scans += 1
        let cacheHits = scans > 1 ? ["codex": 1, "codex-file-list": 1] : [:]
        return SessionProviderResult(sessions: [], cacheHits: cacheHits)
    }
}

private func runSQLite(database: String, sql: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [database, sql]

    let errorPipe = Pipe()
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTFail("sqlite3 failed: \(error)")
    }
}
