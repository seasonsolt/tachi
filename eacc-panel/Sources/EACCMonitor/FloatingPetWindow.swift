import AppKit
import SwiftUI

@MainActor
final class FloatingPetWindowController {
    static let shared = FloatingPetWindowController()

    private var panel: NSPanel?

    func show(vm: ViewModel) {
        let initialSize = DynamicIslandPanelView.panelSize(for: .idleLine)
        if let panel {
            updateContent(vm: vm, panel: panel)
            panel.orderFrontRegardless()
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
        panel.isMovableByWindowBackground = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false

        updateContent(vm: vm, panel: panel)
        place(panel: panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func updateContent(vm: ViewModel, panel: NSPanel) {
        let view = DynamicIslandPanelView(vm: vm) { [weak self, weak panel] size in
            guard let self, let panel else { return }
            self.applySize(size, to: panel)
        }
        panel.contentView = NSHostingView(rootView: view)
    }

    private func place(panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        panel.setFrame(targetFrame(for: panel.frame.size, on: screen), display: true)
    }

    private func applySize(_ size: CGSize, to panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            panel.setContentSize(size)
            return
        }

        panel.setFrame(targetFrame(for: size, on: screen), display: true)
    }

    private func targetFrame(for size: CGSize, on screen: NSScreen) -> NSRect {
        let frame = screen.visibleFrame
        return NSRect(
            x: frame.midX - (size.width / 2),
            y: frame.maxY - size.height - 8,
            width: size.width,
            height: size.height
        )
    }
}

private struct DynamicIslandPanelView: View {
    private static let idleWidth: CGFloat = 122
    private static let idleHeight: CGFloat = 18
    private static let capsuleWidth: CGFloat = 332
    private static let capsuleHeight: CGFloat = 54
    private static let detailHeight: CGFloat = 146
    private static let eventCollapseSeconds: Double = 2.3
    private static let detailCollapseSeconds: Double = 0.9

    let vm: ViewModel
    var onPanelSizeChange: ((CGSize) -> Void)? = nil

    @State private var isBreathing = false
    @State private var isTransientlyExpanded = false
    @State private var isDetailPresented = false
    @State private var collapseTask: Task<Void, Never>? = nil
    @State private var completionHeadline: String? = nil

    private var panelColors: EACCThemeColors {
        vm.panelThemeColors
    }

    private var snapshot: IslandSnapshot {
        vm.islandSnapshot
    }

    private var dominantSession: CodingSession? {
        vm.dominantSession
    }

    private var visibleMode: IslandVisibleMode {
        IslandPresentation.resolveVisibleMode(
            hasActiveSession: snapshot.hasActiveSession,
            isDetailPresented: isDetailPresented,
            isTransientlyExpanded: isTransientlyExpanded
        )
    }

    private var panelSize: CGSize {
        Self.panelSize(for: visibleMode)
    }

    private var islandHeadline: String {
        if !snapshot.hasActiveSession, let completionHeadline, !completionHeadline.isEmpty {
            return completionHeadline
        }
        guard let session = dominantSession else { return "No active task" }
        return vm.companionTaskLine(for: session)
    }

    private var islandSubheadline: String {
        if !snapshot.hasActiveSession, completionHeadline != nil {
            return "completed just now"
        }
        guard let session = dominantSession else { return "awaiting session activity" }
        return vm.companionTaskMeta(for: session)
    }

    private var detailFooter: String? {
        guard snapshot.hasActiveSession, vm.companionTaskOverflowCount > 0 else { return nil }
        return "+\(vm.companionTaskOverflowCount) more active"
    }

    private var pulseTint: Color {
        switch snapshot.pulse {
        case .hot:
            return panelColors.accent
        case .warm:
            return panelColors.accent.opacity(0.75)
        case .listening:
            return panelColors.accentEdge.opacity(0.78)
        case .drowsy:
            return panelColors.textSecondary
        case .sleeping, nil:
            return panelColors.textMuted
        }
    }

    var body: some View {
        VStack(spacing: visibleMode == .detailPopover ? 8 : 0) {
            Button {
                handleIslandTap()
            } label: {
                islandSurface
            }
            .buttonStyle(.plain)
            .help(snapshot.hasActiveSession ? "Open current session details" : "Waiting for active sessions")

            if visibleMode == .detailPopover {
                detailPopover
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: panelSize.width, height: panelSize.height, alignment: .top)
        .background(Color.clear)
        .onAppear {
            onPanelSizeChange?(panelSize)
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .onDisappear {
            collapseTask?.cancel()
        }
        .onChange(of: visibleMode) { _, _ in
            onPanelSizeChange?(panelSize)
        }
        .onChange(of: snapshot) { oldValue, newValue in
            handleSnapshotChange(from: oldValue, to: newValue)
        }
        .onChange(of: isDetailPresented) { _, presented in
            if presented {
                collapseTask?.cancel()
            } else if isTransientlyExpanded {
                scheduleCollapse(after: Self.detailCollapseSeconds)
            }
        }
        .onChange(of: vm.companionCelebrationSequence) { _, newValue in
            guard newValue > 0 else { return }
            completionHeadline = vm.companionCelebrationTitle
            isDetailPresented = false
            triggerTransientExpansion(after: Self.eventCollapseSeconds)
        }
    }

    private var islandSurface: some View {
        Group {
            switch visibleMode {
            case .idleLine:
                idleLine
            case .eventExpanded, .detailPopover:
                capsule
            }
        }
    }

    private var idleLine: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        panelColors.accent.opacity(0.18),
                        panelColors.accent.opacity(0.88),
                        panelColors.accent.opacity(0.18)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: isBreathing ? 108 : 82, height: 6)
            .shadow(color: panelColors.accent.opacity(isBreathing ? 0.32 : 0.18), radius: 14, y: 2)
            .padding(.top, 6)
    }

    private var capsule: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(pulseTint)
                .frame(width: 9, height: 9)
                .shadow(color: pulseTint.opacity(0.55), radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(islandHeadline)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(panelColors.textPrimary)
                    .lineLimit(1)

                Text(islandSubheadline)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(panelColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let session = dominantSession, snapshot.hasActiveSession {
                Image(systemName: session.tool.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(panelColors.accent)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(panelColors.accent.opacity(0.10))
                    )
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(panelColors.textPrimary)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(panelColors.textMuted.opacity(0.16))
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: Self.capsuleWidth, height: Self.capsuleHeight)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    panelColors.cardBg.opacity(0.80),
                                    panelColors.accent.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(panelColors.accent.opacity(0.20), lineWidth: 1)
                }
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        .shadow(color: panelColors.accent.opacity(0.12), radius: 18, y: 6)
    }

    private var detailPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CURRENT SESSION")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(panelColors.textMuted)

            if let session = dominantSession {
                Button {
                    vm.openCompanionTask(session)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        isDetailPresented = false
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        if vm.companionTaskShowsProjectBadge(for: session) {
                            Text(vm.companionTaskProject(for: session))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(panelColors.accent)
                        }

                        Text(vm.companionTaskLine(for: session))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(panelColors.textPrimary)
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            Text(vm.companionTaskMeta(for: session))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(panelColors.textSecondary)

                            Spacer(minLength: 0)

                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(panelColors.accent)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(panelColors.cardBg.opacity(0.92))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(panelColors.accent.opacity(0.14), lineWidth: 1)
                            }
                    )
                }
                .buttonStyle(.plain)
            }

            if let detailFooter {
                Text(detailFooter)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(panelColors.textSecondary)
            }
        }
        .padding(12)
        .frame(width: Self.capsuleWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(panelColors.cardBg.opacity(0.78))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(panelColors.cardBorder.opacity(0.85), lineWidth: 1)
                }
        )
        .shadow(color: .black.opacity(0.16), radius: 24, y: 14)
    }

    private func handleIslandTap() {
        guard snapshot.hasActiveSession else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            isDetailPresented.toggle()
        }
    }

    private func handleSnapshotChange(from oldValue: IslandSnapshot, to newValue: IslandSnapshot) {
        if IslandPresentation.shouldAutoExpand(from: oldValue, to: newValue) {
            completionHeadline = nil
            triggerTransientExpansion(after: Self.eventCollapseSeconds)
        }

        if !newValue.hasActiveSession && !isTransientlyExpanded {
            isDetailPresented = false
        }
    }

    private func triggerTransientExpansion(after seconds: Double) {
        collapseTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            isTransientlyExpanded = true
        }
        scheduleCollapse(after: seconds)
    }

    private func scheduleCollapse(after seconds: Double) {
        collapseTask?.cancel()
        collapseTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !isDetailPresented else { return }
                withAnimation(.easeOut(duration: 0.22)) {
                    isTransientlyExpanded = false
                    if !snapshot.hasActiveSession {
                        completionHeadline = nil
                    }
                }
            }
        }
    }

    static func panelSize(for mode: IslandVisibleMode) -> CGSize {
        switch mode {
        case .idleLine:
            return CGSize(width: idleWidth, height: idleHeight)
        case .eventExpanded:
            return CGSize(width: capsuleWidth, height: capsuleHeight)
        case .detailPopover:
            return CGSize(width: capsuleWidth, height: detailHeight)
        }
    }
}
