import Foundation
import WidgetKit

/// Grava o resumo para o widget a cada registro e pede ao WidgetKit para redesenhá-lo quando algo mudou.
///
/// O macOS limita quantas vezes por dia um widget é redesenhado; pedir mais que isso não adianta.
/// Por isso o pedido só sai quando a mudança é visível, e no máximo uma vez por minuto.
@MainActor
final class WidgetPublisher {
    /// Último resumo que pediu para redesenhar (veja `WidgetSnapshot.needsReload(since:)`).
    private var lastReload: WidgetSnapshot?
    /// Sem acesso ao App Group (build sem a assinatura do time), desiste depois do primeiro erro.
    private var isUnavailable = false

    func publish(_ snapshot: WidgetSnapshot) {
        guard !isUnavailable else { return }
        do {
            try snapshot.save()
        } catch {
            isUnavailable = true
            Log.system.error("Resumo do widget não gravado: \(String(describing: error), privacy: .public)")
            return
        }
        if let last = lastReload, !snapshot.needsReload(since: last) { return }
        lastReload = snapshot
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.kind)
    }
}
