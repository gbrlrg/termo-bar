import AppKit
import Observation
import Sparkle

/// Atualização automática pelo Sparkle. O appcast é publicado junto com cada versão no GitHub
/// (`SUFeedURL` no Info.plist), e cada atualização é conferida pela assinatura EdDSA (`SUPublicEDKey`).
///
/// Na segunda vez que o app abre, o Sparkle pergunta se pode buscar atualizações sozinho;
/// a escolha fica nos Ajustes. Como app de barra de menus, a busca automática não abre janela
/// por conta própria: a versão nova aparece no popover (`pendingVersion`) até o usuário abrir.
@MainActor @Observable
final class Updater: NSObject, SPUStandardUserDriverDelegate {
    /// Versão encontrada pela busca automática que o usuário ainda não viu.
    private(set) var pendingVersion: String?

    @ObservationIgnored private var controller: SPUStandardUpdaterController?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
    }

    var automaticallyChecks: Bool {
        get {
            access(keyPath: \.automaticallyChecks)
            return controller?.updater.automaticallyChecksForUpdates ?? false
        }
        set {
            withMutation(keyPath: \.automaticallyChecks) {
                controller?.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    func checkForUpdates() {
        // App de barra de menus: sem ativar, a janela do Sparkle abre atrás das outras.
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }

    // MARK: - SPUStandardUserDriverDelegate (o Sparkle chama na main thread)

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        let version = update.displayVersionString
        Log.system.notice(
            "Atualização \(version, privacy: .public) encontrada; o Sparkle mostra agora: \(handleShowingUpdate)")
        guard !handleShowingUpdate else { return }
        MainActor.assumeIsolated { pendingVersion = version }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        MainActor.assumeIsolated { pendingVersion = nil }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated { pendingVersion = nil }
    }
}
