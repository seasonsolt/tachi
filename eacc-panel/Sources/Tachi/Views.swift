import SwiftUI

// MARK: - EACC Semantic Status Colors (theme-independent)

let redAccent = Color(red: 1.0, green: 0.28, blue: 0.28)
let purpleAccent = Color(red: 0.58, green: 0.38, blue: 1.0)
let matrixGreen = Color(red: 0, green: 0.9, blue: 0.4)

private let auroraPurple = Color(red: 167.0 / 255.0, green: 139.0 / 255.0, blue: 250.0 / 255.0)
private let auroraGreen = Color(red: 52.0 / 255.0, green: 211.0 / 255.0, blue: 153.0 / 255.0)
private let auroraAmber = Color(red: 245.0 / 255.0, green: 158.0 / 255.0, blue: 11.0 / 255.0)
private let auroraRed = Color(red: 248.0 / 255.0, green: 113.0 / 255.0, blue: 113.0 / 255.0)
private let auroraMuted = Color(red: 148.0 / 255.0, green: 163.0 / 255.0, blue: 184.0 / 255.0)

// CRT scanline overlay for the Matrix skin (design .mtx-scan): thin dark
// lines every 4pt plus a bottom vignette. Shared by the menu panel and the
// companion bubble.
struct CRTScanlines: View {
    var body: some View {
        ZStack {
            Canvas { context, size in
                var y: CGFloat = 2
                while y < size.height {
                    context.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                        with: .color(Color(red: 0, green: 0.1, blue: 0.04).opacity(0.22))
                    )
                    y += 4
                }
            }
            .blendMode(.overlay)

            RadialGradient(
                colors: [.clear, Color.black.opacity(0.4)],
                center: .top,
                startRadius: 40,
                endRadius: 560
            )
            .opacity(0.55)
        }
        .allowsHitTesting(false)
    }
}

private struct RitualPanelBackdrop: View {
    let themeColors: EACCThemeColors
    let accent: Color
    let theme: EACCThemeName

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeColors.cardBg.opacity(0.98),
                    themeColors.bg.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    accent.opacity(theme == .voidTheme ? 0.04 : 0.08),
                    .clear,
                    themeColors.accentEdge.opacity(theme == .voidTheme ? 0.02 : 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    accent.opacity(theme == .voidTheme ? 0.06 : 0.15),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 18,
                endRadius: 260
            )
            .offset(x: 56, y: -42)

            RadialGradient(
                colors: [
                    themeColors.accentEdge.opacity(theme == .voidTheme ? 0.05 : 0.09),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 12,
                endRadius: 220
            )
            .offset(x: -68, y: 76)

            Canvas { context, size in
                let spacing: CGFloat = theme == .matrix ? 12 : 18
                let alpha = theme == .voidTheme ? 0.05 : 0.09

                for y in stride(from: 0, through: size.height, by: spacing) {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(themeColors.cardBorder.opacity(alpha)), lineWidth: 0.5)
                }
            }
            .blendMode(.overlay)
            .opacity(theme == .voidTheme ? 0.45 : (theme == .cyber ? 0.18 : 1))

            if theme == .matrix {
                MatrixRainView()
                    .opacity(0.14)
                CRTScanlines()
            }
        }
    }
}

private struct RitualDivider: View {
    let themeColors: EACCThemeColors
    let accent: Color

    var body: some View {
        Rectangle()
            .fill(auroraMuted.opacity(0.08))
            .frame(height: 1)
    }
}

private struct RitualSectionModifier: ViewModifier {
    let themeColors: EACCThemeColors
    let accent: Color

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                auroraMuted.opacity(0.035),
                                accent.opacity(0.035)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.16),
                                auroraMuted.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

private struct RitualFieldModifier: ViewModifier {
    let themeColors: EACCThemeColors
    let accent: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeColors.cardBg.opacity(0.9),
                                accent.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(accent.opacity(0.16), lineWidth: 1)
            )
    }
}

private struct RitualDataCardModifier: ViewModifier {
    let themeColors: EACCThemeColors
    let emphasis: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                auroraMuted.opacity(0.035),
                                emphasis.opacity(0.035)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                emphasis.opacity(0.18),
                                auroraMuted.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.16), radius: 14, y: 8)
    }
}

private struct AuroraStatusDot: View {
    let color: Color
    var isActive = true

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.45), lineWidth: 1)
                .frame(width: 18, height: 18)
                .scaleEffect(pulse && isActive ? 1.28 : 0.72)
                .opacity(pulse && isActive ? 0 : 0.72)

            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .scaleEffect(pulse && isActive ? 0.82 : 1)
                .opacity(pulse && isActive ? 0.55 : 1)
                .shadow(color: color.opacity(0.42), radius: 8)
        }
        .frame(width: 18, height: 18)
        .onAppear {
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct AuroraDashedDivider: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(auroraMuted.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .frame(height: 1)
    }
}

private extension View {
    func ritualSection(themeColors: EACCThemeColors, accent: Color) -> some View {
        modifier(RitualSectionModifier(themeColors: themeColors, accent: accent))
    }

    func ritualField(themeColors: EACCThemeColors, accent: Color) -> some View {
        modifier(RitualFieldModifier(themeColors: themeColors, accent: accent))
    }

    func ritualDataCard(themeColors: EACCThemeColors, emphasis: Color? = nil, radius: CGFloat = 12) -> some View {
        modifier(
            RitualDataCardModifier(
                themeColors: themeColors,
                emphasis: emphasis ?? themeColors.accent,
                radius: radius
            )
        )
    }
}

// MARK: - Content View

struct ContentView: View {
    @Bindable var vm: ViewModel

    private let panelWidth: CGFloat = 400
    private let scrollMaxHeight: CGFloat = 560

    private var panelColors: EACCThemeColors {
        vm.panelThemeColors
    }

    private var skin: EACCThemeColors { panelColors }

    var body: some View {
        VStack(spacing: 0) {
            header
            RitualDivider(themeColors: panelColors, accent: panelColors.accent)
            if vm.isLoading && vm.items.isEmpty && vm.sessions.isEmpty {
                loadingView
            } else {
                scrollContent
            }
            RitualDivider(themeColors: panelColors, accent: panelColors.accent)
            footer
        }
        .frame(width: panelWidth)
        .clipped()
        .background {
            RitualPanelBackdrop(
                themeColors: panelColors,
                accent: panelColors.accent,
                theme: vm.selectedTheme
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(panelColors.accent.opacity(0.15), lineWidth: 1)
        )
        .overlay {
            // Odyssey white room: 1px specular highlight inside the top edge.
            if vm.selectedTheme == .voidTheme {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.7), Color.white.opacity(0)],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
            }
        }
        .shadow(color: .black.opacity(0.72), radius: 36, y: 24)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AuroraStatusDot(color: panelColors.accent, isActive: !vm.isLoading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(activeTaskTitle)
                    .font(skin.display(vm.selectedTheme == .voidTheme ? 20 : 22,
                                       weight: vm.selectedTheme == .voidTheme ? .medium : .bold))
                    .tracking(vm.selectedTheme == .voidTheme ? 2 : 0)
                    .foregroundStyle(panelColors.textPrimary)
                    .shadow(
                        color: vm.selectedTheme == .matrix ? panelColors.accent.opacity(0.4) : .clear,
                        radius: vm.selectedTheme == .matrix ? 7 : 0
                    )
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let date = vm.lastUpdated {
                        Text(date, style: .time)
                            .font(skin.mono(11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(skin.textSecondary)
                        Text("·")
                            .font(skin.mono(11, weight: .semibold))
                            .foregroundStyle(skin.textMuted)
                    }

                    Text(activeTaskSubtitle)
                        .font(skin.mono(11, weight: .semibold))
                        .foregroundStyle(skin.textMuted)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            CompanionPersonaMenu(vm: vm, accent: panelColors.accent, isProminent: true)

            Button {
                Task { await vm.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(panelColors.accent.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(panelColors.accent.opacity(0.20), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(panelColors.accent)
            .help("Refresh")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var activeTaskTitle: String {
        let count = vm.activeSessions.count
        // Odyssey (5A) speaks in mission-control uppercase.
        if vm.selectedTheme == .voidTheme {
            if count == 1 { return "1 ACTIVE TASK" }
            if count > 1 { return "\(count) ACTIVE TASKS" }
            return "ALL SYSTEMS NOMINAL"
        }
        if count == 1 { return "1 active task" }
        if count > 1 { return "\(count) active tasks" }
        return "all agents quiet"
    }

    private var activeTaskSubtitle: String {
        guard let lastUpdated = vm.lastUpdated else { return "sync pending" }
        let seconds = max(0, Int(Date().timeIntervalSince(lastUpdated).rounded()))
        if seconds < 5 { return "synced now" }
        if seconds < 60 { return "synced \(seconds)s ago" }
        return "synced \(seconds / 60)m ago"
    }

    private var syncStatusText: String {
        let total = vm.recipeSources.count
        let connected = vm.recipeSources.filter { $0.data.connected }.count
        let pulse = "pulse \(Int(vm.sessionRefreshInterval))s"

        guard total > 0 else { return "all synced · \(pulse)" }
        if connected == total { return "all synced · \(pulse)" }
        return "\(connected)/\(total) synced · \(pulse)"
    }

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(auroraGreen)
                Text(syncStatusText)
                    .font(skin.mono(10, weight: .semibold))
                    .foregroundStyle(panelColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Menu {
                ForEach([15.0, 30.0, 60.0, 120.0], id: \.self) { interval in
                    Button {
                        vm.refreshInterval = interval
                    } label: {
                        HStack {
                            Text("\(Int(interval))s")
                            if vm.refreshInterval == interval {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(Int(vm.refreshInterval))s")
                        .font(skin.mono(10, weight: .semibold).monospacedDigit())
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(auroraMuted.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(auroraMuted.opacity(0.12), lineWidth: 1)
                )
                .foregroundStyle(panelColors.textSecondary)
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)

            Button {
                if let url = URL(string: "https://e-acc.ai") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                footerIcon("arrow.up.forward.app", tint: panelColors.accent)
            }
            .buttonStyle(.plain)
            .help("Open altar")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                footerIcon("power", tint: auroraRed)
            }
            .buttonStyle(.plain)
            .help("Disconnect")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.25))
    }

    private func footerIcon(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .bold))
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(tint.opacity(0.18), lineWidth: 1)
            )
            .foregroundStyle(tint.opacity(0.86))
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Initializing ritual link...")
                .font(skin.mono(12))
                .foregroundStyle(panelColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                companionSection
                if let snapshot = vm.codexRateLimits {
                    codexUsageSection(snapshot)
                }
                if !vm.menuSessions.isEmpty {
                    sessionsSection
                }
                if !vm.recipeSources.isEmpty {
                    recipeSourcesSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: scrollMaxHeight)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var companionSection: some View {
        CompanionCard(vm: vm)
    }

    // MARK: - Codex Usage

    private func codexUsageSection(_ snapshot: CodexRateLimitSnapshot) -> some View {
        CodexQuotaCard(snapshot: snapshot, themeColors: panelColors)
    }

    // MARK: - Recipe Sources

    private var recipeSourcesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(panelColors.accent)
                Text("COLLECTORS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(panelColors.textSecondary)
                Spacer()
                Text("\(vm.recipeSources.filter { $0.data.connected }.count) live")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(panelColors.accent.opacity(0.7))
            }
            .padding(.horizontal, 4)

            ForEach(vm.recipeSources) { source in
                RecipeSourceCard(name: source.name, data: source.data, themeColors: panelColors)
            }
        }
        .ritualSection(themeColors: panelColors, accent: panelColors.accent)
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(skin.accentEdge)
                Text("AI CODING SESSIONS")
                    .font(skin.mono(12, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(panelColors.textSecondary)
                Spacer()
                Text("\(vm.menuSessions.count) WATCHING")
                    .font(skin.mono(9, weight: .bold))
                    .tracking(1.0)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(panelColors.accent.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(panelColors.accent.opacity(0.25), lineWidth: 1)
                    )
                    .foregroundStyle(panelColors.accent)
            }

            ForEach(vm.menuSessions) { session in
                SessionRow(session: session, themeColors: panelColors)
            }
        }
        .padding(16)
        .ritualDataCard(themeColors: panelColors, emphasis: panelColors.accent, radius: 18)
    }

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(redAccent.opacity(0.7))
                Text("OFFERINGS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(panelColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            ForEach(vm.providers) { provider in
                ProviderCard(
                    provider: provider,
                    themeColors: panelColors,
                    testState: provider.capacityData.map { vm.testStates[$0.id] ?? .idle } ?? .idle
                ) {
                    if let cap = provider.capacityData {
                        Task { await vm.runTest(accountId: cap.id) }
                    }
                }
            }
        }
        .ritualSection(themeColors: panelColors, accent: panelColors.accent)
    }

}

// MARK: - Companion Card

struct CompanionCard: View {
    let vm: ViewModel

    private var panelColors: EACCThemeColors {
        vm.panelThemeColors
    }

    private var skin: EACCThemeColors { panelColors }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                mascotBadge

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(vm.companionMood.badge)
                            .font(skin.mono(10, weight: .bold))
                            .tracking(1.1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(panelColors.accent.opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(panelColors.accent.opacity(0.25), lineWidth: 1)
                            )
                            .foregroundStyle(panelColors.accent)

                        Text("\(vm.weightedUtil)% util")
                            .font(skin.mono(11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(skin.textMuted)
                    }

                    Text(vm.companionHeadline)
                        .font(skin.display(19, weight: .semibold))
                        .foregroundStyle(panelColors.textPrimary)
                        .lineLimit(2)

                    Text(vm.companionSubtitle)
                        .font(skin.mono(12, weight: .medium))
                        .foregroundStyle(panelColors.textSecondary)
                        .lineLimit(2)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }

            if vm.selectedTheme == .voidTheme {
                // Odyssey (5A): flat three-column readout split by hairlines.
                HStack(spacing: 0) {
                    voidStatColumn(value: vm.workingSessionCount, label: "LIVE", divider: true)
                    voidStatColumn(value: vm.waitingSessionCount, label: "WAITING", divider: true)
                    voidStatColumn(value: vm.warmSessionCount, label: "WARM", divider: false)
                }
                .padding(.top, 12)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 1)
                }
            } else {
                HStack(spacing: 8) {
                    statTile(value: vm.workingSessionCount, label: "live", tint: panelColors.textPrimary)
                    statTile(value: vm.waitingSessionCount, label: "waiting", tint: panelColors.accent)
                    statTile(value: vm.warmSessionCount, label: "warm", tint: auroraPurple)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            panelColors.accent.opacity(0.055),
                            panelColors.accent.opacity(0.012)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(panelColors.accent.opacity(0.15), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [panelColors.accent, skin.accentEdge],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            Task { await vm.refreshSessionPulse() }
        }
        .contextMenu {
            CompanionPersonaActions(vm: vm)
        }
        .help("Tap to sniff for fresh session activity")
    }

    private var mascotBadge: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            panelColors.accent.opacity(0.18),
                            panelColors.accent.opacity(0.04)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 42
                    )
                )

            CompanionPetView(
                persona: vm.companionPersona,
                mood: vm.companionMood,
                accent: vm.companionPetAccent,
                themeColors: panelColors,
                hasMotion: vm.companionHasMotion,
                motionScale: 0.18
            )
            .frame(width: 108, height: 108)
            .scaleEffect(0.56)
        }
        .frame(width: 66, height: 66)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(panelColors.accent.opacity(0.35), lineWidth: 2))
    }

    private func voidStatColumn(value: Int, label: String, divider: Bool) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(skin.mono(20, weight: .regular).monospacedDigit())
                .foregroundStyle(panelColors.textPrimary)
            Text(label)
                .font(skin.display(10, weight: .medium))
                .tracking(2)
                .foregroundStyle(skin.textMuted)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            if divider {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 1)
            }
        }
    }

    private func statTile(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(skin.display(18, weight: .bold).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(skin.mono(10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(skin.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(tint.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

struct CompanionPersonaMenu: View {
    let vm: ViewModel
    var accent: Color? = nil
    var isProminent = false

    private var menuAccent: Color {
        accent ?? vm.themeColors.accent
    }

    private var skin: EACCThemeColors { vm.panelThemeColors }

    var body: some View {
        Menu {
            CompanionPersonaActions(vm: vm)
        } label: {
            HStack(spacing: isProminent ? 6 : 5) {
                Text(vm.companionPersonaMode.badge)
                    .font(skin.mono(isProminent ? 11 : 10, weight: .bold))
                    .tracking(isProminent ? 1.0 : 0.8)
                Image(systemName: "chevron.down")
                    .font(.system(size: isProminent ? 8 : 7, weight: .bold))
                    .foregroundStyle(skin.textMuted)
            }
            .padding(.horizontal, isProminent ? 10 : 8)
            .padding(.vertical, isProminent ? 7 : 5)
            .background {
                RoundedRectangle(cornerRadius: isProminent ? 9 : 8, style: .continuous)
                    .fill(auroraMuted.opacity(0.06))
            }
            .overlay {
                RoundedRectangle(cornerRadius: isProminent ? 9 : 8, style: .continuous)
                    .strokeBorder(auroraMuted.opacity(0.14), lineWidth: 1)
            }
            // Design keeps this control neutral so it never competes with the
            // accent-colored status content.
            .foregroundStyle(skin.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .help("Switch companion")
    }
}

struct CompanionPersonaActions: View {
    let vm: ViewModel

    var body: some View {
        ForEach(CompanionPersonaMode.allCases, id: \.self) { mode in
            Button {
                vm.setCompanionPersonaMode(mode)
            } label: {
                HStack {
                    Text(mode.label)
                    if vm.companionPersonaMode == mode {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}

struct CompanionPetView: View {
    let persona: CompanionPersona
    let mood: CompanionMood
    let accent: Color
    let themeColors: EACCThemeColors
    var hasMotion: Bool = true
    var motionScale: CGFloat = 1.0

    var body: some View {
        switch persona {
        case .defaultOrb:
            DefaultCompanionPetView(mood: mood, accent: accent, themeColors: themeColors, hasMotion: hasMotion, motionScale: motionScale)
        case .cyberSignal:
            CyberSignalPetView(mood: mood, accent: accent, hasMotion: hasMotion, motionScale: motionScale)
        case .matrixAgent:
            MatrixPetView(mood: mood, accent: accent, hasMotion: hasMotion, motionScale: motionScale)
        case .amberEye:
            OrigamiUnicornPetView(mood: mood, accent: accent, hasMotion: hasMotion, motionScale: motionScale)
        case .voidMonolith:
            MonolithPetView(mood: mood, accent: accent, hasMotion: hasMotion, motionScale: motionScale)
        }
    }
}

private struct DefaultCompanionPetView: View {
    let mood: CompanionMood
    let accent: Color
    let themeColors: EACCThemeColors
    var hasMotion: Bool = true
    var motionScale: CGFloat = 1.0

    @State private var isFloating = false
    @State private var isOrbiting = false

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.14))
                .frame(width: 94, height: 94)
                .blur(radius: 10)

            if mood == .feasting || mood == .alert {
                Circle()
                    .stroke(accent.opacity(0.34), lineWidth: 1)
                    .frame(width: 82, height: 82)
                    .rotationEffect(.degrees(isOrbiting ? 360 : 0))
                    .overlay(alignment: .top) {
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)
                            .offset(y: -4)
                    }
            }

            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 18, height: 18)
                .offset(x: -22, y: -28)
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 18, height: 18)
                .offset(x: 22, y: -28)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.65), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                .frame(width: 72, height: 72)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 8) {
                HStack(spacing: 14) {
                    eye
                    eye
                }
                mouth
            }
        }
        .frame(width: 108, height: 108)
        .offset(y: isFloating ? -3 * motionScale : 3 * motionScale)
        .animation(hasMotion ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .easeInOut(duration: 0.2), value: isFloating)
        .animation(hasMotion ? .linear(duration: 4.8).repeatForever(autoreverses: false) : .easeInOut(duration: 0.2), value: isOrbiting)
        .onAppear {
            isFloating = hasMotion
            isOrbiting = hasMotion
        }
        .onChange(of: hasMotion) { _, enabled in
            isFloating = enabled
            isOrbiting = enabled
        }
    }

    @ViewBuilder
    private var eye: some View {
        switch mood {
        case .sleeping:
            Capsule()
                .fill(themeColors.textPrimary)
                .frame(width: 12, height: 2)
        case .dozing:
            Capsule()
                .fill(themeColors.textPrimary)
                .frame(width: 10, height: 3)
        case .expecting:
            Circle()
                .fill(themeColors.textPrimary)
                .frame(width: 7, height: 7)
        case .alert:
            Circle()
                .fill(themeColors.textPrimary)
                .frame(width: 8, height: 8)
                .overlay(Circle().fill(accent).frame(width: 3, height: 3))
        case .feasting:
            Circle()
                .fill(themeColors.textPrimary)
                .frame(width: 9, height: 9)
                .overlay(Circle().fill(accent).frame(width: 4, height: 4))
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .feasting:
            Capsule()
                .fill(themeColors.textPrimary)
                .frame(width: 18, height: 6)
        case .alert:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(themeColors.textPrimary)
                .frame(width: 14, height: 5)
        case .expecting:
            Circle()
                .fill(themeColors.textPrimary)
                .frame(width: 7, height: 7)
        case .dozing:
            Capsule()
                .fill(themeColors.textPrimary.opacity(0.8))
                .frame(width: 14, height: 3)
        case .sleeping:
            Capsule()
                .fill(themeColors.textPrimary.opacity(0.75))
                .frame(width: 12, height: 2)
        }
    }
}

// MARK: - Cyber Signal Pet View (SVG ring + Canvas face)
// Ring: NSImage from inline SVG text path for pixel-perfect text.
// Face: Canvas paths with mood-based opacity.
// Both layers share the same coordinate space centered on SVG origin (0,0).
// Ring rotates via GPU-accelerated SwiftUI animation (no per-frame redraw).

private struct CyberSignalPetView: View {
    let mood: CompanionMood
    let accent: Color
    var hasMotion: Bool = true
    var motionScale: CGFloat = 1.0

    @State private var isFloating = false
    @State private var isRingRotating = false
    @State private var rotationStartDate = Date()

    private let teal = Color(red: 0, green: 85.0 / 255.0, blue: 119.0 / 255.0)

    // Outer ring rendered once from inline SVG.
    // Uses native <textPath> — identical text distribution to laughing-man.svg.
    // viewBox is square and centered on origin so SwiftUI rotation works correctly.
    private static let ringImage: NSImage? = {
        let svg = """
        <svg viewBox="-200 -200 400 400" width="400" height="400" \
        xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">\
        <defs><path id="f" d="m123,0a123,123 0,0 1-246,0a123,123 0,0 1 246,0"/></defs>\
        <g fill="#057">\
        <circle r="160"/>\
        <circle r="150" fill="#fff"/>\
        <text font-size="28" font-stretch="condensed" font-family="Impact">\
        <textPath xlink:href="#f">TACHI LOCAL SESSION SIGNAL WATCH THE WORK KEEP THE FLOW</textPath>\
        </text>\
        </g>\
        </svg>
        """
        guard let data = svg.data(using: .utf8) else { return nil }
        return NSImage(data: data)
    }()

    private static let ringTextImage: NSImage = {
        let image = NSImage(size: NSSize(width: 400, height: 400))
        let text = Array(
            "TACHI LOCAL SESSION SIGNAL WATCH THE WORK KEEP THE FLOW "
        )
        let font = NSFont(name: "Impact", size: 22)
            ?? NSFont.systemFont(ofSize: 22, weight: .heavy)
        let color = NSColor(red: 0, green: 85.0 / 255.0, blue: 119.0 / 255.0, alpha: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let widths = text.map {
            NSAttributedString(string: String($0), attributes: attributes).size().width
        }
        let totalWidth = widths.reduce(0, +)

        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        var cumulative: CGFloat = 0
        for (index, character) in text.enumerated() {
            let charCenter = cumulative + widths[index] / 2
            let angle = Double(charCenter / totalWidth) * 360.0
            let radians = angle * .pi / 180.0
            let radius: CGFloat = 123
            let x = 200 + radius * cos(radians)
            let y = 200 + radius * sin(radians)
            let string = NSString(string: String(character))
            let size = string.size(withAttributes: attributes)

            let transform = NSAffineTransform()
            transform.translateX(by: x, yBy: y)
            transform.rotate(byDegrees: angle + 90)
            transform.concat()
            string.draw(
                at: NSPoint(x: -size.width / 2, y: -size.height),
                withAttributes: attributes
            )
            transform.invert()
            transform.concat()

            cumulative += widths[index]
        }

        image.unlockFocus()
        return image
    }()

    private var faceOpacity: Double {
        switch mood {
        case .feasting: return 0.95
        case .alert: return 0.85
        case .expecting: return 0.75
        case .dozing: return 0.6
        case .sleeping: return 0.42
        }
    }

    var body: some View {
        ZStack {
            // Layer 1: Outer circles (NSImage from SVG)
            if let ring = Self.ringImage {
                Image(nsImage: ring)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            // Layer 2: Rotating pre-rendered text ring
            Image(nsImage: Self.ringTextImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .rotationEffect(
                    .degrees(
                        hasMotion && isRingRotating ? -360 : 0
                    )
                )
                .animation(
                    hasMotion
                        ? .linear(duration: CyberSignalMotion.revolutionDuration).repeatForever(autoreverses: false)
                        : .easeInOut(duration: 0.2),
                    value: isRingRotating
                )

            // Layer 3: Static face (Canvas, redraws only on mood change)
            Canvas { context, size in
                drawFace(&context, size)
            }
        }
        .frame(width: 108, height: 108)
        .offset(y: isFloating ? -3 * motionScale : 3 * motionScale)
        .onAppear {
            rotationStartDate = .now
            isRingRotating = hasMotion
            withAnimation(
                hasMotion
                    ? .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.2)
            ) {
                isFloating = hasMotion
            }
        }
        .onChange(of: hasMotion) { _, enabled in
            if enabled {
                rotationStartDate = .now
            }
            isRingRotating = enabled
            withAnimation(
                enabled
                    ? .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.2)
            ) {
                isFloating = enabled
            }
        }
    }

    // All coordinates use the same 400×400 space as the ring SVG viewBox.
    // SVG origin (0,0) = center of both layers.
    private func drawFace(_ context: inout GraphicsContext, _ size: CGSize) {
        let s = min(size.width, size.height)
        let sc = s / 400.0
        let cx = s / 2
        let cy = s / 2

        func px(_ v: CGFloat) -> CGFloat { cx + v * sc }
        func py(_ v: CGFloat) -> CGFloat { cy + v * sc }
        func pd(_ v: CGFloat) -> CGFloat { v * sc }

        // Inner teal circle r=115 — masks the ring text underneath
        context.fill(
            Path(ellipseIn: CGRect(x: px(0) - pd(115), y: py(0) - pd(115),
                                   width: pd(230), height: pd(230))),
            with: .color(teal))

        // Inner white circle r=95
        context.fill(
            Path(ellipseIn: CGRect(x: px(0) - pd(95), y: py(0) - pd(95),
                                   width: pd(190), height: pd(190))),
            with: .color(.white))

        // Face features (mood opacity)
        context.drawLayer { fc in
            fc.opacity = faceOpacity

            // Top tick (m-8-119h16 l2,5h-20z)
            var tick = Path()
            tick.move(to: CGPoint(x: px(-8), y: py(-119)))
            tick.addLine(to: CGPoint(x: px(8), y: py(-119)))
            tick.addLine(to: CGPoint(x: px(10), y: py(-114)))
            tick.addLine(to: CGPoint(x: px(-10), y: py(-114)))
            tick.closeSubpath()
            fc.fill(tick, with: .color(teal))

            // Right ear (circle cx=160 r=40)
            fc.fill(
                Path(ellipseIn: CGRect(x: px(160) - pd(40), y: py(0) - pd(40),
                                       width: pd(80), height: pd(80))),
                with: .color(teal))

            // Visor (m-95-20v-20h255a40,40 0,0 1 0,80h-55v-20z)
            var visor = Path()
            visor.move(to: CGPoint(x: px(-95), y: py(-20)))
            visor.addLine(to: CGPoint(x: px(-95), y: py(-40)))
            visor.addLine(to: CGPoint(x: px(160), y: py(-40)))
            visor.addArc(center: CGPoint(x: px(160), y: py(0)), radius: pd(40),
                         startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            visor.addLine(to: CGPoint(x: px(105), y: py(40)))
            visor.addLine(to: CGPoint(x: px(105), y: py(20)))
            visor.closeSubpath()
            fc.fill(visor, with: .color(teal))

            // Smile (outer r=85, inner r=65)
            var smile = Path()
            smile.move(to: CGPoint(x: px(-85), y: py(0)))
            smile.addArc(center: CGPoint(x: px(0), y: py(0)), radius: pd(85),
                         startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
            smile.addLine(to: CGPoint(x: px(65), y: py(0)))
            smile.addArc(center: CGPoint(x: px(0), y: py(0)), radius: pd(65),
                         startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            smile.closeSubpath()
            fc.fill(smile, with: .color(teal))

            // Chin bar (m-65 20v20h140v-20z)
            var chin = Path()
            chin.move(to: CGPoint(x: px(-65), y: py(20)))
            chin.addLine(to: CGPoint(x: px(-65), y: py(40)))
            chin.addLine(to: CGPoint(x: px(75), y: py(40)))
            chin.addLine(to: CGPoint(x: px(75), y: py(20)))
            chin.closeSubpath()
            fc.fill(chin, with: .color(teal))
        }

        // White highlight (m-115-20v10h25v30h250a20,20 0,0 0 0,-40z)
        var hl = Path()
        hl.move(to: CGPoint(x: px(-115), y: py(-20)))
        hl.addLine(to: CGPoint(x: px(-115), y: py(-10)))
        hl.addLine(to: CGPoint(x: px(-90), y: py(-10)))
        hl.addLine(to: CGPoint(x: px(-90), y: py(20)))
        hl.addLine(to: CGPoint(x: px(160), y: py(20)))
        hl.addArc(center: CGPoint(x: px(160), y: py(0)), radius: pd(20),
                   startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        hl.closeSubpath()
        context.fill(hl, with: .color(.white))

        // Eyes (mood opacity)
        context.drawLayer { ec in
            ec.opacity = faceOpacity

            var le = Path()
            le.move(to: CGPoint(x: px(-20), y: py(10)))
            le.addCurve(to: CGPoint(x: px(-64), y: py(10)),
                        control1: CGPoint(x: px(-37), y: py(-4)),
                        control2: CGPoint(x: px(-47), y: py(-4)))
            le.addCurve(to: CGPoint(x: px(-20), y: py(10)),
                        control1: CGPoint(x: px(-58), y: py(-15)),
                        control2: CGPoint(x: px(-27), y: py(-15)))
            le.closeSubpath()
            ec.fill(le, with: .color(teal))

            var re = Path()
            re.move(to: CGPoint(x: px(60), y: py(10)))
            re.addCurve(to: CGPoint(x: px(16), y: py(10)),
                        control1: CGPoint(x: px(43), y: py(-4)),
                        control2: CGPoint(x: px(33), y: py(-4)))
            re.addCurve(to: CGPoint(x: px(60), y: py(10)),
                        control1: CGPoint(x: px(22), y: py(-15)),
                        control2: CGPoint(x: px(53), y: py(-15)))
            re.closeSubpath()
            ec.fill(re, with: .color(teal))
        }
    }
}

// MARK: - Provider Card (Unified)

// MARK: - Recipe Source Card

struct RecipeSourceCard: View {
    let name: String
    let data: EACCSourceData
    let themeColors: EACCThemeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: name + status
            HStack {
                Circle()
                    .fill(data.connected ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(name)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(themeColors.textPrimary)
                Spacer()
            }

            if data.connected || data.totalTokens > 0 {
                let hasToday = data.todayCostUSD > 0 || data.todayTokens > 0

                if hasToday {
                    // Line 1: TODAY (hero) — only when today data exists
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("TODAY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeColors.accent.opacity(0.7))
                        Spacer()
                        Text(formatCost(data.todayCostUSD))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeColors.accent)
                        Text("/ \(formatCount(data.todayTokens))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(themeColors.textSecondary)
                    }
                }

                // Summary row: month (if available) + total
                let hasMonth = data.monthCostUSD > 0 || data.monthTokens > 0
                HStack(spacing: 0) {
                    if hasMonth {
                        periodItem("MONTH", formatCost(data.monthCostUSD), formatCount(data.monthTokens))
                        Spacer()
                    }
                    // Total — hero style when no today data
                    if hasToday || hasMonth {
                        periodItem("TOTAL", formatCost(data.costUSD), formatCount(data.totalTokens))
                    } else {
                        // Total is the only data — show it big
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("TOTAL")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(themeColors.accent.opacity(0.7))
                            Spacer()
                            Text(formatCost(data.costUSD))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(themeColors.accent)
                            Text("/ \(formatCount(data.totalTokens))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(themeColors.textSecondary)
                        }
                    }
                }
            } else {
                Text("Waiting for data...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(themeColors.textMuted)
            }
        }
        .padding(10)
        .ritualDataCard(themeColors: themeColors, radius: 12)
    }

    private func periodItem(_ label: String, _ cost: String, _ tokens: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(themeColors.textMuted)
            HStack(spacing: 3) {
                Text(cost)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(themeColors.textSecondary)
                Text(tokens)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(themeColors.textMuted)
            }
        }
    }

    private func formatCost(_ cost: Double) -> String {
        if cost >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return "$" + (formatter.string(from: NSNumber(value: cost)) ?? "\(Int(cost))")
        }
        if cost >= 1 { return String(format: "$%.2f", cost) }
        if cost > 0 { return String(format: "$%.4f", cost) }
        return "$0"
    }

    private func formatCount(_ count: Int) -> String {
        count >= 1_000_000_000 ? String(format: "%.1fB", Double(count) / 1_000_000_000) :
        count >= 1_000_000 ? String(format: "%.1fM", Double(count) / 1_000_000) :
        count >= 1_000 ? String(format: "%.1fK", Double(count) / 1_000) :
        "\(count)"
    }
}

struct ProviderCard: View {
    let provider: ProviderSummary
    let themeColors: EACCThemeColors
    let testState: TestState
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader
            if let stats = provider.personalStats {
                tributeSection(stats)
            }
            if let cap = provider.capacityData {
                if provider.personalStats != nil {
                    sectionDivider
                }
                capacitySection(cap)
            }
            if provider.capacityData == nil && provider.personalStats == nil {
                unavailableBadge
            }
            if provider.capacityData != nil {
                testSection
            }
        }
        .padding(12)
        .ritualDataCard(themeColors: themeColors, emphasis: platformEmphasis, radius: 12)
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: provider.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(platformGradient)
                .frame(width: 20)
            HStack(spacing: 4) {
                Text(provider.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(themeColors.textPrimary)
                    .lineLimit(1)
                if provider.platform == "anthropic" {
                    Text("// SYMBIONT")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(themeColors.textMuted)
                }
            }
            Spacer()
            primaryMetric
        }
    }

    @ViewBuilder
    private var primaryMetric: some View {
        if let stats = provider.personalStats {
            Text(stats.formattedTotalCost)
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(purpleAccent)
        } else if let cap = provider.capacityData {
            let util = cap.maxUtilization
            Text("\(util)%")
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(ritualColorForUtil(util, accent: themeColors.accent))
        }
    }

    private static let brandGold = Color(red: 1.0, green: 0.78, blue: 0.2)

    private var platformEmphasis: Color {
        switch provider.platform {
        case "openai":
            return Self.brandGold
        case "anthropic":
            return purpleAccent
        case "antigravity":
            return themeColors.accent
        default:
            return themeColors.accent
        }
    }

    private var platformGradient: some ShapeStyle {
        switch provider.platform {
        case "openai":
            return AnyShapeStyle(
                .linearGradient(
                    colors: [Self.brandGold, Self.brandGold.opacity(0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        case "anthropic":
            return AnyShapeStyle(
                .linearGradient(
                    colors: [purpleAccent, purpleAccent.opacity(0.5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        case "antigravity":
            return AnyShapeStyle(
                .linearGradient(
                    colors: [themeColors.accent, themeColors.accent.opacity(0.5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        default:
            return AnyShapeStyle(.secondary)
        }
    }

    // MARK: - TRIBUTE Section

    private func tributeSection(_ stats: ClaudeStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TRIBUTE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(themeColors.textMuted)

            if stats.dailyCostLimit > 0 {
                costBar(label: "Today", current: stats.dailyCost, limit: stats.dailyCostLimit)
            } else {
                tributeRow(label: "Today", cost: stats.dailyCost)
            }

            if stats.weeklyOpusCostLimit > 0 {
                costBar(label: "Opus/wk", current: stats.weeklyOpusCost, limit: stats.weeklyOpusCostLimit)
            } else if stats.weeklyOpusCost > 0 {
                tributeRow(label: "Opus/wk", cost: stats.weeklyOpusCost)
            }

            tributeRow(label: "Total", cost: stats.totalCost)

            HStack(spacing: 4) {
                Label("\(stats.totalRequests) reqs", systemImage: "arrow.up.arrow.down")
                Text("\u{00B7}")
                Label(formatTokens(stats.totalTokens), systemImage: "text.word.spacing")
                Spacer()
            }
            .font(.system(size: 10))
            .foregroundStyle(themeColors.textMuted)
        }
    }

    private func tributeRow(label: String, cost: Double) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(themeColors.textMuted)
                .frame(width: 50, alignment: .trailing)
            Text(String(format: "$%.2f", cost))
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(themeColors.textSecondary)
            Spacer()
        }
    }

    private func costBar(label: String, current: Double, limit: Double) -> some View {
        let pct = limit > 0 ? min(current / limit, 1.0) : 0
        let utilInt = Int((pct * 100).rounded())
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(themeColors.textMuted)
                .frame(width: 50, alignment: .trailing)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(themeColors.cardBorder.opacity(0.45))
                    if pct > 0 {
                        Capsule()
                            .fill(ritualBarGradient(utilInt))
                            .frame(width: max(4, geo.size.width * CGFloat(pct)))
                    }
                }
            }
            .frame(height: 5)
            Text(String(format: "$%.2f", current))
                .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(ritualColorForUtil(utilInt, accent: themeColors.accent))
                .frame(width: 50, alignment: .trailing)
            Text("/ $\(String(format: "%.0f", limit))")
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(themeColors.textMuted)
                .frame(width: 40, alignment: .leading)
        }
    }

    private func ritualBarGradient(_ util: Int) -> some ShapeStyle {
        let c = ritualColorForUtil(util, accent: themeColors.accent)
        return AnyShapeStyle(
            .linearGradient(
                colors: [c.opacity(0.5), c],
                startPoint: .leading, endPoint: .trailing))
    }

    // MARK: - CAPACITY Section

    @ViewBuilder
    private func capacitySection(_ cap: AccountWithUsage) -> some View {
        if let usage = cap.usage {
            VStack(alignment: .leading, spacing: 6) {
                if provider.personalStats != nil {
                    Text("CAPACITY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(themeColors.textMuted)
                }
                capacityContent(usage)
            }
        } else {
            unavailableBadge
        }
    }

    @ViewBuilder
    private func capacityContent(_ usage: UsageData) -> some View {
        switch usage {
        case .openai(let fh, let sd):
            VStack(spacing: 6) {
                UtilRow(label: "5h", util: fh.utilization, remaining: fh.remainingSeconds, themeColors: themeColors)
                UtilRow(label: "7d", util: sd.utilization, remaining: sd.remainingSeconds, themeColors: themeColors)
                if fh.requests > 0 || sd.requests > 0 {
                    HStack(spacing: 4) {
                        Label("\(fh.requests) reqs", systemImage: "arrow.up.arrow.down")
                        Text("\u{00B7}")
                        Label(formatTokens(fh.tokens), systemImage: "text.word.spacing")
                        Spacer()
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(themeColors.textMuted)
                }
            }
        case .antigravity(let fh, let models, let tier, let credits):
            VStack(alignment: .leading, spacing: 6) {
                if !tier.isEmpty {
                    HStack(spacing: 6) {
                        Text(tier)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(themeColors.accent.opacity(0.1)))
                            .foregroundStyle(themeColors.accent)
                        Text("Credits: \(credits)")
                            .font(.system(size: 10))
                            .foregroundStyle(themeColors.textMuted)
                    }
                }
                UtilRow(label: "5h", util: fh.utilization, remaining: fh.remainingSeconds, themeColors: themeColors)

                let active = models.filter { $0.utilization > 0 }
                let idle = models.filter { $0.utilization == 0 }

                ForEach(active) { m in
                    ModelRow(model: m, themeColors: themeColors)
                }

                if !idle.isEmpty {
                    Text("\(idle.count) models at 0%")
                        .font(.system(size: 10))
                        .foregroundStyle(themeColors.textMuted)
                        .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Shared

    private var sectionDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        platformEmphasis.opacity(0.22),
                        themeColors.cardBorder.opacity(0.9),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.vertical, 2)
    }

    private var unavailableBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text("Offering data unavailable")
                .font(.system(size: 11))
                .foregroundStyle(themeColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(themeColors.cardBorder.opacity(0.35))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .foregroundStyle(themeColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    platformEmphasis.opacity(0.16),
                                    themeColors.cardBorder.opacity(0.45)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        case .testing:
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
                Text("Probing...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(themeColors.textSecondary)
            }
        case .success(let model, let text):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(themeColors.accent)
                        .font(.system(size: 11))
                    Text(model)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(themeColors.textSecondary)
                }
                Text(text)
                    .font(.system(size: 10))
                    .foregroundStyle(themeColors.textMuted)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(platformEmphasis.opacity(0.08)))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        case .failure(let error):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(redAccent)
                    .font(.system(size: 11))
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(themeColors.textSecondary)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(redAccent.opacity(0.06)))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

// MARK: - Utilization Row

struct UtilRow: View {
    let label: String
    let util: Int
    let remaining: Int
    let themeColors: EACCThemeColors

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(themeColors.textMuted)
                .frame(width: 22, alignment: .trailing)
            UtilBar(value: util, accent: themeColors.accent)
            Text("\(util)%")
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(ritualColorForUtil(util, accent: themeColors.accent))
                .frame(width: 36, alignment: .trailing)
            Text(formatRemaining(remaining))
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(themeColors.textMuted)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: ModelQuota
    let themeColors: EACCThemeColors

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(model.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(themeColors.textSecondary)
                    .lineLimit(1)
                Spacer()
                let reset = formatResetTime(model.resetTime)
                if !reset.isEmpty {
                    Text(reset)
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(themeColors.textMuted)
                }
            }
            HStack(spacing: 8) {
                UtilBar(value: model.utilization, accent: themeColors.accent)
                Text("\(model.utilization)%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(ritualColorForUtil(model.utilization, accent: themeColors.accent))
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }
}

// MARK: - Utilization Bar

struct UtilBar: View {
    let value: Int
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(accent.opacity(0.12))
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
        let c = ritualColorForUtil(value, accent: accent)
        return AnyShapeStyle(
            .linearGradient(
                colors: [c.opacity(0.5), c],
                startPoint: .leading, endPoint: .trailing))
    }
}

// MARK: - Codex Quota Card

struct CodexQuotaCard: View {
    let snapshot: CodexRateLimitSnapshot
    let themeColors: EACCThemeColors

    private var skin: EACCThemeColors { themeColors }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeColors.accent)
                Text("CODEX USAGE")
                    .font(skin.mono(12, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(themeColors.textSecondary)
                Spacer()
                Text("OFFICIAL")
                    .font(skin.mono(9, weight: .bold))
                    .tracking(1.0)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(auroraGreen.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(auroraGreen.opacity(0.25), lineWidth: 1)
                    )
                    .foregroundStyle(auroraGreen)
            }

            HStack(spacing: 10) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(themeColors.accent.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(themeColors.accent.opacity(0.20), lineWidth: 1)
                    )
                    .foregroundStyle(themeColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex account")
                        .font(skin.display(14, weight: .semibold))
                        .foregroundStyle(themeColors.textPrimary)
                    Text(snapshot.limitName ?? snapshot.limitId ?? "codex")
                        .font(skin.mono(10, weight: .medium))
                        .foregroundStyle(skin.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                if let count = snapshot.resetCreditCount {
                    Text("\(count) resets")
                        .font(skin.mono(12, weight: .bold).monospacedDigit())
                        .foregroundStyle(themeColors.accent)
                }
            }

            VStack(spacing: 12) {
                ForEach(snapshot.windows, id: \.kind.rawValue) { window in
                    quotaWindowRow(window)
                }
            }

            if !snapshot.availableResetCredits.isEmpty {
                VStack(spacing: 7) {
                    AuroraDashedDivider()
                    ForEach(Array(snapshot.availableResetCredits.prefix(4).enumerated()), id: \.offset) { index, credit in
                        resetCreditRow(index: index, credit: credit)
                    }
                    if snapshot.availableResetCredits.count > 4 {
                        Text("+\(snapshot.availableResetCredits.count - 4) more reset date ▾")
                            .font(skin.mono(10, weight: .medium))
                            .foregroundStyle(skin.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, snapshot.windows.isEmpty ? 0 : 2)
            } else if (snapshot.resetCreditCount ?? 0) > 0 {
                Text("Reset valid dates unavailable")
                    .font(skin.mono(10, weight: .medium))
                    .foregroundStyle(skin.textMuted)
            }
        }
        .padding(16)
        .ritualDataCard(themeColors: themeColors, emphasis: themeColors.accent, radius: 18)
    }

    private func quotaWindowRow(_ window: CodexRateLimitWindow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(window.validityLabel) window")
                    .font(skin.mono(11, weight: .bold))
                    .foregroundStyle(skin.textSecondary)
                Spacer()
                Text("\(formatPercent(window.remainingPercent))% left")
                    .font(skin.mono(11, weight: .bold).monospacedDigit())
                    .foregroundStyle(remainingColor(window.remainingPercent))
                Text("· \(formatResetDate(window.resetsAt))")
                    .font(skin.mono(11, weight: .medium).monospacedDigit())
                    .foregroundStyle(themeColors.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(auroraMuted.opacity(0.10))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [themeColors.accent, skin.accentEdge],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(window.remainingPercent) / 100))
                }
            }
            .frame(height: 6)
        }
    }

    private func resetCreditRow(index: Int, credit: CodexResetCredit) -> some View {
        HStack(spacing: 8) {
            Text("Reset \(index + 1)")
                .font(skin.mono(11, weight: .semibold))
                .foregroundStyle(themeColors.textSecondary)
                .frame(width: 58, alignment: .leading)
            Text("valid until")
                .font(skin.mono(10, weight: .medium))
                .foregroundStyle(skin.textMuted)
            Spacer()
            Text(formatResetValidDate(credit.expiresAt))
                .font(skin.mono(11, weight: .bold).monospacedDigit())
                .foregroundStyle(themeColors.accent)
        }
    }

    private func remainingColor(_ value: Double) -> Color {
        if value < 5 { return auroraRed }
        if value < 20 { return auroraAmber }
        return auroraGreen
    }

    private func formatPercent(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func formatResetDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "M/d"
        } else {
            formatter.dateFormat = "yyyy/M/d"
        }
        return formatter.string(from: date)
    }

    private func formatResetValidDate(_ date: Date?) -> String {
        guard let date else { return "unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "EEE M/d HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: CodingSession
    let themeColors: EACCThemeColors

    private var skin: EACCThemeColors { themeColors }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(session.projectName)
                        .font(skin.mono(12, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(themeColors.textPrimary)

                    Text(statusLabel)
                        .font(skin.mono(10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(statusChipColor.opacity(0.12))
                        )
                        .foregroundStyle(statusChipColor)
                        .lineLimit(1)
                }

                Text(agentStatusLine)
                    .font(skin.mono(11, weight: .medium))
                    .foregroundStyle(themeColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Button {
                Task { @MainActor in
                    SessionLauncher.open(session)
                }
            } label: {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(statusColor.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(statusColor.opacity(0.28), lineWidth: 1)
                    )
                    .foregroundStyle(statusColor)
            }
            .buttonStyle(.plain)
            .help("Open \(session.tool.rawValue)")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(themeColors.accent.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(themeColors.accent.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(skin.accentEdge)
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var agentStatusLine: String {
        let detail = session.status == .waitingForInput ? "waiting for input" : session.signal.compactLabel
        return "\(session.tool.rawValue) · \(detail)"
    }

    private var statusLabel: String {
        switch session.status {
        case .working: return "working"
        case .waitingForInput: return "waiting"
        case .completed: return "done"
        case .idle: return "warm"
        }
    }

    private var statusColor: Color {
        switch session.pulse {
        case .hot: return themeColors.accent
        case .warm: return themeColors.accent.opacity(0.7)
        case .listening: return themeColors.accent.opacity(0.5)
        case .drowsy: return purpleAccent.opacity(0.7)
        case .sleeping: return .gray
        }
    }

    private var statusChipColor: Color {
        switch session.status {
        case .working: return themeColors.accent
        case .waitingForInput: return auroraAmber
        case .completed: return auroraGreen
        case .idle: return themeColors.textMuted
        }
    }
}

// MARK: - Matrix Static Wallpaper

struct MatrixRainView: View {
    private static let glyphs: [String] = "アウエカキケコシスセタチツテトナニネノハヒフヘホマミムメモヤユヨラリルレロワン0123456789ABCDEF".map { String($0) }
    private static let colSpacing: Double = 18
    private static let fontSize: CGFloat = 11

    private struct FrozenColumn {
        let x: Double
        let chars: [(glyph: String, y: Double, alpha: Double, isHead: Bool)]
    }

    @State private var frozen: [FrozenColumn] = []

    var body: some View {
        GeometryReader { geo in
            Canvas(rendersAsynchronously: true) { ctx, size in
                draw(ctx: ctx, size: size)
            }
            .onAppear { generate(width: geo.size.width, height: geo.size.height) }
            .onChange(of: geo.size) { _, s in generate(width: s.width, height: s.height) }
        }
        .overlay {
            // Top-down vignette glow
            LinearGradient(
                stops: [
                    .init(color: matrixGreen.opacity(0.06), location: 0),
                    .init(color: .clear, location: 0.35),
                    .init(color: .clear, location: 0.7),
                    .init(color: matrixGreen.opacity(0.04), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .overlay {
            // Radial center highlight
            RadialGradient(
                colors: [matrixGreen.opacity(0.05), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }

    private func generate(width: Double, height: Double) {
        let colCount = Int(width / Self.colSpacing)
        var rng = SystemRandomNumberGenerator()
        frozen = (0..<colCount).map { i in
            let x = Double(i) * Self.colSpacing + 4
            let length = Int.random(in: 5...18, using: &rng)
            let headY = Double.random(in: 0...height, using: &rng)

            let chars: [(String, Double, Double, Bool)] = (0..<length).compactMap { j in
                let y = headY - Double(j) * Double(Self.fontSize)
                guard y > -Double(Self.fontSize), y < height + Double(Self.fontSize) else { return nil }
                let alpha: Double
                let isHead: Bool
                if j == 0 {
                    alpha = Double.random(in: 0.55...0.85, using: &rng)
                    isHead = true
                } else {
                    let fade = 1.0 - Double(j) / Double(length)
                    alpha = fade * Double.random(in: 0.12...0.30, using: &rng)
                    isHead = false
                }
                let glyph = Self.glyphs.randomElement(using: &rng)!
                return (glyph, y, alpha, isHead)
            }
            return FrozenColumn(x: x, chars: chars)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let font = Font.system(size: Self.fontSize, design: .monospaced)
        for col in frozen {
            for ch in col.chars {
                let color: Color = ch.isHead
                    ? .white.opacity(ch.alpha)
                    : matrixGreen.opacity(ch.alpha)
                var text = ctx.resolve(Text(ch.glyph).font(font))
                text.shading = .color(color)

                // Subtle glow for head chars
                if ch.isHead {
                    var glow = ctx.resolve(Text(ch.glyph).font(font))
                    glow.shading = .color(matrixGreen.opacity(ch.alpha * 0.4))
                    ctx.drawLayer { inner in
                        inner.addFilter(.blur(radius: 4))
                        inner.draw(glow, at: CGPoint(x: col.x, y: ch.y), anchor: .topLeading)
                    }
                }

                ctx.draw(text, at: CGPoint(x: col.x, y: ch.y), anchor: .topLeading)
            }
        }
    }
}

// MARK: - EACC Helpers

/// Gold color used as a mid-range utilization indicator (theme-independent).
private let utilGold = Color(red: 1.0, green: 0.78, blue: 0.2)

func ritualColorForUtil(_ v: Int, accent: Color) -> Color {
    if v < 50 { return accent }
    if v < 80 { return utilGold }
    return redAccent
}

func colorForUtil(_ v: Int, accent: Color) -> Color {
    ritualColorForUtil(v, accent: accent)
}
