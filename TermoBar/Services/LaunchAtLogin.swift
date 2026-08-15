import Observation
import ServiceManagement

/// Abre o TermoBar ao iniciar sessão (item de login do `SMAppService`).
@MainActor @Observable
final class LaunchAtLogin {
    private(set) var isRegistered = SMAppService.mainApp.status == .enabled

    /// Ligar ou desligar registra o app; se o sistema recusar, volta ao estado real.
    var isEnabled: Bool {
        get { isRegistered }
        set { setEnabled(newValue) }
    }

    private func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isRegistered = enabled
        } catch {
            Log.system.error("Não foi possível alterar o item de login: \(error.localizedDescription)")
            isRegistered = SMAppService.mainApp.status == .enabled
        }
    }
}
