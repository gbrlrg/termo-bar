import SwiftUI

@main
struct TermoBarApp: App {
    init() {
        #if DEBUG
            DebugSnapshot.runIfRequested()
        #endif
        AppDependencies.statusMenu.install()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView().appDependencies()
        } label: {
            MenuBarLabel().appDependencies()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().appDependencies()
        }
    }
}
