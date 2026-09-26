#if DEBUG
import AppKit
import SwiftUI

@MainActor
final class VideoDemoWindowController {
    static let shared = VideoDemoWindowController()

    private var windows: [NSWindow] = []

    private init() {}

    func show(vm: ViewModel) {
        NSApp.setActivationPolicy(.regular)

        if !windows.isEmpty {
            windows.forEach { $0.orderFrontRegardless() }
            windows.last?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panelView = ContentView(vm: vm)
            .frame(width: 520, height: 820)
        let panelWindow = makeWindow(
            title: "Tachi Panel Demo",
            size: NSSize(width: 520, height: 820),
            rootView: AnyView(panelView)
        )
        panelWindow.center()

        let petView = ZStack {
            LinearGradient(
                colors: [vm.themeColors.cardBg, vm.themeColors.bg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            DesktopPetView(vm: vm, forcePreviewVisible: true)
        }
        .frame(width: 420, height: 720)
        let petWindow = makeWindow(
            title: "Tachi Pet Demo",
            size: NSSize(width: 420, height: 720),
            rootView: AnyView(petView)
        )

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            petWindow.setFrameOrigin(NSPoint(x: visible.minX + 24, y: visible.minY + 80))
        }

        panelWindow.orderFrontRegardless()
        petWindow.makeKeyAndOrderFront(nil)
        windows = [panelWindow, petWindow]
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow(title: String, size: NSSize, rootView: AnyView) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: rootView)
        return window
    }
}
#endif
