import SwiftUI

/// Raiz de composição: cria uma única vez os serviços do app e os entrega às telas.
///
/// Fica fora da struct do app porque o SwiftUI pode instanciá-la mais de uma vez,
/// e cada `Monitor` liga o seu próprio timer de coleta.
@MainActor
enum AppDependencies {
    static let preferences = Preferences()
    static let alerts = AlertNotifier(preferences: preferences)
    static let launchAtLogin = LaunchAtLogin()
    static let updater = Updater()
    static let monitor = Monitor(preferences: preferences, alerts: alerts, store: openHistory())
    static let statusMenu = StatusItemContextMenu(
        actions: .init(
            openSettings: AppActions.openSettings,
            openActivityMonitor: AppActions.openActivityMonitor,
            checkForUpdates: { updater.checkForUpdates() },
            toggleLaunchAtLogin: { launchAtLogin.isEnabled.toggle() },
            quit: { NSApp.terminate(nil) }),
        isLaunchAtLoginEnabled: { launchAtLogin.isEnabled })

    /// Sem acesso ao arquivo, o histórico fica só em memória e o app continua funcionando.
    private static func openHistory() -> HistoryStore? {
        do {
            return try HistoryStore(url: HistoryStore.defaultURL)
        } catch {
            Log.history.error("Histórico em disco indisponível: \(String(describing: error), privacy: .public)")
            return try? HistoryStore.inMemory()
        }
    }
}

extension View {
    /// Injeta os serviços do app no ambiente das telas.
    @MainActor
    func appDependencies() -> some View {
        environment(AppDependencies.preferences)
            .environment(AppDependencies.monitor)
            .environment(AppDependencies.alerts)
            .environment(AppDependencies.launchAtLogin)
            .environment(AppDependencies.updater)
    }
}
