import AppKit
import SwiftUI

@MainActor
final class FloatingPetWindowController {
    static let shared = FloatingPetWindowController()

    private var panel: NSPanel?

    func show(vm: ViewModel) {
        let initialSize = DesktopPetView.panelSize(for: vm, showingPreview: false)
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
    private static let panelWidth: CGFloat = 276
    private static let collapsedContentHeight: CGFloat = 148
    private static let previewLift: CGFloat = 148
    private static let previewOffsetY: CGFloat = 118
    private static let horizontalPadding: CGFloat = 10
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

    private var contentHeight: CGFloat {
        guard vm.shouldShowCompanionTaskPreview else { return Self.collapsedContentHeight }
        return max(Self.collapsedContentHeight, estimatedBubbleHeight + Self.previewLift)
    }

    private var panelSize: CGSize {
        CGSize(
            width: Self.panelWidth,
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
        .frame(width: Self.panelWidth - (Self.horizontalPadding * 2), height: contentHeight, alignment: .bottomTrailing)
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
            }
        }
    }

    static func panelSize(for vm: ViewModel, showingPreview: Bool) -> CGSize {
        let estimatedBubbleHeight = estimatedBubbleHeight(for: vm)
        let contentHeight = showingPreview
            ? max(collapsedContentHeight, estimatedBubbleHeight + previewLift)
            : collapsedContentHeight
        return CGSize(
            width: panelWidth,
            height: contentHeight + (verticalPadding * 2)
        )
    }

    private static func estimatedBubbleHeight(for vm: ViewModel) -> CGFloat {
        let taskCount = max(1, vm.companionTaskVisibleSessions.count)
        let itemHeight: CGFloat = 78
        let itemSpacing: CGFloat = CGFloat(max(0, taskCount - 1)) * 9
        let footerHeight: CGFloat = vm.companionTaskFooter == nil ? 0 : 18
        return 64 + (CGFloat(taskCount) * itemHeight) + itemSpacing + footerHeight
    }

    private var taskBubble: some View {
        let panelColors = vm.panelThemeColors
        let fillTint = LinearGradient(
            colors: [
                panelColors.accent.opacity(0.20),
                panelColors.accentEdge.opacity(0.14),
                panelColors.bg.opacity(0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let sheen = LinearGradient(
            colors: [
                Color.white.opacity(0.28),
                Color.white.opacity(0.06),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let strokeGradient = LinearGradient(
            colors: [
                Color.white.opacity(0.38),
                panelColors.accent.opacity(0.48),
                panelColors.accentEdge.opacity(0.32)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Circle()
                    .fill(panelColors.accent)
                    .frame(width: 10, height: 10)
                Text(vm.companionTaskHeader)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(panelColors.textPrimary)
                Spacer()
                CompanionPersonaMenu(
                    vm: vm,
                    accent: panelColors.accent
                )
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(vm.companionTaskVisibleSessions) { session in
                    Button {
                        vm.openCompanionTask(session)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            if vm.companionTaskShowsProjectBadge(for: session) {
                                Text(vm.companionTaskProject(for: session))
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(panelColors.accent.opacity(0.12))
                                    )
                                    .foregroundStyle(panelColors.accent)
                            }

                            Text(vm.companionTaskLine(for: session))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(panelColors.textPrimary)
                                .lineLimit(2)

                            HStack(spacing: 6) {
                                Text(vm.companionTaskMeta(for: session))
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(panelColors.textSecondary)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                Image(systemName: "arrow.up.forward")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(panelColors.accent.opacity(0.9))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(fillTint.opacity(0.42))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
                            }
                    )
                    .help("Open \(session.tool.rawValue)")
                }
            }

            if let footer = vm.companionTaskFooter {
                Text(footer)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(panelColors.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(width: 242, alignment: .leading)
        .background(
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(fillTint)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(sheen)
                    }
                    .padding(.bottom, 14)

                BubbleTail()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        BubbleTail()
                            .fill(fillTint)
                    }
                    .frame(width: 20, height: 18)
                    .offset(x: 40, y: 2)
            }
        )
        .overlay(
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(strokeGradient, lineWidth: 1)
                    .padding(.bottom, 14)

                BubbleTail()
                    .stroke(strokeGradient, lineWidth: 1)
                    .frame(width: 20, height: 18)
                    .offset(x: 40, y: 2)
            }
        )
        .shadow(color: panelColors.accent.opacity(0.14), radius: 24, y: 10)
        .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
        .fixedSize(horizontal: false, vertical: true)
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

struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width / 2, y: rect.height))
        path.closeSubpath()
        return path
    }
}
