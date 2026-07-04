import AppKit
import SwiftUI

private let desktopAuroraCyan = Color(red: 56.0 / 255.0, green: 189.0 / 255.0, blue: 248.0 / 255.0)
private let desktopAuroraTeal = Color(red: 45.0 / 255.0, green: 212.0 / 255.0, blue: 191.0 / 255.0)
private let desktopAuroraAmber = Color(red: 245.0 / 255.0, green: 158.0 / 255.0, blue: 11.0 / 255.0)
private let desktopAuroraMutedDeep = Color(red: 90.0 / 255.0, green: 107.0 / 255.0, blue: 126.0 / 255.0)

// Behind-window vibrancy: blurs the actual desktop content underneath the
// panel, which SwiftUI materials (within-window blending) cannot do.
private struct GlassBackdrop: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct DesktopPulseDot: View {
    let color: Color

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.38), lineWidth: 1)
                .frame(width: 16, height: 16)
                .scaleEffect(pulse ? 1.28 : 0.72)
                .opacity(pulse ? 0 : 0.78)

            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .scaleEffect(pulse ? 0.82 : 1)
                .opacity(pulse ? 0.55 : 1)
                .shadow(color: color.opacity(0.42), radius: 8)
        }
        .frame(width: 16, height: 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

@MainActor
final class FloatingPetWindowController {
    static let shared = FloatingPetWindowController()

    private var panel: NSPanel?

    func show(vm: ViewModel) {
        let initialSize = DesktopPetView.panelSize(for: vm, showingPreview: false)
        if let panel {
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false

        updateContent(vm: vm, panel: panel)
        place(panel: panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func updateContent(vm: ViewModel, panel: NSPanel) {
        let view = DesktopPetView(vm: vm) { [weak self, weak panel] size in
            guard let self, let panel else { return }
            self.applySize(size, to: panel)
        }
        if let hosting = panel.contentView as? NSHostingView<DesktopPetView> {
            hosting.rootView = view
        } else {
            panel.contentView = NSHostingView(rootView: view)
        }
    }

    private func place(panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        let x = frame.maxX - panel.frame.width - 24
        let y = frame.minY + 72
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func applySize(_ size: CGSize, to panel: NSPanel, animated: Bool = true) {
        guard panel.frame.size != size else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            panel.setContentSize(size)
            return
        }

        let frame = screen.visibleFrame
        let targetFrame = NSRect(
            x: frame.maxX - size.width - 24,
            y: frame.minY + 72,
            width: size.width,
            height: size.height
        )

        panel.setFrame(targetFrame, display: true)
    }
}

struct DesktopPetView: View {
    private static let collapsedPanelWidth: CGFloat = 168
    private static let expandedPanelWidth: CGFloat = 372
    private static let collapsedContentHeight: CGFloat = 148
    private static let previewLift: CGFloat = 170
    private static let previewOffsetY: CGFloat = 136
    private static let horizontalPadding: CGFloat = 20
    private static let verticalPadding: CGFloat = 12

    let vm: ViewModel
    var onPanelSizeChange: ((CGSize) -> Void)? = nil
    @State private var isHoveringCompanion = false
    @State private var isHoveringTaskBubble = false
    @State private var isCelebrating = false
    @State private var celebrationToken = 0
    @State private var isPreviewVisible = false
    @State private var previewDismissTask: Task<Void, Never>? = nil

    private var isShowingPreview: Bool {
        isPreviewVisible && vm.shouldShowCompanionTaskPreview
    }

    private var estimatedBubbleHeight: CGFloat {
        Self.estimatedBubbleHeight(for: vm)
    }

    private var currentPanelWidth: CGFloat {
        isShowingPreview ? Self.expandedPanelWidth : Self.collapsedPanelWidth
    }

    private var contentHeight: CGFloat {
        guard isShowingPreview else { return Self.collapsedContentHeight }
        return max(Self.collapsedContentHeight, estimatedBubbleHeight + Self.previewLift)
    }

    private var panelSize: CGSize {
        CGSize(
            width: currentPanelWidth,
            height: contentHeight + (Self.verticalPadding * 2)
        )
    }

    private var usesLaunchAwayCelebration: Bool {
        vm.companionPersona == .voidMonolith
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isShowingPreview {
                taskBubble
                    .offset(x: -8, y: isShowingPreview ? -Self.previewOffsetY : -(Self.previewOffsetY - 8))
                    .opacity(isShowingPreview ? 1 : 0)
                    .blur(radius: isShowingPreview ? 0 : 4)
                    .animation(.easeOut(duration: 0.22), value: isShowingPreview)
                    .onHover { hovering in
                        isHoveringTaskBubble = hovering
                        if hovering {
                            showPreview()
                        } else {
                            schedulePreviewDismissIfNeeded()
                        }
                    }
            }

            ZStack {
                if isCelebrating && !usesLaunchAwayCelebration {
                    TaskCompletionBurstView(accent: vm.companionPetAccent, token: celebrationToken)
                        .offset(x: -8, y: -10)
                }

                CompanionPetView(
                    persona: vm.companionPersona,
                    mood: vm.companionMood,
                    accent: vm.companionPetAccent,
                    themeColors: vm.themeColors,
                    hasMotion: vm.companionHasMotion,
                    motionScale: 0.12
                )
                .scaleEffect(companionCelebrationScale)
                .rotationEffect(.degrees(companionCelebrationRotation))
                .offset(y: companionCelebrationOffsetY)
                .opacity(companionCelebrationOpacity)
                .blur(radius: companionCelebrationBlur)
                .shadow(color: vm.companionPetAccent.opacity(companionCelebrationShadowOpacity), radius: 22, y: 4)
                .frame(width: 124, height: 124)
                .contentShape(Rectangle())
                .onHover { hovering in
                    isHoveringCompanion = hovering
                    if hovering {
                        showPreview()
                    } else {
                        schedulePreviewDismissIfNeeded()
                    }
                }
            }
        }
        .frame(width: currentPanelWidth - (Self.horizontalPadding * 2), height: contentHeight, alignment: .bottomTrailing)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .background(Color.clear)
        .onAppear {
            onPanelSizeChange?(panelSize)
        }
        .onChange(of: vm.shouldShowCompanionTaskPreview) { _, _ in
            onPanelSizeChange?(panelSize)
        }
        .onChange(of: vm.companionTaskVisibleSessions.count) { _, _ in
            onPanelSizeChange?(panelSize)
        }
        .onChange(of: vm.companionTaskOverflowCount) { _, _ in
            onPanelSizeChange?(panelSize)
        }
        .onChange(of: vm.shouldShowCompanionTaskPreview) { _, newValue in
            if !newValue {
                previewDismissTask?.cancel()
                isPreviewVisible = false
                isHoveringTaskBubble = false
            }
        }
        .onChange(of: vm.companionCelebrationSequence) { _, newValue in
            guard newValue > 0 else { return }
            celebrationToken = newValue
            withAnimation(usesLaunchAwayCelebration ? .easeInOut(duration: 0.72) : .spring(response: 0.22, dampingFraction: 0.55)) {
                isCelebrating = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(950))
                await MainActor.run {
                    withAnimation(usesLaunchAwayCelebration ? .easeOut(duration: 0.18) : .easeOut(duration: 0.24)) {
                        isCelebrating = false
                    }
                }
            }
        }
        .onTapGesture {
            Task { await vm.refreshSessionPulse() }
        }
        .contextMenu {
            CompanionPersonaActions(vm: vm)
        }
        .help("Hover to peek at the current task, drag to move, or tap to sniff session activity")
    }

    private var companionCelebrationScale: CGFloat {
        guard isCelebrating else { return 1.0 }
        return usesLaunchAwayCelebration ? 0.68 : 1.12
    }

    private var companionCelebrationRotation: Double {
        guard isCelebrating else { return 0 }
        return usesLaunchAwayCelebration ? -1.5 : 7
    }

    private var companionCelebrationOffsetY: CGFloat {
        guard isCelebrating else { return 0 }
        return usesLaunchAwayCelebration ? -92 : 0
    }

    private var companionCelebrationOpacity: Double {
        guard isCelebrating else { return 1 }
        return usesLaunchAwayCelebration ? 0 : 1
    }

    private var companionCelebrationBlur: CGFloat {
        guard isCelebrating else { return 0 }
        return usesLaunchAwayCelebration ? 1.6 : 0
    }

    private var companionCelebrationShadowOpacity: Double {
        guard isCelebrating else { return 0 }
        return usesLaunchAwayCelebration ? 0.0 : 0.28
    }

    private func showPreview() {
        previewDismissTask?.cancel()
        previewDismissTask = nil
        guard vm.shouldShowCompanionTaskPreview else {
            isPreviewVisible = false
            return
        }
        withAnimation(.easeOut(duration: 0.16)) {
            isPreviewVisible = true
        }
        onPanelSizeChange?(Self.panelSize(for: vm, showingPreview: true))
    }

    private func schedulePreviewDismissIfNeeded() {
        previewDismissTask?.cancel()
        guard !isHoveringCompanion && !isHoveringTaskBubble else { return }

        previewDismissTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !isHoveringCompanion && !isHoveringTaskBubble else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    isPreviewVisible = false
                }
                onPanelSizeChange?(Self.panelSize(for: vm, showingPreview: false))
            }
        }
    }

    static func panelSize(for vm: ViewModel, showingPreview: Bool) -> CGSize {
        let estimatedBubbleHeight = estimatedBubbleHeight(for: vm)
        let contentHeight = showingPreview
            ? max(collapsedContentHeight, estimatedBubbleHeight + previewLift)
            : collapsedContentHeight
        return CGSize(
            width: showingPreview ? expandedPanelWidth : collapsedPanelWidth,
            height: contentHeight + (verticalPadding * 2)
        )
    }

    private static func estimatedBubbleHeight(for vm: ViewModel) -> CGFloat {
        let taskCount = max(1, vm.companionTaskVisibleSessions.count)
        // Real card height: chip row (~24) + two-line title (~38) + meta row (32)
        // + internal spacing. Underestimating clips the bubble at the panel edge.
        let itemHeight: CGFloat = 118
        let itemSpacing: CGFloat = CGFloat(max(0, taskCount - 1)) * 10
        let footerHeight: CGFloat = vm.companionTaskFooter == nil ? 0 : 32
        return 76 + (CGFloat(taskCount) * itemHeight) + itemSpacing + footerHeight
    }

    private var taskBubble: some View {
        let panelColors = vm.panelThemeColors
        let skin = panelColors
        // Keep the tint light so the behind-window blur stays visible.
        let bubbleFill = LinearGradient(
            colors: [
                panelColors.cardBg.opacity(0.55),
                panelColors.bg.opacity(0.62)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                DesktopPulseDot(color: panelColors.accent)
                Text(vm.companionTaskHeader)
                    .font(skin.display(16, weight: .semibold))
                    .foregroundStyle(panelColors.textPrimary)
                Spacer()
                CompanionPersonaMenu(
                    vm: vm,
                    accent: panelColors.accent
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(vm.companionTaskVisibleSessions) { session in
                    taskPreviewItem(session, panelColors: panelColors)
                }
            }

            if let footer = vm.companionTaskFooter {
                Text(footer)
                    .font(skin.mono(11, weight: .medium))
                    .foregroundStyle(panelColors.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(width: 332, alignment: .leading)
        .background(
            GlassBackdrop()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(bubbleFill)
                }
                .overlay {
                    // Specular top edge, the detail that sells native glass.
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(panelColors.accent.opacity(0.18), lineWidth: 1)
        )
        .overlay(alignment: .bottomLeading) {
            // Same glass treatment as the bubble so the tail doesn't read as a
            // solid chip; DiamondShape clips without rotating the NSView.
            GlassBackdrop()
                .clipShape(DiamondShape())
                .overlay(DiamondShape().fill(panelColors.bg.opacity(0.62)))
                .overlay(DiamondShape().stroke(panelColors.accent.opacity(0.16), lineWidth: 1))
                .frame(width: 26, height: 26)
                .offset(x: 40, y: 13)
        }
        .shadow(color: panelColors.accent.opacity(0.18), radius: 40, y: 12)
        .shadow(color: .black.opacity(0.32), radius: 26, y: 14)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func taskPreviewItem(_ session: CodingSession, panelColors: EACCThemeColors) -> some View {
        let skin = panelColors
        return Button {
            vm.openCompanionTask(session)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(vm.companionTaskProject(for: session))
                        .font(skin.mono(11, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(panelColors.accent.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(panelColors.accent.opacity(0.25), lineWidth: 1)
                        )
                        .foregroundStyle(panelColors.accent)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(sessionStatusLabel(session))
                        .font(skin.mono(10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(sessionStatusTint(session).opacity(0.12))
                        )
                        .foregroundStyle(sessionStatusTint(session))

                    Spacer(minLength: 0)
                }

                Text(vm.companionTaskLine(for: session))
                    .font(skin.display(15, weight: .semibold))
                    .foregroundStyle(panelColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(sessionMetaLine(session))
                        .font(skin.mono(11, weight: .medium))
                        .foregroundStyle(panelColors.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(panelColors.accent.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(panelColors.accent.opacity(0.20), lineWidth: 1)
                        )
                        .foregroundStyle(panelColors.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Open \(session.tool.rawValue)")
    }

    private func sessionStatusTint(_ session: CodingSession) -> Color {
        switch session.status {
        case .working: return desktopAuroraCyan
        case .waitingForInput: return desktopAuroraAmber
        case .completed: return desktopAuroraTeal
        case .idle: return desktopAuroraMutedDeep
        }
    }

    private func sessionStatusLabel(_ session: CodingSession) -> String {
        switch session.status {
        case .working: return "working"
        case .waitingForInput: return "waiting"
        case .completed: return "done"
        case .idle: return "open"
        }
    }

    private func sessionMetaLine(_ session: CodingSession) -> String {
        let detail = session.status == .completed ? "done" : "watching"
        return "\(session.tool.rawValue) · \(detail)"
    }
}

private struct TaskCompletionBurstView: View {
    let accent: Color
    let token: Int

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.36), lineWidth: 2)
                .frame(width: 78, height: 78)
                .scaleEffect(isAnimating ? 1.45 : 0.35)
                .opacity(isAnimating ? 0 : 0.9)

            ForEach(0..<10, id: \.self) { index in
                let angle = (Double(index) / 10.0) * (.pi * 2)
                Circle()
                    .fill(index.isMultiple(of: 2) ? accent : Color.white.opacity(0.95))
                    .frame(width: index.isMultiple(of: 3) ? 10 : 7, height: index.isMultiple(of: 3) ? 10 : 7)
                    .offset(
                        x: isAnimating ? cos(angle) * 58 : 0,
                        y: isAnimating ? sin(angle) * 58 : 0
                    )
                    .scaleEffect(isAnimating ? 0.75 : 0.2)
                    .opacity(isAnimating ? 0 : 1)
            }
        }
        .frame(width: 156, height: 156)
        .id(token)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                isAnimating = true
            }
        }
    }
}
