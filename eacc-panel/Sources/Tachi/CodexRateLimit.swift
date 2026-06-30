import Foundation

struct CodexRateLimitWindow: Equatable, Sendable {
    enum Kind: String, Sendable {
        case primary
        case secondary
    }

    let kind: Kind
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: Date

    var remainingPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }

    var validityLabel: String {
        Self.formatWindow(minutes: windowMinutes)
    }

    private static func formatWindow(minutes: Int) -> String {
        if minutes >= 10_080, minutes % 10_080 == 0 {
            return "\(minutes / 10_080)w"
        }
        if minutes >= 1_440, minutes % 1_440 == 0 {
            return "\(minutes / 1_440)d"
        }
        if minutes >= 60, minutes % 60 == 0 {
            return "\(minutes / 60)h"
        }
        return "\(minutes)m"
    }
}

struct CodexResetCredit: Equatable, Sendable {
    let status: String
    let expiresAt: Date?

    var isAvailable: Bool {
        status.caseInsensitiveCompare("available") == .orderedSame
    }
}

struct CodexResetCreditsResponse: Equatable, Sendable {
    let availableCount: Int
    let credits: [CodexResetCredit]

    var availableCredits: [CodexResetCredit] {
        credits
            .filter(\.isAvailable)
            .sorted { lhs, rhs in
                switch (lhs.expiresAt, rhs.expiresAt) {
                case let (left?, right?): return left < right
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return false
                }
            }
    }

    static func fromJSONData(_ data: Data) -> CodexResetCreditsResponse? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return fromJSONObject(json)
    }

    static func fromJSONObject(_ json: [String: Any]) -> CodexResetCreditsResponse? {
        let rawCredits = json["credits"] as? [[String: Any]] ?? []
        let credits = rawCredits.compactMap { raw -> CodexResetCredit? in
            let status = stringValue(raw["status"]) ?? "unknown"
            let expiresAt = parseCodexDate(stringValue(raw["expires_at"] ?? raw["expiresAt"]))
            return CodexResetCredit(status: status, expiresAt: expiresAt)
        }
        let availableCount = intValue(json["available_count"] ?? json["availableCount"])
            ?? credits.filter(\.isAvailable).count

        return CodexResetCreditsResponse(
            availableCount: availableCount,
            credits: credits
        )
    }
}

struct CodexRateLimitSnapshot: Equatable, Sendable {
    let limitId: String?
    let limitName: String?
    let windows: [CodexRateLimitWindow]
    let resetCreditCount: Int?
    let resetCredits: [CodexResetCredit]

    init(
        limitId: String? = nil,
        limitName: String?,
        windows: [CodexRateLimitWindow],
        resetCreditCount: Int? = nil,
        resetCredits: [CodexResetCredit] = []
    ) {
        self.limitId = limitId
        self.limitName = limitName
        self.windows = windows
        self.resetCreditCount = resetCreditCount
        self.resetCredits = resetCredits
    }

    var validityLabel: String {
        windows.map(\.validityLabel).joined(separator: " / ")
    }

    var availableResetCredits: [CodexResetCredit] {
        resetCredits
            .filter(\.isAvailable)
            .sorted { lhs, rhs in
                switch (lhs.expiresAt, rhs.expiresAt) {
                case let (left?, right?): return left < right
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return false
                }
            }
    }

    func withResetCredits(_ response: CodexResetCreditsResponse?) -> CodexRateLimitSnapshot {
        guard let response else { return self }
        return CodexRateLimitSnapshot(
            limitId: limitId,
            limitName: limitName,
            windows: windows,
            resetCreditCount: response.availableCount,
            resetCredits: response.credits
        )
    }

    static func fromResetCredits(_ response: CodexResetCreditsResponse) -> CodexRateLimitSnapshot {
        CodexRateLimitSnapshot(
            limitName: "OpenAI Codex",
            windows: [],
            resetCreditCount: response.availableCount,
            resetCredits: response.credits
        )
    }

    static func fromAppServerResponse(_ response: [String: Any], preferredLimitId: String = "codex") -> CodexRateLimitSnapshot? {
        let result = (response["result"] as? [String: Any]) ?? response
        let byLimitId = dictionaryValue(result["rateLimitsByLimitId"] ?? result["rate_limits_by_limit_id"])
        let preferred = dictionaryValue(byLimitId?[preferredLimitId])
        let fallback = dictionaryValue(result["rateLimits"] ?? result["rate_limits"])
        guard let snapshot = preferred ?? fallback else { return nil }

        var windows: [CodexRateLimitWindow] = []
        for kind in [CodexRateLimitWindow.Kind.primary, .secondary] {
            guard let raw = dictionaryValue(snapshot[kind.rawValue]),
                  let usedPercent = doubleValue(raw["usedPercent"] ?? raw["used_percent"]),
                  let resetSeconds = doubleValue(raw["resetsAt"] ?? raw["resets_at"])
            else { continue }

            let windowMinutes = intValue(raw["windowDurationMins"] ?? raw["window_minutes"]) ?? defaultWindowMinutes(for: kind)
            windows.append(
                CodexRateLimitWindow(
                    kind: kind,
                    usedPercent: usedPercent,
                    windowMinutes: windowMinutes,
                    resetsAt: Date(timeIntervalSince1970: resetSeconds)
                )
            )
        }

        guard !windows.isEmpty else { return nil }
        let credits = dictionaryValue(result["rateLimitResetCredits"] ?? result["rate_limit_reset_credits"])
        return CodexRateLimitSnapshot(
            limitId: stringValue(snapshot["limitId"] ?? snapshot["limit_id"]),
            limitName: stringValue(snapshot["limitName"] ?? snapshot["limit_name"]),
            windows: windows,
            resetCreditCount: intValue(credits?["availableCount"] ?? credits?["available_count"])
        )
    }
}

final class CodexResetCreditsClient: @unchecked Sendable {
    static let shared = CodexResetCreditsClient()

    private let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!

    func fetch(timeout: TimeInterval = 10) async -> CodexResetCreditsResponse? {
        guard let context = loadAuthContext() else { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
        request.setValue("CODEX", forHTTPHeaderField: "OAI-Product-Sku")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountId = context.accountId {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  !data.isEmpty
            else { return nil }
            return CodexResetCreditsResponse.fromJSONData(data)
        } catch {
            return nil
        }
    }

    private func loadAuthContext() -> (accessToken: String, accountId: String?)? {
        let authPath = resolvedCodexHome().appendingPathComponent("auth.json").path
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: authPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty
        else { return nil }

        let auth = jwtAuthPayload(from: accessToken)
        let accountId = auth?["chatgpt_account_id"] as? String
            ?? tokens["account_id"] as? String
        return (accessToken, accountId)
    }

    private func resolvedCodexHome() -> URL {
        if let value = ProcessInfo.processInfo.environment["CODEX_HOME"], !value.isEmpty {
            return URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }
}

final class CodexAppServerRateLimitClient: @unchecked Sendable {
    static let shared = CodexAppServerRateLimitClient()

    private let lock = NSLock()
    private var cached: (snapshot: CodexRateLimitSnapshot, fetchedAt: Date)?

    func fetchCached(maxAge: TimeInterval = 60, timeout: TimeInterval = 10) -> CodexRateLimitSnapshot? {
        let now = Date()
        lock.lock()
        if let cached, now.timeIntervalSince(cached.fetchedAt) < maxAge {
            lock.unlock()
            return cached.snapshot
        }
        lock.unlock()

        guard let snapshot = fetch(timeout: timeout) else { return nil }

        lock.lock()
        cached = (snapshot, Date())
        lock.unlock()
        return snapshot
    }

    func fetch(timeout: TimeInterval = 10) -> CodexRateLimitSnapshot? {
        guard let executable = resolveCodexExecutable() else { return nil }

        let process = Process()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.environment = appServerEnvironment()

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        let stateLock = NSLock()
        let semaphore = DispatchSemaphore(value: 0)
        var buffer = ""
        var snapshot: CodexRateLimitSnapshot?
        var completed = false

        func complete(with value: CodexRateLimitSnapshot?) {
            stateLock.lock()
            guard !completed else {
                stateLock.unlock()
                return
            }
            completed = true
            snapshot = value
            stateLock.unlock()
            semaphore.signal()
        }

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

            stateLock.lock()
            buffer += chunk
            let parts = buffer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            buffer = parts.last ?? ""
            let lines = parts.dropLast()
            stateLock.unlock()

            for line in lines {
                guard let data = line.data(using: .utf8),
                      let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let id = message["id"] as? Int,
                      id == 2
                else { continue }
                complete(with: CodexRateLimitSnapshot.fromAppServerResponse(message))
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

        do {
            try process.run()
            try writeJSONLine(
                [
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "initialize",
                    "params": [
                        "clientInfo": [
                            "name": "tachi",
                            "title": "Tachi",
                            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
                        ],
                        "capabilities": [
                            "experimentalApi": true,
                            "requestAttestation": false,
                        ],
                    ],
                ],
                to: stdin.fileHandleForWriting
            )
            try writeJSONLine(
                [
                    "jsonrpc": "2.0",
                    "id": 2,
                    "method": "account/rateLimits/read",
                ],
                to: stdin.fileHandleForWriting
            )
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            return nil
        }

        let result = semaphore.wait(timeout: .now() + timeout)
        if result == .timedOut {
            process.terminate()
        }

        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        try? stdin.fileHandleForWriting.close()
        if process.isRunning {
            process.terminate()
        }
        process.waitUntilExit()
        return snapshot
    }

    private func resolveCodexExecutable() -> URL? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.codex/packages/standalone/current/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/.bun/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
        ]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        return nil
    }

    private func appServerEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let additions = [
            "\(home)/.codex/packages/standalone/current",
            "\(home)/.bun/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = (additions + [existingPath]).filter { !$0.isEmpty }.joined(separator: ":")
        return environment
    }

    private func writeJSONLine(_ value: [String: Any], to handle: FileHandle) throws {
        let data = try JSONSerialization.data(withJSONObject: value)
        handle.write(data)
        handle.write(Data([0x0A]))
    }
}

private func defaultWindowMinutes(for kind: CodexRateLimitWindow.Kind) -> Int {
    switch kind {
    case .primary: return 300
    case .secondary: return 10_080
    }
}

private func dictionaryValue(_ raw: Any?) -> [String: Any]? {
    raw as? [String: Any]
}

private func stringValue(_ raw: Any?) -> String? {
    raw as? String
}

private func doubleValue(_ raw: Any?) -> Double? {
    if let value = raw as? Double { return value }
    if let value = raw as? Int { return Double(value) }
    if let value = raw as? NSNumber { return value.doubleValue }
    return nil
}

private func intValue(_ raw: Any?) -> Int? {
    if let value = raw as? Int { return value }
    if let value = raw as? Double { return Int(value) }
    if let value = raw as? NSNumber { return value.intValue }
    return nil
}

private func parseCodexDate(_ raw: String?) -> Date? {
    guard let raw, !raw.isEmpty else { return nil }
    if let date = codexISOFormatterFractional.date(from: raw) {
        return date
    }
    return codexISOFormatter.date(from: raw)
}

private let codexISOFormatterFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private let codexISOFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

private func jwtAuthPayload(from token: String) -> [String: Any]? {
    let parts = token.split(separator: ".")
    guard parts.count >= 2,
          let data = Data(base64URLString: String(parts[1])),
          let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return payload["https://api.openai.com/auth"] as? [String: Any]
}

private extension Data {
    init?(base64URLString value: String) {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = base64.count % 4
        if padding > 0 {
            base64 += String(repeating: "=", count: 4 - padding)
        }
        self.init(base64Encoded: base64)
    }
}
