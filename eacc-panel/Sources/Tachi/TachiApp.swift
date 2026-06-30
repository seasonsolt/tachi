import SwiftUI

@main
struct TachiApp: App {
    private let vm = ViewModel()

    // WebSocket sidecar for eacc-screen
    private let wsServer = WebSocketServer(port: 3666)
    private let statsWatcher = StatsWatcher()
    private let sessionsWatcher = SessionsWatcher()
    private let themeWatcher = ThemeWatcher()
    private let bridge: EACCBridge

    private let recipeRuntime = RecipeRuntime()

    init() {
        NotificationManager.shared.requestAuthorization()

        // Wire up the EACC bridge (includes theme watcher)
        bridge = EACCBridge(
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
        bridge.onClaudeCodeChanged = { [vm] data in
            vm.upsertSource(id: "claude-code", name: "Claude Code", data: data)
        }

        // Connect RecipeRuntime to ViewModel + Bridge
        vm.recipeRuntime = recipeRuntime
        bridge.recipeRuntime = recipeRuntime

        // Install default recipes if first run
        RecipeStore.installDefaults()

        bridge.start()
        wsServer.start()
        statsWatcher.start()
        sessionsWatcher.start()
        themeWatcher.start()
        recipeRuntime.start()

        Task { @MainActor [vm] in
            FloatingPetWindowController.shared.show(vm: vm)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(vm: vm)
        } label: {
            ZStack(alignment: .leading) {
                Text(vm.menuBarWidthTemplate)
                    .hidden()
                Text(vm.isLoading && vm.items.isEmpty && vm.sessions.isEmpty ? "\u{23f3}" : vm.menuBarText)
            }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .fixedSize()
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
