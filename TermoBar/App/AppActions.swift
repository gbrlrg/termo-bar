import AppKit

/// Ações do app que mais de uma tela dispara (popover e menu da barra).
@MainActor
enum AppActions {
    private static let activityMonitorURL = URL(filePath: "/System/Applications/Utilities/Activity Monitor.app")

    static func openActivityMonitor() {
        NSWorkspace.shared.open(activityMonitorURL)
    }

    /// Abre a janela de Ajustes fora de uma view, onde `openSettings` do SwiftUI não existe.
    static func openSettings() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
