import SwiftUI

@main
struct EACCSMonitorApp: App {
    @State private var vm = ViewModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView(vm: vm)
        } label: {
            Text(vm.isLoading ? "\u{23f3}" : vm.menuBarText)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
        }
        .menuBarExtraStyle(.window)
    }
}
