import Foundation
import SwiftUI

@Observable
final class ViewModel {
    var items: [AccountWithUsage] = []
    var sessions: [CodingSession] = []
    var isLoading = true
    var lastUpdated: Date?
    var testStates: [Int: TestState] = [:]

    var activeSessions: [CodingSession] {
        sessions.filter { $0.status == .working || $0.status == .waitingForInput }
    }

    /// Weighted average utilization across all accounts (weighted by activity)
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

    var statusColor: Color {
        let v = weightedUtil
        if v <= 30 { return .green }
        if v <= 70 { return .orange }
        return .red
    }

    var statusEmoji: String {
        let v = weightedUtil
        if v <= 30 { return "\u{1F7E2}" }
        if v <= 70 { return "\u{1F7E1}" }
        return "\u{1F534}"
    }

    var menuBarText: String {
        let working = activeSessions.filter { $0.status == .working }.count
        if working > 0 {
            return "\(statusEmoji) \(weightedUtil)% [\(working)]"
        }
        return "\(statusEmoji) \(weightedUtil)%"
    }

    @MainActor
    func refresh() async {
        async let usageTask: () = refreshUsage()
        async let sessionsTask: () = refreshSessions()
        _ = await (usageTask, sessionsTask)
        lastUpdated = Date()
        isLoading = false
    }

    @MainActor
    private func refreshUsage() async {
        let api = APIClient.shared
        let accounts = await api.fetchAccounts()
        guard !accounts.isEmpty else { return }
        var results: [AccountWithUsage] = []
        for acc in accounts {
            let usage = await api.fetchUsage(accountId: acc.id)
            results.append(AccountWithUsage(id: acc.id, account: acc, usage: usage))
        }
        items = results.sorted { $0.maxUtilization > $1.maxUtilization }
    }

    @MainActor
    private func refreshSessions() async {
        sessions = await Task.detached {
            SessionMonitor.shared.scanSessions()
        }.value
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
