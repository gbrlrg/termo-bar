import SwiftUI

@main
struct TermoBarApp: App {
    @State private var monitor = Monitor.shared

    init() {
        #if DEBUG
        DebugSnapshot.runIfRequested(monitor)
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(monitor: monitor)
        }
    }
}
