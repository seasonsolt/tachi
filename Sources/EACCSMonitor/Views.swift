import SwiftUI

// MARK: - Content View

struct ContentView: View {
    var vm: ViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if vm.isLoading && vm.items.isEmpty {
                loadingView
            } else {
                scrollContent
            }
            Divider()
            footer
        }
        .frame(width: 400)
        .task {
            await vm.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Config.refreshInterval))
                await vm.refresh()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("EACCS Monitor")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            if let date = vm.lastUpdated {
                Text(date, style: .time)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Button {
                Task { await vm.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Refresh")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading accounts...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
    }

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if !vm.sessions.isEmpty {
                    sessionsSection
                }
                accountsSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(maxHeight: 620)
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Active Sessions")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                let working = vm.sessions.filter { $0.status == .working }.count
                if working > 0 {
                    Text("\(working) running")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 4)

            ForEach(vm.sessions) { session in
                SessionRow(session: session)
            }
        }
        .padding(.bottom, 4)
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Usage")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            ForEach(vm.items) { item in
                AccountCard(item: item, testState: vm.testStates[item.id] ?? .idle) {
                    Task { await vm.runTest(accountId: item.id) }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Account Card

struct AccountCard: View {
    let item: AccountWithUsage
    let testState: TestState
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            accountHeader
            if let usage = item.usage {
                usageContent(usage)
            } else {
                unavailableBadge
            }
            testSection
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private var accountHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: item.account.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(platformGradient)
                .frame(width: 20)
            Text(item.account.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Spacer()
            Text("\(item.maxUtilization)%")
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(colorForUtil(item.maxUtilization))
        }
    }

    private var platformGradient: some ShapeStyle {
        switch item.account.platform {
        case "openai":
            return AnyShapeStyle(
                .linearGradient(
                    colors: [Color(red: 0.29, green: 0.84, blue: 0.63), Color(red: 0.07, green: 0.6, blue: 0.45)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        case "anthropic":
            return AnyShapeStyle(
                .linearGradient(
                    colors: [Color(red: 0.82, green: 0.62, blue: 0.47), Color(red: 0.65, green: 0.4, blue: 0.28)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        case "antigravity":
            return AnyShapeStyle(
                .linearGradient(
                    colors: [Color(red: 0.4, green: 0.52, blue: 0.96), Color(red: 0.28, green: 0.35, blue: 0.78)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        default:
            return AnyShapeStyle(.secondary)
        }
    }

    @ViewBuilder
    private func usageContent(_ usage: UsageData) -> some View {
        switch usage {
        case .openai(let fh, let sd):
            openAIContent(fh: fh, sd: sd)
        case .antigravity(let fh, let models, let tier, let credits):
            antigravityContent(fh: fh, models: models, tier: tier, credits: credits)
        }
    }

    private func openAIContent(fh: WindowUsage, sd: WindowUsage) -> some View {
        VStack(spacing: 6) {
            UtilRow(label: "5h", util: fh.utilization, remaining: fh.remainingSeconds)
            UtilRow(label: "7d", util: sd.utilization, remaining: sd.remainingSeconds)
            if fh.requests > 0 || sd.requests > 0 {
                HStack(spacing: 4) {
                    let totalReqs = fh.requests
                    let totalTokens = fh.tokens
                    Label("\(totalReqs) reqs", systemImage: "arrow.up.arrow.down")
                    Text("·")
                    Label(formatTokens(totalTokens), systemImage: "text.word.spacing")
                    Spacer()
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
    }

    private func antigravityContent(
        fh: WindowUsage, models: [ModelQuota], tier: String, credits: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !tier.isEmpty {
                HStack(spacing: 6) {
                    Text(tier)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .foregroundStyle(Color.accentColor)
                    Text("Credits: \(credits)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            UtilRow(label: "5h", util: fh.utilization, remaining: fh.remainingSeconds)

            let active = models.filter { $0.utilization > 0 }
            let idle = models.filter { $0.utilization == 0 }

            ForEach(active) { m in
                ModelRow(model: m)
            }

            if !idle.isEmpty {
                Text("\(idle.count) models at 0%")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
    }

    private var unavailableBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text("Usage data unavailable")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var testSection: some View {
        switch testState {
        case .idle:
            HStack {
                Spacer()
                Button {
                    onTest()
                } label: {
                    Label("Test", systemImage: "play.fill")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(.quaternary))
            }
        case .testing:
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
                Text("Testing...")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        case .success(let model, let text):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 11))
                    Text(model)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(text)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.green.opacity(0.08)))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        case .failure(let error):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 11))
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.red.opacity(0.08)))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

// MARK: - Utilization Row

struct UtilRow: View {
    let label: String
    let util: Int
    let remaining: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 22, alignment: .trailing)
            UtilBar(value: util)
            Text("\(util)%")
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(colorForUtil(util))
                .frame(width: 36, alignment: .trailing)
            Text(formatRemaining(remaining))
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.quaternary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: ModelQuota

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(model.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                let reset = formatResetTime(model.resetTime)
                if !reset.isEmpty {
                    Text(reset)
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(.quaternary)
                }
            }
            HStack(spacing: 8) {
                UtilBar(value: model.utilization)
                Text("\(model.utilization)%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(colorForUtil(model.utilization))
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }
}

// MARK: - Utilization Bar

struct UtilBar: View {
    let value: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary.opacity(0.5))
                if value > 0 {
                    Capsule()
                        .fill(barGradient)
                        .frame(width: max(4, geo.size.width * CGFloat(value) / 100))
                }
            }
        }
        .frame(height: 5)
    }

    private var barGradient: some ShapeStyle {
        let c = utilizationColor(value)
        let color = Color(red: c.r, green: c.g, blue: c.b)
        return AnyShapeStyle(
            .linearGradient(
                colors: [color.opacity(0.7), color],
                startPoint: .leading, endPoint: .trailing))
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: CodingSession

    var body: some View {
        HStack(spacing: 10) {
            statusIndicator
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: session.tool.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(session.projectName)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                if !session.slug.isEmpty && session.slug != session.projectName {
                    Text(session.slug)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.status.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(statusColor)
                Text(timeAgo(session.lastActivity))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(statusBorderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .fill(statusColor.opacity(0.3))
                    .frame(width: 14, height: 14)
                    .opacity(session.status == .working ? 1 : 0)
            )
    }

    private var statusColor: Color {
        switch session.status {
        case .working: return .green
        case .waitingForInput: return .orange
        case .idle: return .gray
        case .completed: return Color(red: 0.4, green: 0.52, blue: 0.96)
        }
    }

    private var statusBorderColor: Color {
        switch session.status {
        case .working: return .green.opacity(0.25)
        case .waitingForInput: return .orange.opacity(0.25)
        default: return .clear
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

// MARK: - Helpers

func colorForUtil(_ v: Int) -> Color {
    let c = utilizationColor(v)
    return Color(red: c.r, green: c.g, blue: c.b)
}
