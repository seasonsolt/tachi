import AppKit
import SwiftUI

@MainActor
final class FloatingPetWindowController {
    static let shared = FloatingPetWindowController()

    private var panel: NSPanel?

    func show(vm: ViewModel) {
        if let panel {
            updateContent(vm: vm, panel: panel)
            panel.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 236, height: 190),
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
        let view = DesktopPetView(vm: vm)
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
}

struct DesktopPetView: View {
    let vm: ViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            bubble

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                CompanionPetView(
                    persona: vm.companionPersona,
                    mood: vm.companionMood,
                    accent: vm.companionPetAccent,
                    themeColors: vm.themeColors
                )
                    .frame(width: 124, height: 124)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await vm.refreshSessionPulse() }
        }
        .contextMenu {
            CompanionPersonaActions(vm: vm)
        }
        .help("Drag me around, or tap to sniff session activity")
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(vm.companionAccent)
                    .frame(width: 7, height: 7)
                Text(vm.companionMood.badge)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(vm.companionAccent)
                Spacer()
                CompanionPersonaMenu(vm: vm)
            }

            Text(vm.companionHeadline)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(vm.themeColors.textPrimary)
                .lineLimit(2)

            Text(shortSubtitle)
                .font(.system(size: 10))
                .foregroundStyle(vm.themeColors.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 200, alignment: .leading)
        .background(
            BubbleShape()
                .fill(vm.themeColors.cardBg.opacity(0.92))
        )
        .overlay(
            BubbleShape()
                .stroke(vm.companionAccent.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
    }

    private var shortSubtitle: String {
        if let session = vm.dominantSession {
            return "\(session.projectName) · \(session.signal.label)"
        }
        return "No warm session yet"
    }
}

struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(
            roundedRect: CGRect(x: 0, y: 0, width: rect.width, height: rect.height - 12),
            cornerRadius: 18
        )

        path.move(to: CGPoint(x: rect.width - 46, y: rect.height - 12))
        path.addLine(to: CGPoint(x: rect.width - 26, y: rect.height - 12))
        path.addLine(to: CGPoint(x: rect.width - 22, y: rect.height))
        path.closeSubpath()

        return path
    }
}
