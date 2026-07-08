import AppKit
import SwiftUI

private let desktopAuroraTeal = Color(red: 45.0 / 255.0, green: 212.0 / 255.0, blue: 191.0 / 255.0)
private let desktopAuroraAmber = Color(red: 245.0 / 255.0, green: 158.0 / 255.0, blue: 11.0 / 255.0)

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

// Bubble body and speech tail traced as one outline so the border never
// crosses the tail — the seam a separate diamond overlay always shows.
// The bottom `tailDepth` strip of the frame is reserved for the tail.
private struct TaskBubbleShape: Shape {
    var cornerRadius: CGFloat = 22
    var tailCenterX: CGFloat = 53
    var tailHalfWidth: CGFloat = 12
    var tailDepth: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailDepth)
        let r = min(cornerRadius, min(body.width, body.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: body.minX + r, y: body.minY))
        p.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        p.addArc(center: CGPoint(x: body.maxX - r, y: body.minY + r), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        p.addArc(center: CGPoint(x: body.maxX - r, y: body.maxY - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: tailCenterX + tailHalfWidth, y: body.maxY))
        p.addLine(to: CGPoint(x: tailCenterX, y: body.maxY + tailDepth))
        p.addLine(to: CGPoint(x: tailCenterX - tailHalfWidth, y: body.maxY))
        p.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
        p.addArc(center: CGPoint(x: body.minX + r, y: body.maxY - r), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
        p.addArc(center: CGPoint(x: body.minX + r, y: body.minY + r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// Per-theme bubble treatment from the design mockup: Aurora glass (3A),
// Matrix CRT (4B), Odyssey white room (5B). Amber follows the Aurora look.
private struct BubbleSkinStyle {
    var cornerRadius: CGFloat = 22
    var isOpaque = false
    var headerUppercase = false
    var headerTracking: CGFloat = 0
    var monolithMarker = false
    var matrixEffects = false

    static func forTheme(_ theme: EACCThemeName) -> BubbleSkinStyle {
        switch theme {
        case .matrix:
            return BubbleSkinStyle(cornerRadius: 16, matrixEffects: true)
        case .voidTheme:
            return BubbleSkinStyle(
                cornerRadius: 14,
                isOpaque: true,
                headerUppercase: true,
                headerTracking: 2.5,
                monolithMarker: true
            )
        case .cyber, .amber:
            return BubbleSkinStyle()
        }
    }
}

// The 5B header mark: a tiny monolith slab instead of a pulse dot.
private struct MonolithMarker: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color(white: 0.07))
            .frame(width: 7, height: 15)
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.black.opacity(0.05))
                    .padding(-3)
            )
    }
}

private struct BlinkingCursor: View {
    let color: Color
    let fontSize: CGFloat
    let fontName: String

    @State private var isOn = false

    var body: some View {
        Text("_")
            .font(.custom(fontName, size: fontSize).weight(.bold))
            .foregroundStyle(color)
            .opacity(isOn ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    isOn = true
                }
            }
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

struct FloatingPetWindowPlacement {
    static let horizontalMargin: CGFloat = 24
    static let bottomOffset: CGFloat = 72

    static func initialFrame(size: CGSize, visibleFrame: CGRect) -> CGRect {
        clampedFrame(
            origin: CGPoint(
                x: visibleFrame.maxX - size.width - horizontalMargin,
                y: visibleFrame.minY + bottomOffset
            ),
            size: size,
            visibleFrame: visibleFrame
        )
    }

    static func resizedFrame(currentFrame: CGRect, newSize: CGSize, visibleFrame _: CGRect) -> CGRect {
        CGRect(
            origin: CGPoint(
                x: currentFrame.maxX - newSize.width,
                y: currentFrame.minY
            ),
            size: newSize
        )
    }

    static func draggedFrame(startFrame: CGRect, translation: CGSize) -> CGRect {
        CGRect(
            origin: CGPoint(
                x: startFrame.minX + translation.width,
                y: startFrame.minY - translation.height
            ),
            size: startFrame.size
        )
    }

    private static func clampedFrame(origin: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGRect {
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - size.height)
        let x = min(max(origin.x, visibleFrame.minX), maxX)
        let y = min(max(origin.y, visibleFrame.minY), maxY)

        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}

@MainActor
final class FloatingPetWindowController {
    static let shared = FloatingPetWindowController()

    private var panel: NSPanel?
    private var dragStartFrame: NSRect?

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
        } onPanelDragChange: { [weak self, weak panel] translation in
            guard let self, let panel else { return }
            self.applyDrag(translation, to: panel)
        } onPanelDragEnd: { [weak self] in
            self?.dragStartFrame = nil
        }
        if let hosting = panel.contentView as? NSHostingView<DesktopPetView> {
            hosting.rootView = view
        } else {
            panel.contentView = NSHostingView(rootView: view)
        }
    }

    private func place(panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let targetFrame = FloatingPetWindowPlacement.initialFrame(
            size: panel.frame.size,
            visibleFrame: screen.visibleFrame
        )
        panel.setFrameOrigin(targetFrame.origin)
    }

    private func applySize(_ size: CGSize, to panel: NSPanel, animated: Bool = true) {
        guard panel.frame.size != size else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            panel.setContentSize(size)
            return
        }

        let targetFrame = FloatingPetWindowPlacement.resizedFrame(
            currentFrame: panel.frame,
            newSize: size,
            visibleFrame: screen.visibleFrame
        )

        panel.setFrame(targetFrame, display: true)
    }

    private func applyDrag(_ translation: CGSize, to panel: NSPanel) {
        if dragStartFrame == nil {
            dragStartFrame = panel.frame
        }
        guard let dragStartFrame else { return }

        let targetFrame = FloatingPetWindowPlacement.draggedFrame(
            startFrame: dragStartFrame,
            translation: translation
        )
        panel.setFrameOrigin(targetFrame.origin)
    }
}

struct DesktopPetView: View {
    private static let collapsedPanelWidth: CGFloat = 168
    private static let expandedPanelWidth: CGFloat = 340
    private static let collapsedContentHeight: CGFloat = 148
    private static let previewLift: CGFloat = 170
    private static let previewOffsetY: CGFloat = 136
    private static let horizontalPadding: CGFloat = 20
    private static let verticalPadding: CGFloat = 12

    let vm: ViewModel
    var onPanelSizeChange: ((CGSize) -> Void)? = nil
    var onPanelDragChange: ((CGSize) -> Void)? = nil
    var onPanelDragEnd: (() -> Void)? = nil
    // One hover region for the whole panel (pet + bubble + the gap between
    // them). Two separate tracking areas left a dead zone that collapsed the
    // panel mid-interaction, and a panel resize under the cursor churned a
    // single pet-only tracking area into a spurious exit/enter bounce.
    @State private var isHoveringPanel = false
    @State private var isCelebrating = false
    @State private var celebrationToken = 0
    @State private var isPreviewVisible = false
    @State private var isDraggingCompanion = false
    @State private var previewDismissTask: Task<Void, Never>? = nil

    private var isShowingPreview: Bool {
        isPreviewVisible && vm.shouldShowCompanionTaskPreview && !isDraggingCompanion
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
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if !isDraggingCompanion {
                                beginCompanionDrag()
                            }
                            onPanelDragChange?(value.translation)
                        }
                        .onEnded { _ in
                            isDraggingCompanion = false
                            onPanelDragEnd?()
                        }
                )
            }
        }
        .frame(width: currentPanelWidth - (Self.horizontalPadding * 2), height: contentHeight, alignment: .bottomTrailing)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHoveringPanel = hovering
            guard !isDraggingCompanion else { return }
            if hovering {
                showPreview()
            } else {
                schedulePreviewDismissIfNeeded()
            }
        }
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
                isHoveringPanel = false
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
            guard !isDraggingCompanion else { return }
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
        guard !isDraggingCompanion else {
            hidePreviewWithoutLayoutAnimation()
            return
        }
        guard vm.shouldShowCompanionTaskPreview else {
            hidePreviewWithoutLayoutAnimation()
            return
        }
        setPreviewVisibleWithoutLayoutAnimation(true)
        onPanelSizeChange?(Self.panelSize(for: vm, showingPreview: true))
    }

    private func schedulePreviewDismissIfNeeded() {
        previewDismissTask?.cancel()
        guard !isHoveringPanel else { return }

        previewDismissTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !isHoveringPanel else { return }
                hidePreviewWithoutLayoutAnimation()
                onPanelSizeChange?(Self.panelSize(for: vm, showingPreview: false))
            }
        }
    }

    private func beginCompanionDrag() {
        isDraggingCompanion = true
        isHoveringPanel = false
        previewDismissTask?.cancel()
        previewDismissTask = nil
        hidePreviewWithoutLayoutAnimation()
        onPanelSizeChange?(Self.panelSize(for: vm, showingPreview: false))
    }

    private func hidePreviewWithoutLayoutAnimation() {
        setPreviewVisibleWithoutLayoutAnimation(false)
    }

    private func setPreviewVisibleWithoutLayoutAnimation(_ visible: Bool) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            isPreviewVisible = visible
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
        // Real card height: chip row (~20) + two-line title (~32) + meta row (26)
        // + internal spacing. Underestimating clips the bubble at the panel edge.
        let itemHeight: CGFloat = 96
        let itemSpacing: CGFloat = CGFloat(max(0, taskCount - 1)) * 10
        let footerHeight: CGFloat = vm.companionTaskFooter == nil ? 0 : 26
        return 66 + bubbleTailDepth + (CGFloat(taskCount) * itemHeight) + itemSpacing + footerHeight
    }

    private var taskBubble: some View {
        let panelColors = vm.panelThemeColors
        let skin = panelColors
        let style = BubbleSkinStyle.forTheme(vm.selectedTheme)
        let shape = TaskBubbleShape(cornerRadius: style.cornerRadius, tailDepth: Self.bubbleTailDepth)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if style.monolithMarker {
                    MonolithMarker()
                } else {
                    DesktopPulseDot(color: panelColors.accent)
                }
                Text(style.headerUppercase ? vm.companionTaskHeader.uppercased() : vm.companionTaskHeader)
                    .font(skin.display(13, weight: style.headerUppercase ? .medium : .semibold))
                    .tracking(style.headerTracking)
                    .foregroundStyle(panelColors.textPrimary)
                    .shadow(
                        color: style.matrixEffects ? panelColors.accent.opacity(0.45) : .clear,
                        radius: style.matrixEffects ? 6 : 0
                    )
                Spacer()
                CompanionPersonaMenu(
                    vm: vm,
                    accent: panelColors.accent
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(vm.companionTaskVisibleSessions) { session in
                    taskPreviewItem(session, panelColors: panelColors, style: style)
                }
            }

            if let footer = vm.companionTaskFooter {
                Text(footer)
                    .font(skin.mono(10, weight: .medium))
                    .foregroundStyle(panelColors.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
        // Reserve the tail strip inside the bounds so the glass NSView
        // actually covers it; the shape carves the tail out of this strip.
        .padding(.bottom, Self.bubbleTailDepth)
        .background(bubbleSurface(shape: shape, style: style, panelColors: panelColors))
        .overlay(
            shape.stroke(
                style.isOpaque
                    ? Color.black.opacity(0.12)
                    : panelColors.accent.opacity(style.matrixEffects ? 0.35 : 0.18),
                lineWidth: 1
            )
        )
        .shadow(color: panelColors.accent.opacity(style.isOpaque ? 0 : 0.18), radius: 40, y: 12)
        .shadow(color: .black.opacity(style.isOpaque ? 0.28 : 0.32), radius: 26, y: 14)
        .fixedSize(horizontal: false, vertical: true)
    }

    private static let bubbleTailDepth: CGFloat = 12

    @ViewBuilder
    private func bubbleSurface(
        shape: TaskBubbleShape,
        style: BubbleSkinStyle,
        panelColors: EACCThemeColors
    ) -> some View {
        // Keep the glass tint light so the behind-window blur stays visible.
        let bubbleFill = LinearGradient(
            colors: [
                panelColors.cardBg.opacity(0.55),
                panelColors.bg.opacity(0.62)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        ZStack {
            if style.isOpaque {
                // Odyssey white room: solid warm surface, no vibrancy.
                shape.fill(panelColors.cardBg)
            } else {
                GlassBackdrop()
                    .clipShape(shape)
                shape.fill(bubbleFill)
            }

            if style.matrixEffects {
                MatrixRainView()
                    .opacity(0.12)
                    .clipShape(shape)
                CRTScanlines()
                    .clipShape(shape)
            }

            // Specular top edge, the detail that sells native glass.
            shape.stroke(
                LinearGradient(
                    colors: [Color.white.opacity(style.isOpaque ? 0.7 : 0.28), Color.white.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .allowsHitTesting(false)
    }

    private func taskPreviewItem(
        _ session: CodingSession,
        panelColors: EACCThemeColors,
        style: BubbleSkinStyle
    ) -> some View {
        let skin = panelColors
        return Button {
            vm.openCompanionTask(session)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(vm.companionTaskProject(for: session))
                        .font(skin.mono(10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
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
                        .font(skin.mono(9, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(sessionStatusTint(session).opacity(0.12))
                        )
                        .foregroundStyle(sessionStatusTint(session))

                    Spacer(minLength: 0)
                }

                taskTitleText(vm.companionTaskLine(for: session), skin: skin)
                    .lineLimit(2)
                    .shadow(
                        color: style.matrixEffects ? panelColors.accent.opacity(0.3) : .clear,
                        radius: style.matrixEffects ? 5 : 0
                    )

                HStack(spacing: 8) {
                    HStack(spacing: 1) {
                        Text(sessionMetaLine(session))
                            .font(skin.mono(10, weight: .medium))
                            .foregroundStyle(panelColors.textSecondary)
                            .lineLimit(1)
                        if style.matrixEffects {
                            BlinkingCursor(
                                color: panelColors.accent,
                                fontSize: 10,
                                fontName: skin.monoFont
                            )
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
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

    // Design 3A styles a leading commit hash in accent mono before the title.
    private func taskTitleText(_ line: String, skin: EACCThemeColors) -> Text {
        if let match = line.range(of: "^[0-9a-f]{7,10}(?=\\s)", options: .regularExpression) {
            let hash = String(line[match])
            let rest = String(line[match.upperBound...])
            return Text(hash)
                .font(skin.mono(11, weight: .semibold))
                .foregroundStyle(skin.accent)
                + Text(rest)
                .font(skin.display(12, weight: .semibold))
                .foregroundStyle(skin.textPrimary)
        }
        return Text(line)
            .font(skin.display(12, weight: .semibold))
            .foregroundStyle(skin.textPrimary)
    }

    private func sessionStatusTint(_ session: CodingSession) -> Color {
        switch session.status {
        case .working: return vm.panelThemeColors.accent
        case .waitingForInput: return desktopAuroraAmber
        case .completed: return desktopAuroraTeal
        // Follow the skin so a quiet session reads muted in every theme
        // instead of slate-grey against the Matrix greens.
        case .idle: return vm.panelThemeColors.textMuted
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
