import SwiftUI

@main
struct EACCSMonitorApp: App {
    private let vm = ViewModel()

    // WebSocket sidecar for ritual-screen
    private let wsServer = WebSocketServer(port: 3666)
    private let statsWatcher = StatsWatcher()
    private let sessionsWatcher = SessionsWatcher()
    private let themeWatcher = ThemeWatcher()
    private let bridge: RitualBridge

    init() {
        NotificationManager.shared.requestAuthorization()

        // Wire up the ritual bridge (includes theme watcher)
        bridge = RitualBridge(
            wsServer: wsServer,
            statsWatcher: statsWatcher,
            sessionsWatcher: sessionsWatcher,
            themeWatcher: themeWatcher
        )

        // Connect ViewModel ↔ Bridge for theme sync
        vm.bridge = bridge
        bridge.onThemeChanged = { [vm] theme in
            vm.handleExternalThemeChange(theme)
        }

        bridge.start()
        wsServer.start()
        statsWatcher.start()
        sessionsWatcher.start()
        themeWatcher.start()
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(vm: vm)
        } label: {
            Text(vm.isLoading && vm.items.isEmpty && vm.sessions.isEmpty ? "\u{23f3}" : vm.menuBarText)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .task {
                    FloatingPetWindowController.shared.show(vm: vm)
                }
                .task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(1))
                        vm.advanceMenuAnimation()
                    }
                }
                .task(id: vm.refreshInterval) {
                    await vm.refresh()
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(vm.refreshInterval))
                        await vm.refresh()
                    }
                }
                .task {
                    await vm.refreshSessionPulse()
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(vm.sessionRefreshInterval))
                        await vm.refreshSessionPulse()
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }
}
